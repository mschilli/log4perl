###########################################
package TestModule;
###########################################
# Test shortcuts
# Mike Schilli, 2002 (m@perlmeister.com)
###########################################
use warnings;
use strict;

use Log::Log4perl qw(:shortcuts);

###########################################
sub new {
###########################################
    my($class) = @_;

    debug("Creating new instance of class $class");

    my $self = {};
    bless $self, $class;
}

###########################################
sub do_something {
###########################################
    my($self) = @_;

    info("Doing something");
}

1;
