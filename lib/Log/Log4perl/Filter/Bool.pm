##################################################
package Log::Log4perl::Filter::Bool;
##################################################

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Level;
use Log::Log4perl::Config;
use Parse::RecDescent;

use constant DEBUG => 0;

use constant CMD_AND => 0;
use constant CMD_OR  => 1;
use constant CMD_NOT => 2;

use base "Log::Log4perl::Filter";

##################################################
sub new {
##################################################
     my ($class, %options) = @_;

     my $self = {};
     
     bless $self, $class;
     
     $self->compile_logic($options{logic});

     return $self;
}

##################################################
sub decide {
##################################################
     my ($self, %p) = @_;

     return $self->eval_logic(\%p);
}

##################################################
# Helper for compile_logic
sub Parse::RecDescent::rpn {
##################################################
    for( my $i=1; $i<@_-1; $i+=2 ) {
        @_[$i, $i+1] = @_[$i+1, $i];
    }
    return join " ", @_;
}

##################################################
sub compile_logic {
##################################################
    my ($self, $logic) = @_;

    my $grammar = q{

      expr  :   <leftop: conj  /(\|\||\|)/ conj> 
                { rpn(@{$item[1]}); }

      conj  :   <leftop: term /(&&|&)/   term>
                { rpn(@{$item[1]}); }

      term  :   "!" unary  { rpn($item[2], $item[1]) }
            | unary { $item[1] }

      unary :   "(" expr ")"   { $item[2] }
            |   value          { $item[1] }

      value :   /(\w+)/        { $item[1] }
    };

    my $parse = Parse::RecDescent->new($grammar);

    die "Internal error: Faulty grammar" unless $parse;

    my $upn = $parse->expr($logic);

    unless($upn) {
        warn "Parse error in " . __PACKAGE__ .
             "'s logic: $logic";
        return undef;
    }

    my @commands  = ();

    while($upn =~ /(\S+)/g) {
        $_ = $1;
        if(/\|/) {
            push @commands, CMD_OR;
        }elsif(/&/) {
            push @commands, CMD_AND;
        }elsif(/!/) {
            push @commands, CMD_NOT;
        }else{
            my $app = Log::Log4perl::Appender::ByName($_);
 
            if(!$app) {
                warn "No appender defined for $_";
                return undef;
            }

            if(! $app->can("filter")) {
                warn "Appender $_ doesn't have a 'filter()'";
                return undef;
            }

            push @commands, $app;
        }
    }

    $self->{commands} = \@commands;
}

##################################################
sub eval_logic {
##################################################
    my($self, $p) = @_;

    my @stack = ();

    for(@{$self->{commands}}) {
        if($_ eq CMD_OR) {
            my $a = pop @stack;
            my $b = pop @stack;
            push @stack, $a || $b;
        }elsif($_ eq CMD_AND) {
            my $a = pop @stack;
            my $b = pop @stack;
            push @stack, $a && $b;
        }elsif($_ eq CMD_NOT) {
            $stack[-1] = ! $stack[-1];
        }elsif(ref($_) =~ /Log::Log4perl::Filter/) {
            push @stack, $_->decide(%$p);
        }
    }

    return $stack[0] || "0";
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
