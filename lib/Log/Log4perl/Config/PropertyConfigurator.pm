package Log::Log4perl::Config::PropertyConfigurator;

use strict;

#poor man's export
*eval_if_perl = \&Log::Log4perl::Config::eval_if_perl;
*unlog4j      = \&Log::Log4perl::Config::unlog4j;



sub parse {
    my $text = shift;

    my $data = {};

    while (@$text) {
        $_ = shift @$text;
        s/#.*//;
        next unless /\S/;
    
        while (/(.+?)\\\s*$/) {
            my $prev = $1;
            my $next = shift(@$text);
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

1;
