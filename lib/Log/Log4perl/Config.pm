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
    #     $data->{$log4j}->{logger}->{foo}->{bar}->{baz} = "WARN, A1";
    # The code below creates the necessary loggers, sets the appenders
    # and the layouts etc.
    # In order to transform parts of this tree back into identifiers
    # (like "foo.bar.baz"), we're using the leaf_paths functions below.
    # Pretty scary. But it allows the lines of the config file to be
    # in *arbitrary* order.

    my $data = config_read($config);
    
    my @loggers = ();

        # Find all logger definitions in the conf file. Start
        # with root loggers.
    if(exists $data->{rootLogger}) {
        push @loggers, ["", $data->{rootLogger}->{value}];
    }
        
        # Continue with lower level loggers. Both 'logger' and 'category'
        # are valid keywords.
    for my $key (qw(logger category)) {
        if(exists $data->{$key}) {
            for my $path (@{leaf_paths($data->{$key})}) {
                my $value = pop @$path;
                pop @$path; # Drop the 'value' keyword part
                push @loggers, [join('.', @$path), $value];
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

        for my $appname (@appnames) {

            my $appenderclass = get_appender_by_name($data, $appname, 
                                                     \%appenders_created);
            my $appender;

            if (ref $appenderclass) {

                $appender = $appenderclass;
                add_layout_by_name($data, $appender, $appname);

            }else{

                die "ERROR: you didn't tell me how to implement your appender '$appname'"
                        unless $appenderclass;

                if($appenderclass =~ /::/) {
                    # It's Perl
                    my @params = grep { $_ ne "layout" and
                                        $_ ne "value"
                                      } keys %{$data->{appender}->{$appname}};

                    $appender = Log::Log4perl::Appender->new(
                        $appenderclass, 
                        name => $appname,
                        map { $_ => $data->{appender}->{$appname}->{$_}->{value} 
                            } @params,
                    ); 
                    my $threshold = 
                       $data->{appender}->{$appname}->{Threshold}->{value};
                    if(defined $threshold) {
                            # Need to split into two lines because of CVS
                        $appender->threshold($
                            Log::Log4perl::Level::PRIORITY{$threshold});
                    }
                    add_layout_by_name($data, $appender, $appname);
                } else {
                    # It's Java. Try to map
                    $appender = Log::Log4perl::JavaMap::get($appname, 
                                                $data->{appender}->{$appname});
                    add_layout_by_name($data, $appender, $appname);
                }
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
        die $@ if $@;
    };

    if ($@) {
        die "ERROR: trying to set layout for $appender_name to " .
            "$layout_class failed\n$@";
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
    
        while (/(.+?)\\$/) {
            my $prev = $1;
            my $next = shift(@text);
            $next =~ s/^ +//g;  #leading spaces
            $next =~ s/#.*//;
            $_ = $prev. $next;
            chomp;
        }
        if(my($key, $val) = /(\S+?)\s*=\s*(.*)/) {
            $val =~ s/\s+$//;
            $key = unlog4j($key);
            my $ptr = $data;
            for my $part (split /\.|::/, $key) {
                $ptr->{$part} = {} unless exists $ptr->{$part};
                $ptr = $ptr->{$part};
            }
            $ptr->{value} = $val;
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

1;
