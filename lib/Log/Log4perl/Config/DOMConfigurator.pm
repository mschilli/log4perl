package Log::Log4perl::Config::DOMConfigurator;
#todo
# appender-ref -- dup'd or ref'd?
# some params not attrs but values, like <sql>...</sql>
# see DEBUG!!!  below
# check multiple appenders in a category
# need docs in Config.pm re URL loading, steal from XML::DOM
# see PropConfigurator re importing unlog4j, eval_if_perl
#  need to handle 0/1, true/false?

use XML::DOM;
use Log::Log4perl::Level;
use strict;

print STDERR __PACKAGE__."is a work in progress, this is an intermediate CVS check-in\n";
print STDERR "DO NOT USE\n";

use constant DEBUG => 1;


sub parse {
    my ($text) = @_;

    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parse (join('',@$text));


     my $l4p_tree = {};
    
     my $config = $doc->getElementsByTagName('log4j:configuration')->item(0);
     for my $kid ($config->getChildNodes){
         next unless $kid->getNodeType == ELEMENT_NODE;
         my $tag_name = $kid->getTagName;
         print "got $tag_name\n" if DEBUG;
         if ($tag_name eq 'appender') {
             &parse_appender($l4p_tree, $kid);
         }elsif ($tag_name eq 'category'){
             &parse_category($l4p_tree, $kid);
         }elsif ($tag_name eq 'root'){
             &parse_root($l4p_tree, $kid);
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

    my $additivity = $node->getAttribute('additivity');
    $additivity && ($l4p_branch->{additivity} = $additivity);

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
            print "got param $name = $value\n"  if DEBUG;
            $l4p_branch->{$name} = {value => $value};
        }elsif ($tag_name eq 'appender-ref'){
            push @appenders, $child->getAttribute('ref');
            #DEBUG!!!! q.v.
        }elsif ($tag_name eq 'level'){
            $priority = &parse_level($child);
        }elsif ($tag_name eq 'priority'){
            $priority = &parse_priority($child);
        }
    }
    $l4p_branch->{value} = $priority.', '.join(',', @appenders);
}


#DEBUG!! what about user-defined, will work?  can do in xml?
sub parse_level {
    my $node = shift;

    my $level = $node->getAttribute('value');

    my $level_str = Log::Log4perl::Level::to_level($level);

    print "*** got level $level_str***\n"  if DEBUG;
    return $level_str;
}

sub parse_priority {
    my $node = shift;

    my $priority = uc($node->getAttribute('value'));

    Log::Log4perl::Level::to_priority($priority);  #will croak if invalid

    print "*** got priority $priority***\n"  if DEBUG;
    return $priority;
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
            print "got param $name = $value\n"  if DEBUG;
            $l4p_branch->{$name} = {value => $value};
        }elsif ($tag_name eq 'layout'){
            $l4p_branch->{layout} = parse_layout($child);
        }elsif ($tag_name eq 'filter'){
            die "filters not supported yet";
        }elsif ($tag_name eq 'errorHandler'){
            die "errorHandlers not supported yet";
        }elsif ($tag_name eq 'appender-ref'){
            #DEBUG!!! hey, are these dup'd or ref'd?

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
            print "\tgot param $name = $value\n"  if DEBUG;
            $layout_tree->{$name}{value} = $value;  #DEBUG!!! --is this right in cases other than ConversionPattern?
        }
    }
    return $layout_tree;
}

1;

__END__
