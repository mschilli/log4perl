
use Test::More;
use Log::Log4perl qw(:easy);

our $CLASS_PROTOTYPE_PRESENT;

BEGIN {
    eval { require Class::Prototyped; };
    if(! $@) {
        $CLASS_PROTOTYPE_PRESENT = 1;
    }
};

if( $CLASS_PROTOTYPE_PRESENT ) {
    plan tests => 1;
} else {
    plan skip_all, "only with Class::Prototyped present";
}

my $buffer =  "";

my $class = Class::Prototyped->newPackage(
        "MyAppenders::Bulletizer",
        bullets => 1,
        log     => sub {
            my($self, %params) = @_;
            $buffer = ( "*" x $self->bullets() .  $params{message} );
        },
);

Log::Log4perl->init(\ q{
    log4perl.logger = INFO, Bully

    log4perl.appender.Bully=MyAppenders::Bulletizer
    log4perl.appender.Bully.bullets=3

    log4perl.appender.Bully.layout = PatternLayout
    log4perl.appender.Bully.layout.ConversionPattern=%m%n
});

INFO "Boo!";
is($buffer, "***Boo!\n", "message via Class::Prototyped");
