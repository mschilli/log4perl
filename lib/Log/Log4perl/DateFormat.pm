###########################################
package Log::Log4perl::DateFormat;
###########################################
use warnings;
use strict;

###########################################
sub new {
###########################################
    my($class, $format) = @_;

    my $self = { 
                  stack => [],
                  fmt   => undef,
               };

    bless $self, $class;

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

    if($first eq "G") {
        # Always constant
        return "AD";
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
    }

    return $string;
}

###########################################
sub format {
###########################################
    my($self, $time) = @_;

    my @time = localtime($time);

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
