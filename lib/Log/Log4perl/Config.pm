##################################################
package Log::Log4perl::Config;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Logger;
use Log::Log4perl::Level;
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Log4perl::JavaMap;
use constant DEBUG => 0;

# How to map lib4j levels to Log::Dispatch levels
my @LEVEL_MAP_A = qw(
 DEBUG  debug
 INFO   info
 INFO   notice
 WARN   warning
 ERROR  error
 FATAL  critical
 FATAL  alert
 FATAL  emergency
);

our $DEFAULT_WATCH_DELAY = 60; #seconds

###########################################
sub init {
###########################################
    Log::Log4perl::Logger->reset();

    return _init(@_);
}

###########################################
sub init_and_watch {
###########################################
    my ($class, $config, $delay) = @_;

    print "init_and_watch ($config-$delay). Resetting.\n" if DEBUG;

    Log::Log4perl::Logger->reset();

    defined ($delay) or $delay = $DEFAULT_WATCH_DELAY;  

    $delay =~ /\D/ && die "illegal non-numerica value for delay: $delay";

    if (ref $config) {
        die "can only watch a file, not a string of configuration information";
    }

    Log::Log4perl::Logger::init_watch($delay);

    _init($class, $config);
}

##################################################
sub _init {
##################################################
    my($class, $config) = @_;

    my %additivity = ();

    print "Calling _init\n" if DEBUG;
    $Log::Log4perl::Logger::INITIALIZED = 1;

    #keep track so we don't create the same one twice
    my %appenders_created = ();

    # This logic is probably suited to win an obfuscated programming
    # contest. It desperately needs to be rewritten.
    # Basically, it works like this:
    # config_read() reads the entire config file into a hash of hashes:
    #     log4j.logger.foo.bar.baz: WARN, A1
    # gets transformed into
    #     $data->{log4j}->{logger}->{foo}->{bar}->{baz} = "WARN, A1";
    # The code below creates the necessary loggers, sets the appenders
    # and the layouts etc.
    # In order to transform parts of this tree back into identifiers
    # (like "foo.bar.baz"), we're using the leaf_paths functions below.
    # Pretty scary. But it allows the lines of the config file to be
    # in *arbitrary* order.

    my $data = config_read($config);
    
    my @loggers = ();
    my $system_wide_threshold;

        # Find all logger definitions in the conf file. Start
        # with root loggers.
    if(exists $data->{rootLogger}) {
        push @loggers, ["", $data->{rootLogger}->{value}];
    }
        
        # Check if we've got a system-wide threshold setting
    if(exists $data->{threshold}) {
            # yes, we do.
        $system_wide_threshold = $data->{threshold}->{value};
    }
    if (exists $data->{oneMessagePerAppender}){
                    $Log::Log4perl::one_message_per_appender = 
                        $data->{oneMessagePerAppender}->{value};
    }

        # Continue with lower level loggers. Both 'logger' and 'category'
        # are valid keywords. Also 'additivity' is one, having a logger
        # attached. We'll differenciate between the two further down.
    for my $key (qw(logger category additivity PatternLayout)) {

        if(exists $data->{$key}) {

            for my $path (@{leaf_paths($data->{$key})}) {

                my $value = pop @$path;

                    # Translate boolean to perlish
                $value = 1 if $value =~ /^true$/i;
                $value = 0 if $value =~ /^false$/i;

                pop @$path; # Drop the 'value' keyword part

                if($key eq "additivity") {
                    # This isn't a logger but an additivity setting.
                    # Save it in a hash under the logger's name for later.
                    $additivity{join('.', @$path)} = $value;

                    #a global user-defined conversion specifier (cspec)
                }elsif ($key eq "PatternLayout"){
                    &add_global_cspec(@$path[-1], $value);

                } else {
                    # This is a regular logger
                    push @loggers, [join('.', @$path), $value];
                }
            }
        }
    }

    for (@loggers) {
        my($name, $value) = @$_;

        my $logger = Log::Log4perl::Logger->get_logger($name);
        my ($level, @appnames) = split /\s*,\s*/, $value;

        $logger->level(
            Log::Log4perl::Level::to_priority($level),
            'dont_reset_all');

        if(exists $additivity{$name}) {
            $logger->additivity($additivity{$name});
        }

        for my $appname (@appnames) {

            my $appenderclass = get_appender_by_name($data, $appname, 
                                                     \%appenders_created);
            my $appender;

            print "appenderclass=$appenderclass\n" if DEBUG;

            if (ref $appenderclass) {

                $appender = $appenderclass;
                add_layout_by_name($data, $appender, $appname);

            }else{

                die "ERROR: you didn't tell me how to " .
                    "implement your appender '$appname'"
                        unless $appenderclass;

                if($appenderclass =~ /::/) {
                    # It's Perl
                    my @params = grep { $_ ne "layout" and
                                        $_ ne "value"
                                      } keys %{$data->{appender}->{$appname}};

                    my %param = ();
                    foreach my $pname (@params){
                        #this could be simple value like 
                        #{appender}{myAppender}{file}{value} => 'log.txt'
                        #or a structure like
                        #{appender}{myAppender}{login} => 
                        #                         { name => {value => 'bob'},
                        #                           pwd  => {value => 'xxx'},
                        #                         }
                        #in the latter case we send a hashref to the appender
                        if (exists $data->{appender}{$appname}
                                          {$pname}{value}      ) {
                            $param{$pname} = $data->{appender}{$appname}
                                                    {$pname}{value};
                        }else{
                            $param{$pname} = {map {$_ => $data->{appender}
                                                                {$appname}
                                                                {$pname}
                                                                {$_}
                                                                {value}} 
                                             keys %{$data->{appender}
                                                           {$appname}
                                                           {$pname}}
                                             };
                        }

                    }

                    $appender = Log::Log4perl::Appender->new(
                        $appenderclass, 
                        name => $appname,
                        %param,
                    ); 
                    add_layout_by_name($data, $appender, $appname);

                } else {
                    # It's Java. Try to map
                    print "Trying to map Java $appname\n" if DEBUG;
                    $appender = Log::Log4perl::JavaMap::get($appname, 
                                                $data->{appender}->{$appname});
                    add_layout_by_name($data, $appender, $appname);
                }
            }

                # Check for appender thresholds
            my $threshold = 
               $data->{appender}->{$appname}->{Threshold}->{value};
            if(defined $threshold) {
                    # Need to split into two lines because of CVS
                $appender->threshold($
                    Log::Log4perl::Level::PRIORITY{$threshold});
            }

            if($system_wide_threshold) {
                $appender->threshold($
                    Log::Log4perl::Level::PRIORITY{$system_wide_threshold});
            }

            if($data->{appender}->{$appname}->{threshold}) {
                    die "threshold keyword needs to be uppercase";
            }

            $logger->add_appender($appender, 'dont_reset_all');
            set_appender_by_name($appname, $appender, \%appenders_created);
        }
    }

    #now we're done, set up all the output methods (e.g. ->debug('...'))
    Log::Log4perl::Logger::reset_all_output_methods();
}


###########################################
sub add_layout_by_name {
###########################################
    my($data, $appender, $appender_name) = @_;

    my $layout_class = $data->{appender}->{$appender_name}->{layout}->{value};

    die "Layout not specified for appender $appender_name" unless $layout_class;

    $layout_class =~ s/org.apache.log4j./Log::Log4perl::Layout::/;

    eval {
        eval "require $layout_class";
        if($@) {
            my $old_err = $@;
            eval "require Log::Log4perl::Layout::$layout_class";

            if($@) {
                # If it failed again, revert to the old error message
                $@ = $old_err;
            } else {
                # If it succeeded, leave $@ as "", which indicates success
                # downstream. And, fix the layout name.
                $layout_class = "Log::Log4perl::Layout::$layout_class";
            }
        }
        die $@ if $@;
           # Eval erroneously succeeds on unknown appender classes if
           # the eval string just consists of valid perl code (e.g. an
           # appended ';' in $appenderclass variable). Fail if we see
           # anything in there that can't be class name.
        die "Unknown layout '$layout_class'" if $layout_class =~ /[^:\w]/;
    };

    if ($@) {
        die "ERROR: trying to set layout for $appender_name to " .
            "'$layout_class' failed\n$@";
    }

    $appender->layout($layout_class->new(
        $data->{appender}->{$appender_name}->{layout},
        ));
}

###########################################
sub get_appender_by_name {
###########################################
    my($data, $name, $appenders_created) = @_;

    if ($appenders_created->{$name}) {
        return $appenders_created->{$name};
    }else{
        return $data->{appender}->{$name}->{value};
    }
}

###########################################
sub set_appender_by_name {
###########################################
# keep track of appenders we've already created
###########################################
    my($appname, $appender, $appenders_created) = @_;

    $appenders_created->{$appname} ||= $appender;
}

##################################################
sub add_global_cspec {
##################################################
# the config file said
# log4j.PatternLayout.cspec.Z=sub {return $$*2}
##################################################
    my ($letter, $perlcode) = @_;

    die "error: only single letters allowed in log4j.PatternLayout.cspec.$letter"
        unless ($letter =~ /^[a-zA-Z]$/);

    Log::Log4perl::Layout::PatternLayout::add_global_cspec($letter, $perlcode);
}

###########################################
sub config_read {
###########################################
# Read the lib4j configuration and store the
# values into a nested hash structure.
###########################################
    my($config) = @_;

    my @text;

    if (ref($config) eq 'HASH') {   # convert the hashref into a list 
                                    # of name/value pairs
        @text = map { $_ . '=' . $config->{$_} } keys %{$config};
    } elsif (ref $config) {
        @text = split(/\n/,$$config);
    }else{
        Log::Log4perl::Logger::set_file_to_watch($config);
        open FILE, "<$config" or die "Cannot open config file '$config'";
        @text = <FILE>;
        close FILE;
    }

    print "Reading $config: [@text]\n" if DEBUG;

    my $data = {};

    while (@text) {
        $_ = shift @text;
        s/#.*//;
        next unless /\S/;
    
        while (/(.+?)\\\s*$/) {
            my $prev = $1;
            my $next = shift(@text);
            $next =~ s/^ +//g;  #leading spaces
            $next =~ s/#.*//;
            $_ = $prev. $next;
            chomp;
        }
        if(my($key, $val) = /(\S+?)\s*=\s*(.*)/) {
            $val =~ s/\s+$//;
            $val = eval_if_perl($val) if $key !~ /\.cspec\./;
            $key = unlog4j($key);
            my $how_deep = 0;
            my $ptr = $data;
            for my $part (split /\.|::/, $key) {
                $ptr->{$part} = {} unless exists $ptr->{$part};
                $ptr = $ptr->{$part};
                ++$how_deep;
            }

            #here's where we deal with turning multiple values like this:
            # log4j.appender.jabbender.to = him@a.jabber.server
            # log4j.appender.jabbender.to = her@a.jabber.server
            #into an arrayref like this:
            #to => { value => 
            #       ["him\@a.jabber.server", "her\@a.jabber.server"] },
            if (exists $ptr->{value} && $how_deep > 2) {
                if (ref ($ptr->{value}) ne 'ARRAY') {
                    my $temp = $ptr->{value};
                    $ptr->{value} = [];
                    push (@{$ptr->{value}}, $temp);
                }
                print ref $ptr->{value},"\n";
                push (@{$ptr->{value}}, $val);
            }else{
                $ptr->{value} = $val;
            }
        }
    }

    return $data;
}

###########################################
sub unlog4j {
###########################################
    my ($string) = @_;

    $string =~ s#^org\.apache\.##;
    $string =~ s#^log4j\.##;
    $string =~ s#^log4perl\.##i;

    $string =~ s#\.#::#g;

    return $string;
}

############################################################
sub leaf_paths {
############################################################
# Takes a reference to a hash of hashes structure of 
# arbitrary depth, walks the tree and returns a reference
# to an array of all possible leaf paths (each path is an 
# array again).
# Example: { a => { b => { c => d }, e => f } } would generate
#          [ [a, b, c, d], [a, e, f] ]
############################################################
    my ($root) = @_;

    my @stack  = ();
    my @result = ();

    push @stack, [$root, []];  
    
    while(@stack) {
        my $item = pop @stack;

        my($node, $path) = @$item;

        if(ref($node) eq "HASH") { 
            for(keys %$node) {
                push @stack, [$node->{$_}, [@$path, $_]];
            }
        } else {
            push @result, [@$path, $node];
        }
    }
    return \@result;
}

###########################################
sub eval_if_perl {
###########################################
    my($value) = @_;

    if($value =~ /^\s*sub\s*{/ ) {
        unless($Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE) {
            die "\$Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE setting " .
                "prohibits Perl code in config file";
        }
        my $cref = eval "package main; $value" or 
            die "Can't evaluate '$value' ($@)";
        $value = $cref->();
    }

    return $value;
}

1;

__END__

=head1 NAME

Log::Log4perl::Config - Log4perl configuration file syntax

=head1 DESCRIPTION

In C<Log::Log4perl>, configuration files are used to describe how the
system's loggers ought to behave. 

The format is the same as the one as used for C<log4j>, just with
a few perl-specific extensions, like enabling the C<Bar::Twix>
syntax instead of insisting on the Java-specific C<Bar.Twix>.

Comment lines (starting with arbitrary whitespace and a #) and
blank lines (all whitespace or empty) are ignored.

Also, blanks between syntactical entities are ignored, it doesn't 
matter if you write

    log4perl.logger.Bar.Twix=WARN,Screen

or 

    log4perl.logger.Bar.Twix = WARN, Screen

C<Log::Log4perl> will strip the blanks while parsing your input.

Assignments need to be on a single line. However, you can break the
line if you want to by using a continuation character at the end of the
line. Instead of writing

    log4perl.appender.A1.layout=Log::Log4perl::Layout::SimpleLayout

you can break the line at any point by putting a backslash at the very (!)
end of the line to be continued:

    log4perl.appender.A1.layout=\
        Log::Log4perl::Layout::SimpleLayout

Watch out for trailing blanks after the backslash, which would prevent
the line from being properly concatenated.

=head2 Loggers

Loggers are addressed by category:

    log4perl.logger.Bar.Twix      = WARN, Screen

This sets all loggers under the C<Bar::Twix> hierarchy on priority
C<WARN> and attaches a later-to-be-defined C<Screen> appender to them.
Settings for the root appender (which doesn't have a name) can be
accomplished by simply omitting the name:

    log4perl.logger = FATAL, Database, Mailer 

This sets the root appender's level to C<FATAL> and also attaches the 
later-to-be-defined appenders C<Database> and C<Mailer> to it.

Loggers carrying a threshold, can be defined using the C<Threshold>
keyword after the logger's name:

    log4perl.logger.Bar.Twix.Threshold = ERROR

The additivity flag of a logger is set or cleared via the 
C<additivity> keyword:

    log4perl.additivity.Bar.Twix = 0|1

(Note the reversed order of keyword and logger name, resulting
from the dilemma that a logger name could end in C<.additivity>
according to the log4j documentation).

=head2 Appenders and Layouts

Appender names used in Log4perl configuration file
lines need to be resolved later on, in order to
define the appender's properties and its layout. To specify properties
of an appender, just use the C<appender> keyword after the
C<log4perl> intro and the appender's name:

        # The Bar::Twix logger and its appender
    log4perl.logger.Bar.Twix = DEBUG, A1
    log4perl.appender.A1=Log::Dispatch::File
    log4perl.appender.A1.filename=test.log
    log4perl.appender.A1.mode=append
    log4perl.appender.A1.layout=Log::Log4perl::Layout::SimpleLayout

This sets a priority of C<DEBUG> for loggers in the C<Bar::Twix>
hierarchy and assigns the C<A1> appender to it, which is later on
resolved to be an appender of type C<Log::Dispatch::File>, simply
appending to a log file. According to the C<Log::Dispatch::File>
manpage, the C<filename> parameter specifies the name of the log file
and the C<mode> parameter can be set to C<append> or C<write> (the
former will append to the logfile if one with the specified name
already exists while the latter would clobber and overwrite it).

The order of the entries in the configuration file is not important,
C<Log::Log4perl> will read in the entire file first and try to make
sense of the lines after it knows the entire context.

You can very well define all loggers first and then their appenders
(you could even define your appenders first and then your loggers,
but let's not go there):

    log4perl.logger.Bar.Twix = DEBUG, A1
    log4perl.logger.Bar.Snickers = FATAL, A2

    log4perl.appender.A1=Log::Dispatch::File
    log4perl.appender.A1.filename=test.log
    log4perl.appender.A1.mode=append
    log4perl.appender.A1.layout=Log::Log4perl::Layout::SimpleLayout

    log4perl.appender.A2=Log::Dispatch::Screen
    log4perl.appender.A2.stderr=0
    log4perl.appender.A2.layout=Log::Log4perl::Layout::PatternLayout
    log4perl.appender.A2.layout.ConversionPattern = %d %m %n

Note that you have to specify the full path to the layout class
and that C<ConversionPattern> is the keyword to specify the printf-style
formatting instructions.

=head1 Configuration File Cookbook

Here's some examples of often-used Log4perl configuration files:

=head2 Append to STDERR

    log4perl.category.Bar.Twix      = WARN, Screen
    log4perl.appender.Screen        = Log::Dispatch::Screen
    log4perl.appender.Screen.layout = \
        Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %m %n

=head2 Append to STDOUT

    log4perl.category.Bar.Twix      = WARN, Screen
    log4perl.appender.Screen        = Log::Dispatch::Screen
    log4perl.appender.Screen.layout = \
    log4perl.appender.Screen.stderr = 0
        Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %m %n

=head2 Append to a log file

    log4perl.logger.Bar.Twix = DEBUG, A1
    log4perl.appender.A1=Log::Dispatch::File
    log4perl.appender.A1.filename=test.log
    log4perl.appender.A1.mode=append
    log4perl.appender.A1.layout = \
        Log::Log4perl::Layout::PatternLayout
    log4perl.appender.A1.layout.ConversionPattern = %d %m %n

Note that you could even leave out 

    log4perl.appender.A1.mode=append

and still have the logger append to the logfile by default, although
the C<Log::Dispatch::File> module does exactly the opposite.
This is due to some nasty trickery C<Log::Log4perl> performs behind 
the scenes to make sure that beginner's CGI applications don't clobber 
the log file every time they're called.

=head2 Write a log file from scratch

If you loathe the Log::Log4perl's append-by-default strategy, you can
certainly override it:

    log4perl.logger.Bar.Twix = DEBUG, A1
    log4perl.appender.A1=Log::Dispatch::File
    log4perl.appender.A1.filename=test.log
    log4perl.appender.A1.mode=write
    log4perl.appender.A1.layout=Log::Log4perl::Layout::SimpleLayout

C<write> is the C<mode> that has C<Log::Dispatch::File> explicitely clobber
the log file if it exists.

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>

=cut
