##################################################
package Log::Log4perl::Layout::PatternLayout;
##################################################

use 5.006;
use strict;
use warnings;
use Log::Log4perl::Level;
use Log::Log4perl::DateFormat;

our $TIME_HIRES_AVAILABLE;
our $TIME_HIRES_AVAILABLE_WARNED = 0;
our $PROGRAM_START_TIME;

BEGIN {
    # Check if we've got Time::HiRes. If not, don't make a big fuss,
    # just set a flag so we know later on that we can't have fine-grained
    # time stamps
    $TIME_HIRES_AVAILABLE = 0;
    eval { require Time::HiRes; };
    if($@) {
        $PROGRAM_START_TIME = time();
    } else {
        $TIME_HIRES_AVAILABLE = 1;
        $PROGRAM_START_TIME = [Time::HiRes::gettimeofday()];
    }
}

##################################################
sub current_time {
##################################################
    # Return secs and optionally msecs if we have Time::HiRes
    if($TIME_HIRES_AVAILABLE) {
        return (Time::HiRes::gettimeofday());
    } else {
        return (time(), 0);
    }
}

use base qw(Log::Log4perl::Layout);

no strict qw(refs);

##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my ($data) = @_;

    my ($layout_string);
     
    if (ref $data) {
        $layout_string = $data->{ConversionPattern}{value};
    } else {
        $layout_string = $data;
    }

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    bless $self, $class;

    $self->define($layout_string);

    return $self;
}

##################################################
sub define {
##################################################
    my($self, $format) = @_;

        # If the message contains a %m followed by a newline,
        # make a note of that so that we can cut a superfluous 
        # \n off the message later on
    if($format =~ /%m%n/) {
        $self->{message_chompable} = 1;
    } else {
        $self->{message_chompable} = 0;
    }

    # Parse the format
    $format =~ s/%(-*\d*)
                       ([cCdfFILmMnprtxX%])
                       (?:{(.*?)})*/
                       rep($self, $1, $2, $3);
                      /gex;

    $self->{printformat} = $format;
}

##################################################
sub rep {
##################################################
    my($self, $num, $op, $curlies) = @_;

    return "%%" if $op eq "%";

    # If it's a %d{...} construct, initialize a simple date
    # format formatter, so that we can quickly render later on.
    # If it's just %d, assume %d{yyyy/MM/dd HH:mm::ss}
    my $sdf;
    if($op eq "d") {
        if(defined $curlies) {
            $sdf = Log::Log4perl::DateFormat->new($curlies);
        } else {
            $sdf = Log::Log4perl::DateFormat->new("yyyy/MM/dd HH:mm:ss");
        }
    }

    push @{$self->{stack}}, [$op, $sdf || $curlies];

    $self->{info_needed}->{$op}++;

    return "%${num}s";
}

##################################################
sub render {
##################################################
    my($self, $message, $category, $priority, $caller_level) = @_;

    $caller_level = 0 unless defined  $caller_level;

    my %info    = ();

    $info{m}    = $message;
        # See 'define'
    chomp $info{m} if $self->{message_chompable};

    my @results = ();

    if($self->{info_needed}->{L} or
       $self->{info_needed}->{F} or
       $self->{info_needed}->{C} or
       $self->{info_needed}->{l} or
       $self->{info_needed}->{M} or
       0
      ) {
        my ($package, $filename, $line, 
            $subroutine, $hasargs,
            $wantarray, $evaltext, $is_require, 
            $hints, $bitmask) = caller($caller_level);

        $info{L} = $line;
        $info{F} = $filename;
        $info{C} = $package;

        if($self->{info_needed}->{M} or
           $self->{info_needed}->{l} or
           0) {
            # For the name of the subroutine the logger was triggered,
            # we need to go one more level up
            $subroutine = (caller($caller_level+1))[3];
            $subroutine = "main::" unless $subroutine;
            $info{M} = $subroutine;
            $info{l} = "$subroutine $filename ($line)";
        }
    }

    $info{c} = $category;
    $info{d} = 1; # Dummy value, corrected later
    $info{n} = "\n";
    $info{p} = $priority;

    if($self->{info_needed}->{r}) {
        if($TIME_HIRES_AVAILABLE) {
            $info{r} = 
                int((Time::HiRes::tv_interval ( $PROGRAM_START_TIME ))*1000);
        } else {
            if(! $TIME_HIRES_AVAILABLE_WARNED) {
                $TIME_HIRES_AVAILABLE_WARNED++;
                # warn "Requested %r pattern without installed Time::HiRes\n";
            }
            $info{r} = time() - $PROGRAM_START_TIME;
        }
    }

        # As long as they're not implemented yet ..
    $info{t} = "N/A";
    $info{x} = "N/A";
    $info{X} = "N/A";

        # Iterate over all info fields on the stack
    for my $e (@{$self->{stack}}) {
        my($op, $curlies) = @$e;
        if(exists $info{$op}) {
            my $result = $info{$op};
            if($curlies) {
                $result = curly_action($op, $curlies, $info{$op});
            } else {
                # just for %d
                if($op eq 'd') {
                    $result = $info{$op}->format(current_time());
                }
            }
            push @results, $result;
        } else {
            warn "Format %'$op' not implemented (yet)";
            push @results, "FORMAT-ERROR";
        }
    }

    return (sprintf $self->{printformat}, @results);
}

##################################################
sub curly_action {
##################################################
    my($ops, $curlies, $data) = @_;

    if($ops eq "c") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "C") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "d") {
        $data = $curlies->format(current_time());
    } elsif($ops eq "F") {
        my @parts = split m#/#, $data;
            # Limit it to max curlies entries
        if(@parts > $curlies) {
            splice @parts, 0, @parts - $curlies;
        }
        $data = join '/', @parts;
    }

    return $data;
}

##################################################
sub shrink_category {
##################################################
    my($category, $len) = @_;

    my @components = split /\.|::/, $category;

    if(@components > $len) {
        splice @components, 0, @components - $len;
        $category = join '.', @components;
    } 

    return $category;
}

1;

__END__

=head1 NAME

Log::Log4perl::Layout::PatternLayout - Pattern Layout

=head1 SYNOPSIS

  use Log::Log4perl::Layout::PatternLayout;

  my $layout = Log::Log4perl::Layout::PatternLayout->new(
                                                   "%d (%F:%L)> %m");

=head1 DESCRIPTION

Creates a pattern layout according to
http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html.

The C<new()> method creates a new PatternLayout, specifying its log
format. The format
string can contain a number of placeholders which will be
replaced by the logging engine when it's time to log the message:

    %c Category of the logging event.
    %C Fully qualified package (or class) name of the caller
    %d Current date in yyyy/mm/dd hh:mm:ss format
    %F File where the logging event occurred
    %l Fully qualified name of the calling method followed by the
       callers source the file name and line number between 
       parentheses.
    %L Line number within the file where the log statement was issued
    %m The message to be logged
    %M Method or function where the logging request was issued
    %n Newline (OS-independent)
    %p Priority of the logging event
    %r Number of milliseconds elapsed from program start to logging 
       event
    %% A literal percent (%) sign

=head2 Quantify placeholders

All placeholders can be extended with formatting instructions,
just like in I<printf>:

    %20c   Reserve 20 chars for the category, left-justify and fill
           with blanks if it is shorter
    %-20c  Same as %20c, but right-justify and fill the left side 
           with blanks
    %09r   Zero-pad the number of milliseconds to 9 digits

=head2 Fine-tuning with curlies

Some placeholders have special functions defined if you add curlies 
with content after them:

    %c{1}  Just show the right-most category compontent, useful in large
           class hierarchies (Foo::Baz::Bar -> Bar)
    %c{2}  Just show the two right most category components
           (Foo::Baz::Bar -> Baz::Bar)

    %f     Display source file including full path
    %f{1}  Just display filename
    %f{2}  Display filename and last path component (dir/test.log)
    %f{3}  Display filename and last two path components (d1/d2/test.log)

In this way, you're able to shrink the displayed category or
limit file/path components to save space in your logs.

=head2 Fine-tune the date

If you're not happy with the default %d format for the date which 
looks like

    YYYY/MM/DD HH:mm::ss

you're free to fine-tune it in order to display only certain characteristics
of a date, according to the SimpleDateFormat in the Java World
(http://java.sun.com/j2se/1.3/docs/api/java/text/SimpleDateFormat.html):

    %d{HH:mm}     "23:45" -- Just display hours and minutes
    %d{yy, EEEE}  "02, Monday" -- Just display two-digit year 
                                  and spelled-out weekday
Here's the symbols and their meaning, according to the SimpleDateFormat
specification:

    Symbol   Meaning                 Presentation     Example
    ------   -------                 ------------     -------
    G        era designator          (Text)           AD
    y        year                    (Number)         1996 
    M        month in year           (Text & Number)  July & 07
    d        day in month            (Number)         10
    h        hour in am/pm (1-12)    (Number)         12
    H        hour in day (0-23)      (Number)         0
    m        minute in hour          (Number)         30
    s        second in minute        (Number)         55
    E        day in week             (Text)           Tuesday
    D        day in year             (Number)         189
    a        am/pm marker            (Text)           PM

    (Text): 4 or more pattern letters--use full form, < 4--use short or 
            abbreviated form if one exists. 

    (Number): the minimum number of digits. Shorter numbers are 
              zero-padded to this amount. Year is handled 
              specially; that is, if the count of 'y' is 2, the 
              Year will be truncated to 2 digits. 

    (Text & Number): 3 or over, use text, otherwise use number. 

There's also a bunch of pre-defined formats:

    %d{ABSOLUTE}   "HH:mm:ss,SSS"
    %d{DATE}       "dd MMM YYYY HH:mm:ss,SSS"
    %d{ISO8601}    "YYYY-mm-dd HH:mm:ss,SSS"

=head1 SEE ALSO

=head1 AUTHOR

Mike Schilli, E<lt>m@perlmeister.comE<gt>

=cut
