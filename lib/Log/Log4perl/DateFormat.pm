###########################################
package Log::Log4perl::DateFormat;
###########################################
use warnings;
use strict;

our $GMTIME = 0;

my @MONTH_NAMES = qw(
January February March April May June July
August September October November December);

my @WEEK_DAYS = qw(
Sunday Monday Tuesday Wednesday Thursday Friday);

###########################################
sub new {
###########################################
    my($class, $format) = @_;

    my $self = { 
                  stack => [],
                  fmt   => undef,
               };

    bless $self, $class;

        # Predefined formats
    if($format eq "ABSOLUTE") {
        $format = "HH:mm:ss,SSS";
    } elsif($format eq "DATE") {
        $format = "dd MMM yyyy HH:mm:ss,SSS";
    } elsif($format eq "ISO8601") {
        $format = "yyyy-mm-dd HH:mm:ss,SSS";
    }

    if($format) { 
        $self->prepare($format);
    }

    return $self;
}

###########################################
sub prepare {
###########################################
    my($self, $format) = @_;

    $format =~ s/(([GyMdhHmsSEDFwWakKz])\2*)/rep($self, $1)/ge;

    $self->{fmt} = $format; 
}

###########################################
sub rep {
###########################################
    my ($self, $string) = @_;

    my $first = substr $string, 0, 1;
    my $len   = length $string;

    #my ($s,$mi,$h,$d,$mo,$y,$wd,$yd,$dst) = localtime($time);

    # Here's how this works:
    # Detect what kind of parameter we're dealing with and determine
    # what type of sprintf-placeholder to return (%d, %02d, %s or whatever).
    # Then, we're setting up an array, specific to the current format,
    # that can be used later on to compute the components of the placeholders
    # one by one when we get the components of the current time later on
    # via localtime.
    
    # So, we're parsing the "yyyy/mm" format once, replace it by, say
    # "%04d:%02d" and store an array that says "for the first placeholder,
    # get the localtime-parameter on index #5 (which is years since the
    # epoch), add 1900 to it and pass it on to sprintf(). For the 2nd 
    # placeholder, get the localtime component at index #2 (which is hours)
    # and pass it on unmodified to sprintf.
    
    # So, the array to compute the time format at logtime contains
    # as many elements as the original SimpleDateFormat contained. Each
    # entry is a arrary ref, holding an array with 2 elements: The index
    # into the localtime to obtain the value and a reference to a subroutine
    # to do computations eventually. The subroutine expects the orginal
    # localtime() time component (like year since the epoch) and returns
    # the desired value for sprintf (like y+1900).

    # This way, we're parsing the original format only once (during system
    # startup) and during runtime all we do is call localtime *once* and
    # run a number of blazingly fast computations, according to the number
    # of placeholders in the format.

###########
#G - epoch#
###########
    if($first eq "G") {
        # Always constant
        return "AD";

##########
#y - year#
##########
    } elsif($first eq "y") {
        if($len >= 4) {
            # 4-digit year
            push @{$self->{stack}}, [5, sub { return $_[0] + 1900 }];
            return "%04d";
        } else {
            # 2-digit year
            push @{$self->{stack}}, [5, sub { $_[0] % 100 }];
            return "%02d";
        }

###########
#M - month#
###########
    } elsif($first eq "M") {
        if($len >= 3) {
            # Use month name
            push @{$self->{stack}}, [4, sub { return $MONTH_NAMES[$_[0]] }];
            return "%s";
        } elsif($len == 2) {
            # Use zero-padded month number
            push @{$self->{stack}}, [4, sub { $_[0]+1 }];
            return "%02d";
        } else {
            # Use zero-padded month number
            push @{$self->{stack}}, [4, sub { $_[0]+1 }];
            return "%d";
        }

##################
#d - day of month#
##################
    } elsif($first eq "d") {
        push @{$self->{stack}}, [3, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#h - am/pm hour#
##################
    } elsif($first eq "h") {
        push @{$self->{stack}}, [2, sub { ($_[0] % 12) || 12 }];
        return "%0" . $len . "d";

##################
#H - 24 hour#
##################
    } elsif($first eq "H") {
        push @{$self->{stack}}, [2, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#m - minute#
##################
    } elsif($first eq "m") {
        push @{$self->{stack}}, [1, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#s - second#
##################
    } elsif($first eq "s") {
        push @{$self->{stack}}, [0, sub { return $_[0] }];
        return "%0" . $len . "d";

##################
#E - day of week #
##################
    } elsif($first eq "E") {
        push @{$self->{stack}}, [6, sub { $WEEK_DAYS[$_[0]] }];
        return "%${len}s";

######################
#D - day of the year #
######################
    } elsif($first eq "D") {
        push @{$self->{stack}}, [7, sub { $_[0] }];
        return "%${len}s";

######################
#a - am/pm marker    #
######################
    } elsif($first eq "a") {
        push @{$self->{stack}}, [2, sub { $_[0] < 12 ? "AM" : "PM" }];
        return "%${len}s";

######################
#S - milliseconds    #
######################
    } elsif($first eq "S") {
        push @{$self->{stack}}, 
             [9, sub { substr sprintf("%06d", $_[0]), 0, $len }];
        return "%s";

#############################
#Something that's not defined
#(F=day of week in month
# w=week in year W=week in month
# k=hour in day K=hour in am/pm
# z=timezone
#############################
    } else {
        return "-- '$first' not (yet) implemented --";
    }

    return $string;
}

###########################################
sub format {
###########################################
    my($self, $secs, $msecs) = @_;

    $msecs = 0 unless defined $msecs;

    my @time; 

    if($GMTIME) {
        @time = gmtime($secs);
    } else {
        @time = localtime($secs);
    }

        # add milliseconds
    push @time, $msecs;

    my @values = ();

    for(@{$self->{stack}}) {
        my($val, $code) = @$_;
        if($code) {
            push @values, $code->($time[$val]);
        } else {
            push @values, $time[$val];
        }
    }

    return sprintf($self->{fmt}, @values);
}

1;

__END__

http://jakarta.apache.org/log4j/docs/api/org/apache/log4j/PatternLayout.html

"ABSOLUTE", 
HH:mm:ss,SSS
"15:49:37,459"

"DATE" 
"dd MMM YYYY HH:mm:ss,SSS"
"06 Nov 1994 15:49:37,459"

and "ISO8601"
"YYYY-mm-dd HH:mm:ss,SSS"
"1999-11-27 15:49:37,459"

%d{ISO8601} or %d{ABSOLUTE}
%d{HH:mm:ss,SSS} or %d{dd MMM yyyy HH:mm:ss,SSS}

Symbol   Meaning                 Presentation        Example
------   -------                 ------------        -------
G        era designator          (Text)              AD
y        year                    (Number)            1996
M        month in year           (Text & Number)     July & 07
d        day in month            (Number)            10
h        hour in am/pm (1~12)    (Number)            12
H        hour in day (0~23)      (Number)            0
m        minute in hour          (Number)            30
s        second in minute        (Number)            55
S        millisecond             (Number)            978
E        day in week             (Text)              Tuesday
D        day in year             (Number)            189
F        day of week in month    (Number)            2 (2nd Wed in July)
w        week in year            (Number)            27
W        week in month           (Number)            2
a        am/pm marker            (Text)              PM
k        hour in day (1~24)      (Number)            24
K        hour in am/pm (0~11)    (Number)            0
z        time zone               (Text)              Pacific Standard Time
'        escape for text         (Delimiter)
''       single quote            (Literal)           '
