#!/usr/bin/perl
##########################################################################
# Synchronizing appender output with Log::Log4perl::Appender::Synchronized.
# This test uses fork and a semaphore to get two appenders to get into
# each other/s way.
# Mike Schilli, 2003 (m@perlmeister.com)
##########################################################################

BEGIN { 
    if($ENV{INTERNAL_DEBUG}) {
        require Log::Log4perl::InternalDebug;
        Log::Log4perl::InternalDebug->enable();
    }
}

use strict;
use warnings;
use Test::More;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
use constant INTERNAL_DEBUG => 0;
our $INTERNAL_DEBUG = 0;

$| = 1;

BEGIN {
plan skip_all => "- only with L4P_ALL_TESTS" if !exists $ENV{"L4P_ALL_TESTS"};
}

use Log::Log4perl::Util::Semaphore;
use Log::Log4perl qw(get_logger);
use Log::Log4perl::Appender::Synchronized;

my $EG_DIR = "eg";
$EG_DIR = "../eg" unless -d $EG_DIR;

my $logfile = "$EG_DIR/fork.log";

our $lock;
our $locker_key  = "abc";

unlink $logfile;

#goto SECOND;

#print "tie\n";
my $locker1 = Log::Log4perl::Util::Semaphore->new(
    key     => $locker_key,
);

print $locker1->status_as_string, "\n" if INTERNAL_DEBUG;

my $conf = qq(
log4perl.category.Bar.Twix          = WARN, Syncer

log4perl.appender.Logfile           = Log::Log4perl::Appender::TestFileCreeper
log4perl.appender.Logfile.autoflush = 1
log4perl.appender.Logfile.filename  = $logfile
log4perl.appender.Logfile.layout    = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %F{1}%L> %m%n

log4perl.appender.Syncer           = Log::Log4perl::Appender::Synchronized
log4perl.appender.Syncer.appender  = Logfile
log4perl.appender.Syncer.key       = blah
#log4perl.appender.Syncer.destroy   = 1
);

$locker1->semlock();

Log::Log4perl::init(\$conf);

my $pid = fork();

die "fork failed" unless defined $pid;

my $logger = get_logger("Bar::Twix");
if($pid) {
   #parent
   $locker1->semlock();
   #print "Waiting for child\n";
   for(1..10) {
       #print "Parent: Writing\n";
       $logger->error("X" x 4097);
   }
} else { 
   #child
   $locker1->semunlock();
   for(1..10) {
       #print "Child: Writing\n";
       $logger->error("Y" x 4097);
   }
   exit 0;
}

   # Wait for child to finish
print "Waiting for pid $pid\n" if $INTERNAL_DEBUG;
waitpid($pid, 0);
print "Done waiting for pid $pid\n" if $INTERNAL_DEBUG;

my $clashes_found = 0;

open FILE, "<", "$logfile" or die "Cannot open $logfile";
while(<FILE>) {
    if(/XY/ || /YX/) {
        $clashes_found = 1;
        last;
    }
}
close FILE;

unlink $logfile;
#print $logfile, "\n";
#exit 0;

ok(! $clashes_found, "Checking for clashes in logfile");

###################################################################
# Test the Socket appender
###################################################################

use IO::Socket::INET;

SECOND:

unlink $logfile;

#print "tie\n";
my $locker2 = Log::Log4perl::Util::Semaphore->new(
    key     => $locker_key,
);

$conf = q{
    log4perl.category                  = WARN, Socket
    log4perl.appender.Socket           = Log::Log4perl::Appender::Socket
    log4perl.appender.Socket.PeerAddr  = localhost
    log4perl.appender.Socket.PeerPort  = 12345
    log4perl.appender.Socket.layout    = SimpleLayout
};

print "1 Semunlock\n" if $INTERNAL_DEBUG;
print $locker2->status_as_string, "\n" if INTERNAL_DEBUG;
$locker2->semunlock();
print "1 Done semunlock\n" if $INTERNAL_DEBUG;

print "2 Semlock\n" if $INTERNAL_DEBUG;
print $locker2->status_as_string, "\n" if INTERNAL_DEBUG;
$locker2->semlock();
print "2 Done semlock\n" if $INTERNAL_DEBUG;

#print "forking\n";
$pid = fork();

die "fork failed" unless defined $pid;

if($pid) {
   #parent
   #print "Waiting for child\n";
   print "Before semlock\n" if $INTERNAL_DEBUG;
   $locker2->semlock();
   print "Done semlock\n" if $INTERNAL_DEBUG;

   {
       my $client = IO::Socket::INET->new( PeerAddr => 'localhost',
                                           PeerPort => 12345,
                                         );

       #print "Checking connection\n";

       if(defined $client) {
           #print "Client defined, sending test\n";
           eval { $client->send("test\n") };
           if($@) {
               #print "Send failed ($!), retrying ...\n";
               sleep(1);
               redo;
           }
       } else {
           #print  "Server not responding yet ($!) ... retrying\n";
           sleep(1);
           redo;
       }
       $client->close();
   }

   Log::Log4perl::init(\$conf);
   $logger = get_logger("Bar::Twix");
   #print "Sending message\n";
   $logger->error("Greetings from the client");
} else { 
   #child

   #print STDERR "child starting\n";
   my $sock = IO::Socket::INET->new(
       Listen    => 5,
       LocalAddr => 'localhost',
       LocalPort => 12345,
       ReuseAddr => 1,
       Proto     => 'tcp');

   die "Cannot start server: $!" unless defined $sock;
       # Ready to receive
   #print "Server started\n";
   print "Before semunlock\n" if $INTERNAL_DEBUG;
   $locker2->semunlock();
   print "After semunlock\n" if $INTERNAL_DEBUG;

   my $nof_messages = 2;

   open FILE, ">", "$logfile" or die "Cannot open $logfile";
   while(my $client = $sock->accept()) {
       #print "Client connected\n";
       while(<$client>) {
           print FILE "$_\n";
           last;
       }
       last unless --$nof_messages;
   }

   close FILE;
   exit 0;
}

   # Wait for child to finish
print "Waiting for pid $pid\n" if $INTERNAL_DEBUG;
waitpid($pid, 0);
print "Done waiting for pid $pid\n" if $INTERNAL_DEBUG;

open FILE, "<", "$logfile" or die "Cannot open $logfile";
my $data = join '', <FILE>;
close FILE;

unlink $logfile;

like($data, qr/Greetings/, "Check logfile of Socket appender");

###################################################################
# Test the "silent_recover" options of the Socket appender
###################################################################

use IO::Socket::INET;

our $TMP_FILE = "warnings.txt";
END { unlink $TMP_FILE if defined $TMP_FILE; }

# Capture STDERR to a temporary file and a filehandle to read from it
open STDERR, ">", "$TMP_FILE";
open IN, "<", "$TMP_FILE" or die "Cannot open $TMP_FILE";
sub readwarn { return scalar <IN>; }

$conf = q{
    log4perl.category                        = WARN, Socket
    log4perl.appender.Socket                 = Log::Log4perl::Appender::Socket
    log4perl.appender.Socket.PeerAddr        = localhost
    log4perl.appender.Socket.PeerPort        = 12345
    log4perl.appender.Socket.layout          = SimpleLayout
    log4perl.appender.Socket.silent_recovery = 1
};

    # issues a warning
Log::Log4perl->init(\$conf);

like(readwarn(), qr/Connection refused/, 
     "Check if warning occurs on dead socket");

$logger = get_logger("foobar");

    # silently ignored
$logger->warn("message lost");

$locker2->semunlock();
$locker2->semlock();

    # Now start a server
$pid = fork();

if($pid) {
   #parent

       # wait for child
   #print "Waiting for server to start\n";
   $locker2->semlock();
   
       # Send another message (should be sent)
   #print "Sending message\n";
   $logger->warn("message sent");
} else { 
   #child

       # Start a server
   my $sock = IO::Socket::INET->new(
       Listen    => 5,
       LocalAddr => 'localhost',
       LocalPort => 12345,
       ReuseAddr => 1,
       Proto     => 'tcp');

   die "Cannot start server: $!" unless defined $sock;
       # Ready to receive
   #print "Server started\n";
   $locker2->semunlock();

   my $nof_messages = 1;

   open FILE, ">", "$logfile" or die "Cannot open $logfile";
   while(my $client = $sock->accept()) {
       #print "Client connected\n";
       while(<$client>) {
           #print "Got message: $_\n";
           print FILE "$_\n";
           last;
       }
       last unless --$nof_messages;
   }

   close FILE;
   exit 0;
}

   # Wait for child to finish
print "Waiting for pid $pid\n" if $INTERNAL_DEBUG;
waitpid($pid, 0);
print "Done waiting for pid $pid\n" if $INTERNAL_DEBUG;

open FILE, "<", "$logfile" or die "Cannot open $logfile";
$data = join '', <FILE>;
close FILE;

#print "data=$data\n";

unlink $logfile;

unlike($data, qr/message lost/, "Check logfile for lost message");
like($data, qr/message sent/, "Check logfile for sent message");

# $locker2 has the same semid, no need to remove

my $locker3 = Log::Log4perl::Util::Semaphore->new(
    key     => "xyz",
);
my $locker4 = Log::Log4perl::Util::Semaphore->new(
    key     => "xyz",
);

$locker1->remove;
$locker3->remove;

done_testing;
