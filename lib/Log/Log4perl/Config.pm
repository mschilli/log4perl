##################################################
package Log::Log4perl::Config;
##################################################

use 5.006;
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl::Logger;
use Log::Log4perl::Level;
use Log::Dispatch::Screen;
use Log::Dispatch::File;

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

##################################################
sub init {
##################################################
    my($class, $filename) = @_;

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

    my $data = config_read($filename);
    
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
        my ($level, $appname) = split /\s*,\s*/, $value;

        $logger->level(
            Log::Log4perl::Level::to_level($level));

        if(defined $appname) {
            add_layout_by_name($data, $logger, $appname);

            my $appenderclass = get_appender_by_name($data, $appname);

            my $appender;

            if($appenderclass =~ /::/) {
                # It's Perl
                my @params = grep { $_ ne "layout" and
                                    $_ ne "value" 
                                  } keys %{$data->{appender}->{$appname}};
                $appender = $appenderclass->new(
                   name      => $appname,
                   min_level => 'debug', # Set default, *we* are controlling
                                         # this now
                   map { $_ => $data->{appender}->{$appname}->{$_}->{value} } 
                       @params
                );
            } else {
                # It's Java. Try to map
                #print Data::Dumper::Dumper($data->{appender}->{$appname});
                $appender = $appenderclass->new($appname, 
                                                $data->{appender}->{$appname});
            }
    
            $logger->add_appender($appender);
        }
    }
}

###########################################
sub add_layout_by_name {
###########################################
    my($data, $logger, $layout) = @_;

    $logger->layout($data->{appender}->{$layout}->
                   {layout}->{ConversionPattern}->{value});
}

###########################################
sub get_appender_by_name {
###########################################
    my($data, $name) = @_;

    my $appender = $data->{appender}->{$name}->{value};

    return unlog4j($appender);
}

###########################################
sub config_read {
###########################################
# Read the lib4j configuration and store the
# values into a nested hash structure.
###########################################
    my($file) = @_;

    open FILE, "<$file" or die "Cannot open $file";
    my @text = <FILE>;
    close FILE;

    my $data = {};

    for(@text) {
        s/#.*//;
        next if /^\s*$/;
        if(my($key, $val) = /(\S+?)\s*=\s*(.*)/) {
            $key = unlog4j($key);
            #$key =~ s#^org\.apache\.##;
            #$key =~ s#^log4j\.##;
            my $ptr = $data;
            for my $part (split /\.|::/, $key) {
                $ptr->{$part} = {} unless exists $ptr->{$part};
                $ptr = $ptr->{$part};
            }
            $ptr->{value} = $val;
            #print "$key: $val\n";
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

###############################################
# The following classes are for mapping log4j #
# appenders to their Log::Dispatch collegues  #
###############################################

###########################################
package ConsoleAppender;
###########################################
sub new {
    my($class, $name) = @_;

    my $disp = Log::Dispatch::Screen->new(
        min_level => "debug",
        name      => $name,
        stderr    => 0,
    );
    return $disp;
}

###########################################
package BufferAppender;
###########################################
sub new {
    my($class, $name) = @_;

    my $disp = Log::Dispatch::Buffer->new(
        min_level => "debug",
        name      => $name,
    );
    return $disp;
}

###########################################
package FileAppender;
###########################################
sub new {
    my($class, $name, $data) = @_;

    my $disp = Log::Dispatch::File->new(
        min_level => "debug",
        name      => $name,
        filename  => $data->{File}->{value},
        mode      => "append",
    );
    return $disp;
}
