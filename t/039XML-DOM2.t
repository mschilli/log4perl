
use Test;
use Log::Log4perl;
use strict;
use Data::Dumper;

our $no_XMLDOM;

BEGIN {
    eval {
        require XML::DOM;
    };
    if ($@) {
        print STDERR "XML::DOM not installed, skipping tests\n";
        $no_XMLDOM = 1;
        plan tests => 1;
    }else{
        plan tests => 1;
    }
}

if ($no_XMLDOM){
    ok(1);
    exit(0);
}


my $xmlconfig = <<'EOL';
<?xml version="1.0" encoding="UTF-8"?> 
<!DOCTYPE log4perl:configuration SYSTEM "log4perl.dtd">

<log4perl:configuration xmlns:log4perl="http://log4perl.sourceforge.net/"
    threshold="debug" oneMessagePerAppender="true">
    
<log4perl:appender name="jabbender" class="Log::Dispatch::Jabber">
          <param-nested name="login">
                <param name="hostname" value="a.jabber.server"/>
                <param name="password" value="12345"/>
                <param name="port" value="5222"/>
                <param name="resource" value="logger"/>
                <param name="username" value="bobjones"/>
         </param-nested>
         <param-nested name="to">
                <param-item>bob@a.jabber.server</param-item>
                <param-item>mary@another.jabber.server</param-item>
          </param-nested>
          <layout class="Log::Log4perl::Layout::SimpleLayout"/>
         
</log4perl:appender>
<log4perl:appender name="DBAppndr2" class="Log::Log4perl::Appender::DBI">
          <param name="warp_message" value="0"/>
          <param name="datasource" value="DBI:CSV:f_dir=t/tmp"/>
          <param name="bufferSize" value="2"/>
          <param name="password" value="sub { $ENV{PWD} }"/>
           <param name="username" value="bobjones"/>
          
          <param-text name="sql">insert into log4perltest (loglevel, message, shortcaller, thingid, category, pkg, runtime1, runtime2) values (?,?,?,?,?,?,?,?)</param-text> 
           <param-nested name="params">
                <param name="1" value="%p"/>
                <param name="3" value="%5.5l"/>
                <param name="5" value="%c"/>
                <param name="6" value="%C"/>
           </param-nested>
           <param-nested name="cspec">
                <param-text name="G">sub {'winstonchurchill'}</param-text>
           </param-nested>
                
           <layout class="Log::Log4perl::Layout::NoopLayout"/>
         
</log4perl:appender>
<category name="animal.dog">
           <priority value="info"/>
           <appender-ref ref="jabbender"/>
</category>

<PatternLayout>
    <cspec name="G"><![CDATA[sub { return "UID $< GID $("; }]]></cspec>
</PatternLayout>


</log4perl:configuration>
EOL


#Log::Log4perl::init(\$config);

my $xmldata = Log::Log4perl::Config::config_read(\$xmlconfig);

my $propsconfig = <<'EOL';

log4j.category.animal.dog   = INFO, jabbender
log4j.threshold = DEBUG

log4j.oneMessagePerAppender=1

log4j.PatternLayout.cspec.G=sub { return "UID $< GID $("; }

log4j.appender.jabbender          = Log::Dispatch::Jabber
log4j.appender.jabbender.layout   = Log::Log4perl::Layout::SimpleLayout
log4j.appender.jabbender.login.hostname = a.jabber.server
log4j.appender.jabbender.login.port = 5222
log4j.appender.jabbender.login.username = bobjones
log4j.appender.jabbender.login.password = 12345
log4j.appender.jabbender.login.resource = logger
log4j.appender.jabbender.to = bob@a.jabber.server
log4j.appender.jabbender.to = mary@another.jabber.server

log4j.appender.DBAppndr2             = Log::Log4perl::Appender::DBI
log4j.appender.DBAppndr2.username  = bobjones
log4j.appender.DBAppndr2.datasource = DBI:CSV:f_dir=t/tmp
log4j.appender.DBAppndr2.password = sub { $ENV{PWD} }
log4j.appender.DBAppndr2.sql = insert into log4perltest (loglevel, message, shortcaller, thingid, category, pkg, runtime1, runtime2) values (?,?,?,?,?,?,?,?)
log4j.appender.DBAppndr2.params.1 = %p    
log4j.appender.DBAppndr2.params.3 = %5.5l
log4j.appender.DBAppndr2.params.5 = %c
log4j.appender.DBAppndr2.params.6 = %C
log4j.appender.DBAppndr2.cspec.G = sub {'winstonchurchill'}

log4j.appender.DBAppndr2.bufferSize=2
log4j.appender.DBAppndr2.warp_message=0
    
#noop layout to pass it through
log4j.appender.DBAppndr2.layout    = Log::Log4perl::Layout::NoopLayout


EOL



my $propsdata = Log::Log4perl::Config::config_read(\$propsconfig);

#brute force testing here, not very granular, but it is thorough
#use Data::Dump qw(dump);
#ok(dump($xmldata),dump($propsdata));
ok(Dumper($xmldata),Dumper($propsdata));


