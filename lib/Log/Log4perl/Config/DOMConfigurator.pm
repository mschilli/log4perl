package Log::Log4perl::Config::DOMConfigurator;
#todo
# some params not attrs but values, like <sql>...</sql>
# see DEBUG!!!  below
# appender-ref in <appender>
# check multiple appenders in a category
# need docs in Config.pm re URL loading, steal from XML::DOM
# see PropConfigurator re importing unlog4j, eval_if_perl
# need to handle 0/1, true/false?
# see Config, need to check version of XML::DOM

use XML::DOM;
use Log::Log4perl::Level;
use strict;

use constant DEBUG => 1;

our $VERSION = 0.02;


sub parse {
    my ($text) = @_;

    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parse (join('',@$text));


     my $l4p_tree = {};
    
     my $config = $doc->getElementsByTagName('log4j:configuration')->item(0);

     $l4p_tree->{threshold}{value} = uc($config->getAttribute('threshold'));

     for my $kid ($config->getChildNodes){
         next unless $kid->getNodeType == ELEMENT_NODE;
         my $tag_name = $kid->getTagName;
         print "parse: got $tag_name\n" if DEBUG;
         if ($tag_name eq 'appender') {
             &parse_appender($l4p_tree, $kid);

         }elsif ($tag_name eq 'category' || $tag_name eq 'logger'){
             &parse_category($l4p_tree, $kid);
             #not entirely accurate, the dtd says 'logger' doesn't accept
             #a 'class' attribute

         }elsif ($tag_name eq 'root'){
             &parse_root($l4p_tree, $kid);

         }elsif ($tag_name eq 'renderer'){
             warn "Log4perl: ignoring renderer tag in config, unimplemented";
             #"log4j will render the content of the log message according to 
             # user specified criteria. For example, if you frequently need 
             # to log Oranges, an object type used in your current project, 
             # then you can register an OrangeRenderer that will be invoked 
             # whenever an orange needs to be logged. "
         }
     }

     $doc->dispose;

     return $l4p_tree;

}

sub parse_root {
    my ($l4p_tree, $node) = @_;

    my $l4p_branch = {};

    &parse_children_of_logger_element($l4p_branch, $node);

    $l4p_tree->{category}{value} = $l4p_branch->{value};#inconsistent--fix later (kg)

}
   

sub parse_category {
    my ($l4p_tree, $node) = @_;

    my $name = $node->getAttribute('name');

    $l4p_tree->{category} ||= {};
    $l4p_tree->{additivity} ||= {};
 
    my $ptr = $l4p_tree->{category};

    for my $part (split /\.|::/, $name) {
        $ptr->{$part} = {} unless exists $ptr->{$part};
        $ptr = $ptr->{$part};
        #++$how_deep;
    }

    my $l4p_branch = $ptr;

    my $class = $node->getAttribute('class');
    $class                       && 
       $class ne 'Log::Log4perl' &&
       $class ne 'org.apache.log4j.Logger' &&
       warn "setting category $name to class $class ignored, only Log::Log4perl implemented";

    #this is kind of funky, additivity has its own spot in the tree
    my $additivity = $node->getAttribute('additivity');
    print "addt is --$additivity--\n";
    if (length $additivity > 0) {
        my $add_ptr = $l4p_tree->{additivity};

        for my $part (split /\.|::/, $name) {
            print "+++pqrt is $part\n";
            $add_ptr->{$part} = {} unless exists $add_ptr->{$part};
            $add_ptr = $add_ptr->{$part};
        }
        $add_ptr->{value} = &parse_boolean($additivity);
    }

    &parse_children_of_logger_element($l4p_branch, $node);

    $ptr  = $l4p_branch;
}

sub parse_children_of_logger_element {
    my ($l4p_branch, $node) = @_;

    my (@appenders, $priority);


    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        if ($tag_name eq 'param') {
            my $name = $child->getAttribute('name');
            my $value = $child->getAttribute('value');
            if ($value =~ /(all|debug|info|warn|error|fatal|off|null)/) {
                $value = uc $value;
            }
            print "parse cole: got param $name = $value\n"  if DEBUG;
            $l4p_branch->{$name} = {value => $value};
        #}elsif ($tag_name eq 'param-nested'){ #log4perl only
        #    parse param-nested
        #       can be param, param-text, param-nested
        #
        #}elsif ($tag_name eq 'param-text'){ #log4perl only
        #    my $name = $child->getAttribute('name');
        #    my $value = $child->getText;
        #    if ($value =~ /(all|debug|info|warn|error|fatal|off|null)/) {
        #        $value = uc $value;
        #    }
        #    print "parse cole: got param $name = $value\n"  if DEBUG;
        #    $l4p_branch->{$name} = {value => $value};
        #
        }elsif ($tag_name eq 'appender-ref'){
            push @appenders, $child->getAttribute('ref');
            #DEBUG!!!! q.v.
        }elsif ($tag_name eq 'level' || $tag_name eq 'priority'){
            $priority = &parse_level($child);
        }
    }
    $l4p_branch->{value} = $priority.', '.join(',', @appenders);
}


#DEBUG!! what about user-defined, will work?  can do in xml?
sub parse_level {
    my $node = shift;

    my $level = uc ($node->getAttribute('value'));

    die "Log4perl: invalid level in config: $level"
        unless Log::Log4perl::Level::is_valid($level);

    return $level;
}



sub parse_appender {
    my ($l4p_tree, $node) = @_;

    my $name = $node->getAttribute("name");

    my $l4p_branch = {};

    my $class = $node->getAttribute("class");

    $l4p_branch->{value} = $class;

    print "looking at $name----------------------\n"  if DEBUG;

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        if ($tag_name eq 'param') {
            my $name = $child->getAttribute('name');
            my $value = $child->getAttribute('value');
            print "parse_appender: got param $name = $value\n"  if DEBUG;

            if ($value =~ /(all|debug|info|warn|error|fatal|off|null)/) {
                $value = uc $value;
            }

            $l4p_branch->{$name} = {value => $value};
        }elsif ($tag_name eq 'layout'){
            $l4p_branch->{layout} = parse_layout($child);
        }elsif ($tag_name eq 'filter'){
            die "filters not supported yet";
        }elsif ($tag_name eq 'errorHandler'){
            die "errorHandlers not supported yet";
        }elsif ($tag_name eq 'appender-ref'){
            #dtd: Appenders may also reference (or include) other appenders. -->
            #TDB DEBUG!!!
            die "Log4perl: in config file, appender-ref unsupported in <appender>";

        }
    }
    $l4p_tree->{appender}{$name} = $l4p_branch;
}

sub parse_layout {
    my $node = shift;

    my $layout_tree = {};

    my $class_name = $node->getAttribute('class');
    
    $layout_tree->{value} = $class_name;
    #
    print "\tparsing layout $class_name\n"  if DEBUG;  
    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;
        if ($child->getTagName() eq 'param') {
            my $name = $child->getAttribute('name');
            my $value = $child->getAttribute('value');
            if ($value =~ /(all|debug|info|warn|error|fatal|off|null)/) {
                $value = uc $value;
            }
            print "\tparse_layout: got param $name = $value\n"  if DEBUG;
            $layout_tree->{$name}{value} = $value;  #DEBUG!!! --is this right in cases other than ConversionPattern?
        }
    }
    return $layout_tree;
}

sub parse_boolean {
    my $a = shift;

    if ($a eq '0' || lc $a eq 'false') {
        return '0';
    }elsif ($a eq '1' || lc $a eq 'true'){
        return '1';
    }else{
        return $a; #probably an error, punt
    }
}

1;

__END__

=head1 NAME

Log::Log4perl::Config::DOMConfigurator - reads xml

=head1 SYNOPSIS

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE log4j:configuration SYSTEM "log4j.dtd">

    <log4j:configuration xmlns:log4j="http://jakarta.apache.org/log4j/">

    <appender name="FileAppndr1" class="org.apache.log4j.FileAppender">
        <layout class="Log::Log4perl::Layout::PatternLayout">
                <param name="ConversionPattern"
                       value="%d %4r [%t] %-5p %c %t - %m%n"/>
        </layout>
        <param name="File" value="t/tmp/DOMtest"/>
        <param name="Append" value="false"/>
    </appender>

    <category name="a.b.c.d" additivity="false">
        <level value="warn"/>  <!-- note lowercase! -->
        <appender-ref ref="FileAppndr1"/>
    </category>

   <root>
        <priority value="warn"/>
        <appender-ref ref="FileAppndr1"/>
   </root>

   </log4j:configuration>



=head1 DESCRIPTION

This parses an XML file that conforms to the log4j.dtd, q.v.  It currently
does B<not> handle any of the log4perl extensions we've been coming 
up with, but that should hopefully follow shortly.

You use it just like you would a properties config but if the data starts 
with an xml declaration C<<\?xml ...> then it gets parsed by this DOMConfigurator instead of the PropertiesConfigurator.

Note that you need XML::DOM installed.

The code is brazenly modeled on log4j's DOMConfigurator class, (by 
Christopher Taylor, Ceki Gülcü and Anders Kristensen) and any
perceived similarity is not coincidental.

=head1 CAVEAT

It is still (version 0.02 Jan-2002) very fresh, alpha software, please 
check it out thoroughly before use and let me know if you find
any problems.

=head1 SEE ALSO

t/038XML-DOM1.t for examples

Log::Log4perl::Config

Log::Log4perl::Config::PropertyConfigurator

Log::Log4perl::Config::LDAPConfigurator (coming soon!)

=head1 AUTHOR

Kevin Goess, <cpan@goess.org> Jan-2003

=cut
