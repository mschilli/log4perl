##################################################
package Log::Log4perl::Filter::Bool;
##################################################

use 5.006;

use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;

use constant DEBUG => 0;

use base "Log::Log4perl::Filter";

##################################################
sub new {
##################################################
     my ($class, %options) = @_;

     my $self = { params => {},
                  %options,
                };
     
     bless $self, $class;
     
     print "Compiling '$options{logic}'\n" if DEBUG;

         # Set up meta-decider for later
     $self->compile_logic($options{logic});

         # Register this bool filter 
         # with the global filter registry
     Log::Log4perl::Filter::by_name($options{name}, $self);

     return $self;
}

##################################################
sub decide {
##################################################
     my ($self, %p) = @_;

     return $self->eval_logic(\%p);
}

##################################################
sub compile_logic {
##################################################
    my ($self, $logic) = @_;

       # Extract Filter placeholders in logic as defined
       # in configuration file.
    while($logic =~ /([\w_-]+)/g) {
            # Get the corresponding filter object
        my $filter = Log::Log4perl::Filter::by_name($1);
        die "Filter $filter required by Bool filter, but not defined" 
            unless $filter;

        $self->{params}->{$1} = $filter;
    }

        # Fabricate a parameter list: A1/A2/A3 => $A1, $A2, $A3
    my $plist = join ', ', map { '$' . $_ } keys %{$self->{params}};

        # Replace all the (dollar-less) placeholders in the code 
        # by scalars (basically just put dollars in front of them)
    $logic =~ s/([\w_-]+)/\$$1/g;

        # Set up the meta decider, which transforms the config file
        # logic into compiled perl code
    my $func = <<EOT;
        sub { 
            my($plist) = \@_;
            $logic;
        }
EOT

    print "func=$func\n" if DEBUG;

    my $eval_func = eval $func;

    if(! $eval_func) {
        die "Syntax error in Bool filter logic: $eval_func";
    }

    $self->{eval_func} = $eval_func;
}

##################################################
sub eval_logic {
##################################################
    my($self, $p) = @_;

    my @plist = ();

        # Eval the results of all filters referenced
        # in the code (although the order of keys is
        # not predictable, it is consistent :)
    for my $param (keys %{$self->{params}}) {
            # Call the decider and map the result to 1 or 0
        print "Calling filter $param\n" if DEBUG;
        push @plist, ($self->{params}->{$param}->decide(%$p) ? 1 : 0);
    }

        # Now pipe the parameters into the canned function,
        # have it evaluate the logic and return the final
        # decision
    print "Passing in (", join(', ', @plist), ")\n" if DEBUG;
    return $self->{eval_func}->(@plist);
}

1;

__END__

=head1 NAME

Log::Log4perl::Filter::Bool - Special filter to combine the results of others

=head1 SYNOPSIS

    log4perl.logger = WARN, AppWarn, AppError

    log4perl.filter.Match1       = sub { /let this through/ }
    log4perl.filter.Match2       = sub { /and that, too/ }
    log4perl.filter.MyBool       = Log::Log4perl::Filter::Bool
    log4perl.filter.MyBool.logic = Match1 || Match2

    log4perl.appender.Screen        = Log::Dispatch::Screen
    log4perl.appender.Screen.Filter = MyBool
    log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>log4perl@perlmeister.comE<gt>, 2003

=cut
