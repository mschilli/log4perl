#testing user-defined conversion specifiers (cspec)

use Test;
use Log::Log4perl;
use Log::Log4perl::TestBuffer;

Log::Log4perl::TestBuffer->reset();


my $config = <<'EOL';
log4j.category.plant    = DEBUG, appndr1
log4j.category.animal   = DEBUG, appndr2

#'U' a global user-defined cspec
log4j.PatternLayout.cspec.U =       \
        sub {                       \
            return "UID $< GID $("; \
        }                           \
    
  
# ********************
# first appender
log4j.appender.appndr1        = Log::Log4perl::TestBuffer
#log4j.appender.appndr1        = Log::Dispatch::Screen
log4j.appender.appndr1.layout = org.apache.log4j.PatternLayout
log4j.appender.appndr1.layout.ConversionPattern = %K xx %G %U

#'K' cspec local to appndr1                 (pid in hex)
log4j.appender.appndr1.layout.cspec.K = sub { return sprintf "%1x", $$}

#'G' cspec unique to appdnr1
log4j.appender.appndr1.layout.cspec.G = sub {return 'thisistheGcspec'}

    

# ********************
# second appender
log4j.appender.appndr2        = Log::Log4perl::TestBuffer
#log4j.appender.appndr2        = Log::Dispatch::Screen
log4j.appender.appndr2.layout = org.apache.log4j.PatternLayout
log4j.appender.appndr2.layout.ConversionPattern = %K %U

#'K' cspec local to appndr2
log4j.appender.appndr2.layout.cspec.K =                              \
    sub {                                                            \
        my ($self, $message, $category, $priority, $caller_level) = @_; \
        $message =~ /--- (.+) ---/;                                  \
        my $snippet = $1;                                            \
        return ucfirst(lc($priority)).'-'.$snippet.'-'.ucfirst(lc($priority));                 \
      }
      
#override global 'U' cspec
log4j.appender.appndr2.layout.cspec.U = sub {return 'foobar'}
      
EOL


Log::Log4perl::init(\$config);

my $plant = Log::Log4perl::get_logger('plant');
my $animal = Log::Log4perl::get_logger('animal');


my $hexpid = sprintf "%1x", $$;
my $uid = $<;
my $gid = $(;


my $plantbuffer = Log::Log4perl::TestBuffer->by_name("appndr1");
my $animalbuffer = Log::Log4perl::TestBuffer->by_name("appndr2");

$plant->fatal('blah blah blah --- plant --- yadda yadda');
ok($plantbuffer->buffer(), "$hexpid xx thisistheGcspec UID $uid GID $gid");
$plantbuffer->reset;

$animal->fatal('blah blah blah --- animal --- yadda yadda');
ok($animalbuffer->buffer(), "Fatal-animal-Fatal foobar");
$animalbuffer->reset;

$plant->error('blah blah blah --- plant --- yadda yadda');
ok($plantbuffer->buffer(), "$hexpid xx thisistheGcspec UID $uid GID $gid");
$plantbuffer->reset;

$animal->error('blah blah blah --- animal --- yadda yadda');
ok($animalbuffer->buffer(), "Error-animal-Error foobar");
$animalbuffer->reset;

$plant->warn('blah blah blah --- plant --- yadda yadda');
ok($plantbuffer->buffer(), "$hexpid xx thisistheGcspec UID $uid GID $gid");
$plantbuffer->reset;

$animal->warn('blah blah blah --- animal --- yadda yadda');
ok($animalbuffer->buffer(), "Warn-animal-Warn foobar");
$animalbuffer->reset;

$plant->info('blah blah blah --- plant --- yadda yadda');
ok($plantbuffer->buffer(), "$hexpid xx thisistheGcspec UID $uid GID $gid");
$plantbuffer->reset;

$animal->info('blah blah blah --- animal --- yadda yadda');
ok($animalbuffer->buffer(), "Info-animal-Info foobar");
$animalbuffer->reset;

$plant->debug('blah blah blah --- plant --- yadda yadda'); 
ok($plantbuffer->buffer(), "$hexpid xx thisistheGcspec UID $uid GID $gid");
$plantbuffer->reset;

$animal->debug('blah blah blah --- animal --- yadda yadda'); 
ok($animalbuffer->buffer(), "Debug-animal-Debug foobar");
$animalbuffer->reset;


#now test the api call we're adding

Log::Log4perl::Layout::PatternLayout::add_global_cspec('Z', sub {'zzzzzzzz'}); #snooze?


my $app = Log::Log4perl::Appender->new(
    "Log::Log4perl::TestBuffer");

my $logger = Log::Log4perl->get_logger("abc.def.ghi");
$logger->add_appender($app);
my $layout = Log::Log4perl::Layout::PatternLayout->new(
    "%m %Z");
$app->layout($layout);
$logger->debug("That's the message");

ok($app->buffer(), "That's the message zzzzzzzz");


BEGIN { plan tests => 11, }
