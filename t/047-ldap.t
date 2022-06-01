###########################################
# Test Suite for LDAP appenders
# Kevin Goess, 2004 (cpan@goess.org)
#
# To run this test, you need to ... DEBUG
# 


#NOTE: the LDAP stuff is all experimental and in-progress,
#not meant to be used for ANYTHING yet --kg 5/2004

=pod 

L4P_DO_LDAP_TESTS=1 \
LOG4PERL_LDAP_USERDN='cn=log4perluser,dc=people,dc=goess,dc=org' \
LOG4PERL_LDAP_PWD=54321 \
LDAP_HOST=localhost \
LDAP_BASE=dc=testsystem,dc=log4perl,dc=goess,dc=org \
perl -Ilib -Iblib/lib t/047-ldap.t


L4P_DO_LDAP_TESTS=1 \
LOG4PERL_LDAP_USERDN='uid=kgoess,ou=People,dc=mrs.hudson,dc=goess,dc=org' \
LOG4PERL_LDAP_PWD=ldap123 \
LDAP_HOST=localhost \
LDAP_BASE=dc=l4ptest,dc=system,dc=mrs.hudson,dc=goess,dc=org \
perl -Ilib -Iblib/lib t/047-ldap.t


=cut

#
###########################################

#Note: should handle ldaps as well DEBUG

BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use warnings;
use strict;

use Test::More;

use Log::Log4perl qw(get_logger);

plan skip_all => 'L4P_DO_LDAP_TESTS not set' if !$ENV{L4P_DO_LDAP_TESTS};
require Net::LDAP;
require URI::ldap;

Log::Log4perl->init(\qq{
  log4perl.category = INFO, LDAPapp
  log4perl.appender.LDAPapp = Log::Log4perl::Appender::TestBuffer
  log4perl.appender.LDAPapp.layout = Log::Log4perl::Layout::PatternLayout
  log4perl.appender.LDAPapp.layout.ConversionPattern = N:%m
});

my $uri = URI->new("ldap:");  # start empty

$uri->host($ENV{LDAP_HOST});  #see above for run values
$uri->dn($ENV{LDAP_BASE});    #see above
#$uri->attributes(qw(postalAddress));
$uri->scope('sub');
#$uri->filter('(cn=Babs Jensen)');
#   ldap://localhost/dc=testsystem,dc=log4perl,dc=goess,dc=org??sub?

   
#ldap://localhost/dc=testsystem,dc=log4perl,dc=goess,dc=org??sub?

my $ldapdata = Log::Log4perl::Config::config_read(
    $uri->as_string
);

my $WORK_DIR = tmpdir();
my $propsconfig = <<EOL;
log4j.appender.A1 = Log::Log4perl::Appender::TestBuffer
log4j.appender.A1.layout = Log::Log4perl::Layout::SimpleLayout

log4j.appender.A2 = Log::Log4perl::Appender::TestBuffer
log4j.appender.A2.layout = Log::Log4perl::Layout::SimpleLayout
#
 log4j.appender.BUF0 = Log::Log4perl::Appender::TestBuffer
 log4j.appender.BUF0.layout = Log::Log4perl::Layout::SimpleLayout
 log4j.appender.BUF0.Threshold = ERROR
#
 #DEBUG: need to test log4j translations
 #log4j.appender.FileAppndr1 = org.apache.log4j.FileAppender
 #log4j.appender.FileAppndr1.layout = Log::Log4perl::Layout::PatternLayout
 #log4j.appender.FileAppndr1.layout.ConversionPattern = %d %4r [%t] %-5p %c %t - %m%n
 #log4j.appender.FileAppndr1.File = $WORK_DIR/DOMtest
 #log4j.appender.FileAppndr1.mode = append
 
 log4j.appender.FileAppndr1 = Log::Log4perl::Appender::FileAppender
 log4j.appender.FileAppndr1.layout = Log::Log4perl::Layout::PatternLayout 
 log4j.appender.FileAppndr1.layout.ConversionPattern = %d %4r [%t] %-5p %c %t - %m%n
 log4j.appender.FileAppndr1.filename = $WORK_DIR/DOMtest
 log4j.appender.FileAppndr1.mode = append
 log4j.appender.FileAppndr1.autoflush = 1
#DEBUG todo log4j.appender.FileAppndr1.umask = 0222
 
#
 log4j.category.a.b.c.d = WARN, A1
 log4j.category.a.b = INFO, A1
#
 log4j.category.xa.b.c.d = INFO, A2,BUF0
 log4j.category.xa.b = WARN, A2

 log4j.category.animal = INFO, FileAppndr1
 log4j.category.animal.dog = INFO, FileAppndr1,A2

 log4j.category = WARN, FileAppndr1

# log4j.threshold = DEBUG
#
# log4j.additivity.a.b.c.d = 0

EOL

my $propsdata = Log::Log4perl::Config::config_read(\$propsconfig);

diag explain $ldapdata;
print STDERR "\n--------------\n";
diag explain $propsdata;
is_deeply($ldapdata, $propsdata);
done_testing;
