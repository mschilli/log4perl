package Log::Log4perl::Appender::DBI;

use Carp;

use strict;
use Log::Log4perl::Layout::PatternLayout;
use Params::Validate qw(validate SCALAR ARRAYREF CODEREF);


use base qw(Log::Dispatch::Output);


#overriding superclass so we can get arrayrefs through in 'message'
sub log
{
    my $self = shift;

    my %p = validate( @_, { level => { type => SCALAR },
                            message => {  },
                            log4p_level => { type => SCALAR },
                            log4p_category  => { type => SCALAR },
                            name  => { type => SCALAR },
                          } );

    return unless $self->_should_log($p{level});

    $p{message} = $self->_apply_callbacks(%p)
        if $self->{callbacks};

    $self->log_message(%p);
}



sub new {
    my($proto, %p) = @_;
    my $class = ref $proto || $proto;

    my $self = bless {}, $class;

    $self->_basic_init(%p);
    $self->_init(%p);

    #e.g.
    #log4j.appender.DBAppndr.params.1 = %p    
    #log4j.appender.DBAppndr.params.2 = %5.5m
    foreach my $pnum (keys %{$p{params}}){
        $self->{bind_value_layouts}{$pnum} = 
                Log::Log4perl::Layout::PatternLayout->new(
                    {ConversionPattern => {value  => $p{params}->{$pnum}}});
    }
    #'bind_value_layouts' now contains a PatternLayout
    #for each parameter heading for the Sql engine

    $self->{SQL} = $p{sql}; #save for error msg later on

    $self->{BUFFERSIZE} = $p{bufferSize} || 1; 

    if ($p{usePreparedStmt}) {
        $self->{sth} = $self->create_statement($p{sql});
        $self->{usePreparedStmt} = 1;
    }else{
        $self->{layout} = Log::Log4perl::Layout::PatternLayout->new(
                    {ConversionPattern => {value  => $p{sql}}});
    }

    if ($self->{usePreparedStmt} &&  $self->{BUFFERSIZE}){
        warn "Log4perl: you've defined both usePreparedStmt and bufferSize \n".
        "in your appender '$p{name}'--\n".
        "I'm going to ignore bufferSize and just use a prepared stmt\n";
    }


    return $self;
}


sub _init {
    my $self = shift;
    my %params = @_;

    if ($params{dbh}) {
        $self->{dbh} = $params{dbh};
    } else {
        $self->{dbh} = DBI->connect(@params{qw(datasource username password)})
            or croak "Log4perl: $DBI::errstr";
        $self->{_mine} = 1;
    }


}


sub create_statement {
    my ($self, $stmt) = @_;

    $stmt || croak "Log4perl: sql not set in Log4perl::Appender::DBI";

    my $sth = $self->{dbh}->prepare($stmt) || croak "Log4perl: DBI->prepare failed $DBI::errstr\n$stmt";

    return $sth;
}


sub log_message {
    my $self = shift;
    my %p = @_;

    #%p is
    #    { name    => \$appender_name,
    #      level   => \$Log: DBI.pm,v $
    #      level   => \Revision 1.3  2002/12/28 00:01:59  kgoess
    #      level   => \moving stuff out of _init to new so subclassing is easier
    #      level   => \
    #      level   => \Revision 1.2  2002/12/27 00:21:43  kgoess
    #      level   => \tweaking docs
    #      level   => \
    #      level   => \Revision 1.1  2002/12/27 00:03:28  kgoess
    #      level   => \initial version
    #      level   => \level},   
    #      message => \$message,
    #      log4p_category => $category,
    #      log4p_level  => $level,);
    #    },


        #getting log4j behavior with no specified ConversionPattern
    chomp $p{message} unless ref $p{message}; 

        
    my $qmarks = $self->calculate_bind_values(\%p);


    if ($self->{usePreparedStmt}) {

        $self->{sth}->execute(@$qmarks);

    }else{

        #first expand any %x's in the statement
        my $stmt = $self->{layout}->render(
                        $p{message},
                        $p{log4p_category},
                        $p{log4p_level},
                        5 + $Log::Log4perl::caller_depth,  
                        );

        push @{$self->{BUFFER}}, $stmt, $qmarks;

        $self->check_buffer();
    }
}

sub calculate_bind_values {
    my ($self, $p) = @_;

    my @qmarks;
    my $user_ph_idx = 0;

    if ($self->{bind_value_layouts}) {

        my $prev_pnum = 0;
        my $max_pnum = 0;
    
        my @pnums = sort {$a <=> $b} keys %{$self->{bind_value_layouts}};
        $max_pnum = $pnums[-1];
        
        #Walk through the integers for each possible bind value.
        #If it doesn't have a layout assigned from the config file
        #then shift it off the array from the $log call
        foreach my $pnum (1..$max_pnum){
            my $msg;
    
            if ($self->{bind_value_layouts}{$pnum}){
               $msg = $self->{bind_value_layouts}{$pnum}->render(
                        $p->{message},
                        $p->{log4p_category},
                        $p->{log4p_level},
                        6 + $Log::Log4perl::caller_depth,  
                    );
            }elsif (ref $p->{message} eq 'ARRAY' && @{$p->{message}}){
                $msg = $p->{message}->[$user_ph_idx++];
            }else{
                croak "Log4perl: missing bind value for placeholder(?) number $pnum in ".
                "sqlStatement, while trying to log \"$p->{message}\"\n".
                "Did you set 'dontCollapseArrayRefs'?\n ";
            }
            push @qmarks, $msg;
        }
    }

    #handle leftovers
    if (ref $p->{message} eq 'ARRAY' && @{$p->{message}} > $user_ph_idx) {
        push @qmarks, @{$p->{message}}[$user_ph_idx..@{$p->{message}}];
    }

    return \@qmarks;
}


sub check_buffer {
    my $self = shift;

    return unless ($self->{BUFFER} && ref $self->{BUFFER} eq 'ARRAY');

    if (scalar @{$self->{BUFFER}} >= $self->{BUFFERSIZE} * 2) {

        my ($sth, $stmt, $prev_stmt);

        while (@{$self->{BUFFER}}) {
            my ($stmt, $qmarks) = splice (@{$self->{BUFFER}},0,2);

                #reuse the sth if the stmt doesn't change
            if ($stmt ne $prev_stmt) {
                $sth = $self->create_statement($stmt);
            }

            $sth->execute(@$qmarks) || 
                croak "Log4perl: DBI->execute failed $DBI::errstr, \n".
                    "on $self->{SQL}\n@$qmarks";

            $prev_stmt = $stmt;

        }
    }
}

sub DESTROY {
    my $self = shift;

    $self->{BUFFERSIZE} = 1;

    $self->check_buffer();

    if ($self->{_mine} && $self->{dbh}) {
        $self->{dbh}->disconnect;
    }
}


1;

__END__

=head1 NAME

Log::Log4perl::Appender::DBI - implements appending to a DB

=head1 SYNOPSIS

    my $config = <<'EOT';
    log4j.category = WARN, DBAppndr
    log4j.appender.DBAppndr             = Log::Log4perl::Appender::DBI
    log4j.appender.DBAppndr.datasource  = DBI:CSV:f_dir=t/tmp
    log4j.appender.DBAppndr.username    = bobjones
    log4j.appender.DBAppndr.password    = 12345
    log4j.appender.DBAppndr.sql         = \
       insert into log4perltest           \
       (loglevel, custid, category, message, ipaddr) \
       values (?,?,?,?,?)
    log4j.appender.DBAppndr.params.1 = %p    
                                  #2 is custid from the log() call
    log4j.appender.DBAppndr.params.3 = %c
                                  #4 is the message from log()
                                  #5 is ipaddr from log()
        
    log4j.appender.DBAppndr.layout    = Log::Log4perl::Layout::PatternLayout
    
    log4j.appender.DBAppndr.usePreparedStmt = 1
     #--or--
    log4j.appender.DBAppndr.bufferSize = 2
    
    
    log4j.appender.DBAppndr.layout.dontCollapseArrayRefs = 1
    
    
    $logger->warn( [$custid, 'big problem!!', $ip_addr] );



=head1 DESCRIPTION

This is a specialized Log::Dispatch object customized to work with
log4perl and its abilities, originally based on Log::Dispatch::DBI 
by Tatsuhiko Miyagawa but with heavy modifications.

It is an attempted compromise between what Log::Dispatch::DBI was 
doing and what log4j's JDBCAppender does.  Note the log4j docs say
the JDBCAppender "is very likely to be completely replaced in the future."

The simplest usage is this:

    log4j.category = WARN, DBAppndr
    log4j.appender.DBAppndr            = Log::Log4perl::Appender::DBI
    log4j.appender.DBAppndr.datasource = DBI:CSV:f_dir=t/tmp
    log4j.appender.DBAppndr.username   = bobjones
    log4j.appender.DBAppndr.password   = 12345
    log4j.appender.DBAppndr.sql        = \
       INSERT INTO logtbl                \
          (loglevel, message)            \
          VALUES ('%c','%m')
    
    log4j.appender.DBAppndr.layout    = Log::Log4perl::Layout::PatternLayout


    $logger->fatal('fatal message');
    $logger->warn('warning message');

    ===============================
    |FATAL|fatal message          |
    |WARN |warning message        |
    ===============================


But the downsides to that usage are:

=over 4

=item * 

You'd better be darn sure there are not quotes in your log message, or your
insert could have unforseen consequences!  This is a very insecure way to
handle database inserts, using place holders and bind values is much better, 
keep reading.

=item *

It's not terribly high-performance, a statement is created and executed
for each log call.

=item *

The only run-time parameter you get is the %m message, in reality
you probably want to log specific data in specific table columns.

=back

So let's try using placeholders, and tell the logger to create a
prepared statement handle at the beginning and just reuse it 
(just like Log::Dispatch::DBI does)


    log4j.appender.DBAppndr.sql = \
       INSERT INTO logtbl \
          (custid, loglevel, message) \
          VALUES (?,?,?)
    log4j.appender.DBAppndr.layout    = Log::Log4perl::Layout::PatternLayout

    #---------------------------------------------------
    #now the bind values:
                                  #1 is the custid
    log4j.appender.DBAppndr.params.2 = %p    
                                  #3 is the message
    #---------------------------------------------------
    log4j.appender.DBAppndr.layout.dontCollapseArrayRefs = 1
    
    log4j.appender.DBAppndr.usePreparedStmt = 1
    
    
    $logger->warn( [1234, 'warning message'] ); #note the arrayref!


Now see how we're using the '?' placeholders in our statement?  This
means we don't have to worry about messages that look like 

    invalid input: 1234';drop table custid;

fubaring our database!

Passing the values in the C<warn> statement as an array reference

    $logger->warn( [1234, 'warning message'] );

after setting this in the layout

    log4j.appender.DBAppndr.layout.dontCollapseArrayRefs = 1


keeps the values available for the DBI later on.  You can mix them up
as you see fit, the logger will populate the question marks
with params you've defined in the config file and populate the
rest with values from your arrayref.  

If the logger statement is also being handled by other non-DBI appenders,
they will just join the arrayrefs into a string, joined with 
C<$Log::Log4perl::JOIN_ARRAYREFS_CHAR> (default is a space).

And see the C<usePreparedStmt>?  That creates a statement handle when
the logger object is created and just reuses it.  That, however, may
be problematic for long-running processes like webservers, in which case
you can use this parameter instead

    log4j.appender.DBAppndr.bufferSize=2

This copies log4j's JDBCAppender's behavior, it saves up that many
log statements and writes them all out at once.  If your INSERT
statement uses only ? placeholders and no %x conversion specifiers
it should be quite efficient because the logger can re-use the
same statement handle for the inserts.

If the program ends while the buffer is only partly full, the DESTROY
block should flush the remaining statements, if the DESTROY block
runs of course.

=head1 DESCRIPTION 2

Or another way to say the same thing:

The idea is that if you're logging to a database table, you probably
want specific parts of your log information in certain columns.  To this
end, you pass an arrayref to the log statement, like 

    $logger->warn(['big problem!!',$userid,$subpoena_nr,$ip_addr]);

and the array members drop into the positions defined by the placeholders
in your SQL statement. You can also define information in the config
file like

    log4j.appender.DBAppndr.params.2 = %p    

in which case those numbered placeholders will be filled in with
the specified values, and the rest of the placeholders will be
filled in with the values from your log statement's array.

=head1 CHANGING DBH CONNECTIONS (POOLING)

If you want to get your dbh from some place in particular, like
maybe a pool, subclass and override _init() and/or create_statement(), 
q.v.

=head1 LIFE OF CONNECTIONS

If you're using C<log4j.appender.DBAppndr.usePreparedStmt>
this module creates an sth when it starts and keeps it for the life
of the program.  For long-running processes (e.g. mod_perl) this
may be a problem, your connections may go stale.  

It also holds one connection open for every appender, which might
be too many.

Even if you're not using that, the database handle may go stale.  If you're
not using Apache::DBI this may cause you problems.


=head1 AUTHOR

Kevin Goess <cpan@goess.org> December, 2002

=head1 SEE ALSO

L<Log::Dispatch::DBI>

L<Log::Log4perl::JavaMap::JDBCAppender>

=cut

