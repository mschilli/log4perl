#NOTE: this LDAP stuff is experimental, in progress,
#not meant to be used for ANYTHING yet --kg 5/2004

package Log::Log4perl::Config::LDAPConfigurator;
use Log::Log4perl::Config::BaseConfigurator;
our @ISA = qw(Log::Log4perl::Config::BaseConfigurator);

use Net::LDAP;
use URI;
use Log::Log4perl::Level;
use Data::Dump qw(dump); #DEBUG
use Carp;
use strict;

use constant _INTERNAL_DEBUG => 1;

our $VERSION = 0.01;

#poor man's export
*eval_if_perl = \&Log::Log4perl::Config::eval_if_perl;
*unlog4j      = \&Log::Log4perl::Config::unlog4j;


############################################
sub parse {
############################################
    my($self, $newtext) = @_;

    $self->text($newtext) if defined $newtext;

    my $uri = $self->{text}->[0];

    $uri = 
        URI->new($uri); #ldap://localhost/dc=testsystem,dc=log4perl,dc=goess,dc=org??sub?



    my ($userdn, $passwd, $ldap, $mesg, $host, $base, $searchString, $scope);

    $userdn = $ENV{LOG4PERL_LDAP_USERDN};   #cn=log4perluser,dc=people,dc=goess,dc=org
    $passwd = $ENV{LOG4PERL_LDAP_PWD};  #note not very secure
    #http://www.faqs.org/rfcs/rfc2255.html
    #   Some authentication methods, in particular reusable passwords sent to
    #   the server, may reveal easily-abused information to the remote server
    #   or to eavesdroppers in transit, and should not be used in URL
    #   processing unless explicitly permitted by policy.

    eval {
        #DEBUG need to check for presence of necessary strings
        $host = $uri->host;   #localhost
        $base = $uri->dn;    #"dc=testsystem,dc=log4perl,dc=goess,dc=org" ;
        $searchString = $uri->filter;#"(objectclass=*)";
        $scope = $uri->scope || 'sub';

        $ldap = Net::LDAP->new ( "localhost" ) or die "$@";

        $mesg = $ldap->bind ( $userdn,           
                             ($passwd ? (password => $passwd) : (noauth => 1)),
                              version => 3 ); 
    
        #DEBUG, check authentication failures
        if ( $mesg->code ) {
            die $mesg->error;
        }
    };
    if ($@) {
        die "log4perl: LDAP unable to bind to $uri:\n$@";
    }

    my $result = $ldap->search ( base    => $base,
                                 scope   => $scope,
                                 filter  => $searchString, #"sn=*"
                                 attrs   =>  [] , #arrayref
                                );

    #DEBUG where are errors here?
    #if ($result->code) {
    #    die $mesg->error;
    #}

    my $l4p_tree = {};

    foreach my $entry ($result->all_entries){
        my $objectclasses = join("\n",$entry->get_value('objectclass'));
        if ($objectclasses =~ /^log4(perl|j)Appender/m) { #DEBUG, make a constant?
            parse_appender($l4p_tree, $entry);

        }elsif ($objectclasses =~ /^log4(perl|j)Layout/m) { 
            parse_layout($l4p_tree, $entry);

        }elsif ($objectclasses =~ /^log4(perl|j)RootLogger/m) { 
            my $level = $entry->get_value("log4perlLevel");
            my @appenders = $entry->get_value("log4perlAppenderName");
            map {s/ +$//} @appenders;#ldap preserves trailing spaces :-(

            $l4p_tree->{category}{value} = $level;
            $l4p_tree->{category}{value} .= ", ".join(',',@appenders);

        }elsif ($objectclasses =~ /^log4(perl|j)(Logger|Category)/m) { 
            parse_category($l4p_tree, $entry);
        }else{
            ;#?
        }
    }

    #my $href = $result->as_struct;
    ##DEBUG, keys don't seem to be normalized?
    #dump $href;

    $mesg = $ldap->unbind;   # take down session

    return $l4p_tree;
}

sub parse_appender {
    my ($l4p_tree, $entry) = @_;
    #foreach my $attr ($entry->attributes) {
    #    print STDERR join( "\n ", $attr, $entry->get_value( $attr ) ), "\n";
    #}

    my $name = subst($entry->get_value("name"));

    my $l4p_branch = {};

    my $class = subst($entry->get_value("log4perlclass")); #DEBUG: handle log4j

    $l4p_branch->{value} = $class;

    print "looking at $name----------------------\n"  if _INTERNAL_DEBUG;

    $l4p_tree->{appender}{$name} = $l4p_branch;

    my ($attrname, $attrvalue);

    foreach ($entry->attributes) {
       /^objectclass$/i        && next;
       /^log4perlclass$/i      && next; #already handled

       #a gross kind of translation?
       /^log4perl/   && do {
            ($attrname = $_)  =~ s/log4perl//;
            $attrvalue = $entry->get_attribute($_);

            #note the '->[0]', log4perl doesn't
            #accept any multi-valued attributes, does it?
            #DEBUG
            $attrvalue = $attrvalue->[0] if (ref $attrvalue eq 'ARRAY');

            if (lc $attrvalue =~ /true/) {
               $attrvalue = 1;
            }elsif (lc $attrvalue eq 'false'){
               $attrvalue = 0;
            }

       };
       next unless $attrname && defined $attrvalue;

       $l4p_branch->{$attrname} = {value => $attrvalue};
                     

    }

}
sub parse_layout {
    my ($l4ptree, $entry) = @_;

    my $layout_tree = {};

    my $class_name = subst($entry->get_value("log4perlLayoutClass"));

    my $dn = $entry->dn;

    $dn =~ /^name=layout,name=(.+?),/ 
       or do {
         warn "layout object at $dn doesn't seem to be in a spot wanting a layout, ",
               "like 'name=layout,name=<some appender>";
         return;
       };
    my $appender_name = $1;

    $l4ptree->{appender}{$appender_name}{layout} = $layout_tree;

    $layout_tree->{value} = $class_name;

    foreach ($entry->attributes) {
       /^objectclass$/i        && next;
       /^name$/i               && next; #is always 'layout'
       /^log4perlLayoutClass$/ && next; #already handled
       /^log4perlConversionPattern$/       && do 
          {
             $layout_tree->{ConversionPattern}
                   = {value => $entry->get_attribute($_)};
             next;
          };

    }

    return $layout_tree;
    
}

sub parse_category {
   my ($l4p_tree, $entry) = @_;

    my $category_name = subst($entry->get_value("log4perlCategoryName"));

    print STDERR "parsing category $category_name\n";

    $l4p_tree->{category} ||= {};
 
    my $ptr = $l4p_tree->{category};

    for my $part (split /\.|::/, $category_name) {
        $ptr->{$part} = {} unless exists $ptr->{$part};
        $ptr = $ptr->{$part};
    }

    my $l4p_branch = $ptr;

    my $level = $entry->get_value("log4perlLevel");
    my @appenders = $entry->get_value("log4perlAppenderName");
    map {s/ +$//} @appenders;#ldap preserves trailing spaces :-(

    $l4p_branch->{value} = $level;

    $l4p_branch->{value} .= ", ".join(',',@appenders);

    return $l4p_tree;
    
}



#all other code below is still from DOMConfigurator (kg 5/12)

=pod

    my $parser = $PARSER_CLASS->new;
    my $doc = $parser->parse (join('',@$text));


    my $l4p_tree = {};
    
    my $config = $doc->getElementsByTagName("$LOG4J_PREFIX:configuration")->item(0)||
                 $doc->getElementsByTagName("$LOG4PERL_PREFIX:configuration")->item(0);

    my $threshold = uc(subst($config->getAttribute('threshold')));
    if ($threshold) {
        $l4p_tree->{threshold}{value} = $threshold;
    }

    if (subst($config->getAttribute('oneMessagePerAppender')) eq 'true') {
        $l4p_tree->{oneMessagePerAppender}{value} = 1;
    }

    for my $kid ($config->getChildNodes){

        next unless $kid->getNodeType == ELEMENT_NODE;

        my $tag_name = $kid->getTagName;

        if ($tag_name =~ $APPENDER_TAG) {
            &parse_appender($l4p_tree, $kid);

        }elsif ($tag_name eq 'category' || $tag_name eq 'logger'){
            &parse_category($l4p_tree, $kid);
            #Treating them the same is not entirely accurate, 
            #the dtd says 'logger' doesn't accept
            #a 'class' attribute while 'category' does.
            #But that's ok, log4perl doesn't do anything with that attribute

        }elsif ($tag_name eq 'root'){
            &parse_root($l4p_tree, $kid);

        }elsif ($tag_name =~ $FILTER_TAG){
            #parse log4perl's chainable boolean filters
            &parse_l4p_filter($l4p_tree, $kid);

        }elsif ($tag_name eq 'renderer'){
            warn "Log4perl: ignoring renderer tag in config, unimplemented";
            #"log4j will render the content of the log message according to 
            # user specified criteria. For example, if you frequently need 
            # to log Oranges, an object type used in your current project, 
            # then you can register an OrangeRenderer that will be invoked 
            # whenever an orange needs to be logged. "
         
        }elsif ($tag_name eq 'PatternLayout'){#log4perl only
            &parse_patternlayout($l4p_tree, $kid);
        }
    }
    $doc->dispose;

    return $l4p_tree;

}

#this is just for toplevel log4perl.PatternLayout tags
#holding the custome cspecs
sub parse_patternlayout {
    my ($l4p_tree, $node) = @_;

    my $l4p_branch = {};

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $name = subst($child->getAttribute('name'));
        my $value;

        foreach my $grandkid ($child->getChildNodes){
            if ($grandkid->getNodeType == TEXT_NODE) {
                $value .= $grandkid->getData;
            }
        }
        $value =~ s/^ +//;  #just to make the unit tests pass
        $value =~ s/ +$//;
        $l4p_branch->{$name}{value} = subst($value);
    }
    $l4p_tree->{PatternLayout}{cspec} = $l4p_branch;
}


#for parsing the root logger, if any
sub parse_root {
    my ($l4p_tree, $node) = @_;

    my $l4p_branch = {};

    &parse_children_of_logger_element($l4p_branch, $node);

    $l4p_tree->{category}{value} = $l4p_branch->{value};

}


#this parses a custom log4perl-specific filter set up under
#the root element, as opposed to children of the appenders
sub parse_l4p_filter {
    my ($l4p_tree, $node) = @_;

    my $l4p_branch = {};

    my $name = subst($node->getAttribute('name'));

    my $class = subst($node->getAttribute('class'));
    my $value = subst($node->getAttribute('value'));

    if ($class && $value) {
        die "Log4perl: only one of class or value allowed, not both, "
            ."in XMLConfig filter '$name'";
    }elsif ($class || $value){
        $l4p_branch->{value} = ($value || $class);

    }

    for my $child ($node->getChildNodes) {

        if ($child->getNodeType == ELEMENT_NODE){

            my $tag_name = $child->getTagName();

            if ($tag_name =~ /^(param|param-nested|param-text)$/) {
                &parse_any_param($l4p_branch, $child);
            }
        }elsif ($child->getNodeType == TEXT_NODE){
            my $text = $child->getData;
            next unless $text =~ /\S/;
            if ($class && $value) {
                die "Log4perl: only one of class, value or PCDATA allowed, "
                    ."in XMLConfig filter '$name'";
            }
            $l4p_branch->{value} .= subst($text); 
        }
    }

    $l4p_tree->{filter}{$name} = $l4p_branch;
}

   
#for parsing a category/logger element
sub parse_category {
    my ($l4p_tree, $node) = @_;

    my $name = subst($node->getAttribute('name'));

    $l4p_tree->{category} ||= {};
 
    my $ptr = $l4p_tree->{category};

    for my $part (split /\.|::/, $name) {
        $ptr->{$part} = {} unless exists $ptr->{$part};
        $ptr = $ptr->{$part};
    }

    my $l4p_branch = $ptr;

    my $class = subst($node->getAttribute('class'));
    $class                       && 
       $class ne 'Log::Log4perl' &&
       $class ne 'org.apache.log4j.Logger' &&
       warn "setting category $name to class $class ignored, only Log::Log4perl implemented";

    #this is kind of funky, additivity has its own spot in the tree
    my $additivity = subst(subst($node->getAttribute('additivity')));
    if (length $additivity > 0) {
        $l4p_tree->{additivity} ||= {};
        my $add_ptr = $l4p_tree->{additivity};

        for my $part (split /\.|::/, $name) {
            $add_ptr->{$part} = {} unless exists $add_ptr->{$part};
            $add_ptr = $add_ptr->{$part};
        }
        $add_ptr->{value} = &parse_boolean($additivity);
    }

    &parse_children_of_logger_element($l4p_branch, $node);
}

# parses the children of a category element
sub parse_children_of_logger_element {
    my ($l4p_branch, $node) = @_;

    my (@appenders, $priority);

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;
            
        my $tag_name = $child->getTagName();

        if ($tag_name eq 'param') {
            my $name = subst($child->getAttribute('name'));
            my $value = subst($child->getAttribute('value'));
            if ($value =~ /^(all|debug|info|warn|error|fatal|off|null)^/) {
                $value = uc $value;
            }
            $l4p_branch->{$name} = {value => $value};
        
        }elsif ($tag_name eq 'appender-ref'){
            push @appenders, subst($child->getAttribute('ref'));
            
        }elsif ($tag_name eq 'level' || $tag_name eq 'priority'){
            $priority = &parse_level($child);
        }
    }
    $l4p_branch->{value} = $priority.', '.join(',', @appenders);
    
    return;
}


sub parse_level {
    my $node = shift;

    my $level = uc (subst($node->getAttribute('value')));

    die "Log4perl: invalid level in config: $level"
        unless Log::Log4perl::Level::is_valid($level);

    return $level;
}



sub parse_appender {
    my ($l4p_tree, $node) = @_;

    my $name = subst($node->getAttribute("name"));

    my $l4p_branch = {};

    my $class = subst($node->getAttribute("class"));

    $l4p_branch->{value} = $class;

    print "looking at $name----------------------\n"  if _INTERNAL_DEBUG;

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        my $name = unlog4j(subst($child->getAttribute('name')));

        if ($tag_name =~ /^(param|param-nested|param-text)$/) {

            &parse_any_param($l4p_branch, $child);

            my $value;

        }elsif ($tag_name =~ /($LOG4PERL_PREFIX:)?layout/){
            $l4p_branch->{layout} = parse_layout($child);

        }elsif ($tag_name =~  $FILTER_TAG){
            $l4p_branch->{Filter} = parse_filter($child);

        }elsif ($tag_name =~ $FILTER_REF_TAG){
            $l4p_branch->{Filter} = parse_filter_ref($child);

        }elsif ($tag_name eq 'errorHandler'){
            die "errorHandlers not supported yet";

        }elsif ($tag_name eq 'appender-ref'){
            #dtd: Appenders may also reference (or include) other appenders. 
            #This feature in log4j is only for appenders who implement the 
            #AppenderAttachable interface, and the only one that does that
            #is the AsyncAppender, which writes logs in a separate thread.
            #I don't see the need to support this on the perl side any 
            #time soon.  --kg 3/2003
            die "Log4perl: in config file, <appender-ref> tag is unsupported in <appender>";
        }else{
            die "Log4perl: in config file, <$tag_name> is unsupported\n";
        }
    }
    $l4p_tree->{appender}{$name} = $l4p_branch;
}

sub parse_any_param {
    my ($l4p_branch, $child) = @_;

    my $tag_name = $child->getTagName();
    my $name = subst($child->getAttribute('name'));
    my $value;

    print "parse_any_param: <$tag_name name=$name\n" if _INTERNAL_DEBUG;

    #<param-nested>
    #note we don't set it to { value => $value }
    #and we don't test for multiple values
    if ($tag_name eq 'param-nested'){
        
        if ($l4p_branch->{$name}){
            die "Log4perl: in config file, multiple param-nested tags for $name not supported";
        }
        $l4p_branch->{$name} = &parse_param_nested($child); 

        return;

    #<param>
    }elsif ($tag_name eq 'param') {

         $value = subst($child->getAttribute('value'));

         print "parse_param_nested: got param $name = $value\n"  
             if _INTERNAL_DEBUG;
        
         if ($value =~ /^(all|debug|info|warn|error|fatal|off|null)$/) {
             $value = uc $value;
         }

         if ($name !~ /warp_message|filter/ &&
            $child->getParentNode->getAttribute('name') ne 'cspec') {
            $value = eval_if_perl($value);
         }
    #<param-text>
    }elsif ($tag_name eq 'param-text'){

        foreach my $grandkid ($child->getChildNodes){
            if ($grandkid->getNodeType == TEXT_NODE) {
                $value .= $grandkid->getData;
            }
        }
        if ($name !~ /warp_message|filter/ &&
            $child->getParentNode->getAttribute('name') ne 'cspec') {
            $value = eval_if_perl($value);
        }
    }

    $value = subst($value);

     #multiple values for the same param name
     if (defined $l4p_branch->{$name}{value} ) {
         if (ref $l4p_branch->{$name}{value} ne 'ARRAY'){
             my $temp = $l4p_branch->{$name}{value};
             $l4p_branch->{$name}{value} = [$temp];
         }
         push @{$l4p_branch->{$name}{value}}, $value;
     }else{
         $l4p_branch->{$name} = {value => $value};
     }
}

#handles an appender's <param-nested> elements
sub parse_param_nested {
    my ($node) = shift;

    my $l4p_branch = {};

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        if ($tag_name =~ /^param|param-nested|param-text$/) {
            &parse_any_param($l4p_branch, $child);
        }
    }

    return $l4p_branch;
}

#this handles filters that are children of appenders, as opposed
#to the custom filters that go under the root element
sub parse_filter {
    my $node = shift;

    my $filter_tree = {};

    my $class_name = subst($node->getAttribute('class'));

    $filter_tree->{value} = $class_name;

    print "\tparsing filter on class $class_name\n"  if _INTERNAL_DEBUG;  

    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;

        my $tag_name = $child->getTagName();

        if ($tag_name =~ 'param|param-nested|param-text') {
            &parse_any_param($filter_tree, $child);
        
        }else{
            die "Log4perl: don't know what to do with a ".$child->getTagName()
                ."inside a filter element";
        }
    }
    return $filter_tree;
}

sub parse_filter_ref {
    my $node = shift;

    my $filter_tree = {};

    my $filter_id = subst($node->getAttribute('id'));

    $filter_tree->{value} = $filter_id;

    return $filter_tree;
}



sub parse_layout {
    my $node = shift;

    my $layout_tree = {};

    my $class_name = subst($node->getAttribute('class'));
    
    $layout_tree->{value} = $class_name;
    #
    print "\tparsing layout $class_name\n"  if _INTERNAL_DEBUG;  
    for my $child ($node->getChildNodes) {
        next unless $child->getNodeType == ELEMENT_NODE;
        if ($child->getTagName() eq 'param') {
            my $name = subst($child->getAttribute('name'));
            my $value = subst($child->getAttribute('value'));
            if ($value =~ /^(all|debug|info|warn|error|fatal|off|null)$/) {
                $value = uc $value;
            }
            print "\tparse_layout: got param $name = $value\n"
                if _INTERNAL_DEBUG;
            $layout_tree->{$name}{value} = $value;  

        }elsif ($child->getTagName() eq 'cspec') {
            my $name = subst($child->getAttribute('name'));
            my $value;
            foreach my $grandkid ($child->getChildNodes){
                if ($grandkid->getNodeType == TEXT_NODE) {
                    $value .= $grandkid->getData;
                }
            }
            $value =~ s/^ +//;
            $value =~ s/ +$//;
            $layout_tree->{cspec}{$name}{value} = subst($value);  
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

=cut 

#this handles variable substitution
sub subst {
    my $val = shift;

    $val =~ s/\${(.*?)}/
                      Log::Log4perl::Config::var_subst($1, {})/gex;
    return $val;
}




1;

__END__

=encoding utf8

=head1 NAME

Log::Log4perl::Config::LDAPConfigurator - configures log4perl via LDAP

=head1 SYNOPSIS


=head1 DESCRIPTION

This module implements 

=head1 WHY


=head1 HOW

=head1 VARIABLE SUBSTITUTION

???

This supports variable substitution like C<${foobar}> in text and in 
attribute values except for appender-ref.  If an environment variable is defined
for that name, its value is substituted. So you can do stuff like

        <param name="${hostname}" value="${hostnameval}.foo.com"/>
        <param-text name="to">${currentsysadmin}@foo.com</param-text>


=head1 REQUIRES

=head1 CAVEATS

=head1 CHANGES

0.01 2004-05-12 initial version

=head1 SEE ALSO

t/047-ldap.t


ldap/log4perl.schema DEBUG

Log::Log4perl::Config

=head1 LICENSE

Copyright 2002-2013 by Mike Schilli E<lt>m@perlmeister.comE<gt> 
and Kevin Goess E<lt>cpan@goess.orgE<gt>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=head1 AUTHOR

Please contribute patches to the project on Github:

    http://github.com/mschilli/log4perl

Send bug reports or requests for enhancements to the authors via our

MAILING LIST (questions, bug reports, suggestions/patches): 
log4perl-devel@lists.sourceforge.net

Authors (please contact them via the list above, not directly):
Mike Schilli <m@perlmeister.com>,
Kevin Goess <cpan@goess.org>

Contributors (in alphabetical order):
Ateeq Altaf, Cory Bennett, Jens Berthold, Jeremy Bopp, Hutton
Davidson, Chris R. Donnelly, Matisse Enzer, Hugh Esco, Anthony
Foiani, James FitzGibbon, Carl Franks, Dennis Gregorovic, Andy
Grundman, Paul Harrington, Alexander Hartmaier  David Hull, 
Robert Jacobson, Jason Kohles, Jeff Macdonald, Markus Peter, 
Brett Rann, Peter Rabbitson, Erik Selberg, Aaron Straup Cope, 
Lars Thegler, David Viner, Mac Yang.

