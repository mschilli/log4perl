package PPM::Make;
use strict;
#use warnings;
use PPM::Make::Util qw(:all);
use Config::IniFiles;
use Cwd;
use Pod::Find qw(pod_find contains_pod);
use File::Basename;
use File::Path;
use File::Find;
use File::Copy;
use Config;
use CPAN;
use Net::FTP;
use LWP::Simple qw(getstore is_success);
require File::Spec;
use Pod::Html;
use Safe;
use YAML qw(LoadFile);
use Log::Log4perl qw(:easy);

our ($VERSION);
$VERSION = '0.67';

my $protocol = $PPM::Make::Util::protocol;
my $ext = $PPM::Make::Util::ext;
my $no_case = 0;
my $html = 'blib/html';

sub new {
  my ($class, %opts) = @_;

  die "\nInvalid option specification" unless check_opts(%opts);
  
  $opts{zip} = 1 if ($opts{binary} and $opts{binary} =~ /\.zip$/);

  my ($arch, $os) = arch_and_os($opts{arch}, $opts{os}, $opts{noas});
  my $has = what_have_you($opts{program}, $arch, $os);
  
  my %cfg;
#  $opts{no_cfg} = 1 if $opts{install};
  unless ($opts{no_cfg}) {
    if (my $file = get_cfg_file()) {
      %cfg = read_cfg($file, $arch) or die "\nError reading config file";
    }
  }  
  my $opts = %cfg ? merge_opts(\%cfg, \%opts) : \%opts;

  $no_case = 1 if defined $opts->{no_case};
  my $self = {
	      opts => $opts || {},
	      cwd => '',
	      has => $has,
	      args => {},
	      ppd => '',
	      archive => '',
              prereq_pm => {},
	      file => '',
	      version => '',
              use_mb => '',
	      ARCHITECTURE => $arch,
	      OS => $os,
	     };
  bless $self, $class;
}

sub check_opts {
  my %opts = @_;
  my %legal = 
    map {$_ => 1} qw(force ignore binary zip remove program cpan
                     dist script exec os arch arch_sub add no_as vs upload
                     no_case no_cfg);
  foreach (keys %opts) {
    next if $legal{$_};
    warn "Unknown option '$_'\n";
    return;
  }

  if (defined $opts{add}) {
    unless (ref($opts{add}) eq 'ARRAY') {
      warn "Please supply an ARRAY reference to 'add'";
      return;
    }
  }

  if (defined $opts{program} and my $progs = $opts{program}) {
    unless (ref($progs) eq 'HASH') {
      warn "Please supply a HASH reference to 'program'";
      return;
    }
    my %ok = map {$_ => 1} qw(zip unzip tar gzip make);
    foreach (keys %{$progs}) {
      next if $ok{$_};
      warn "Unknown program option '$_'\n";
      return;
    }
  }
  
  if (defined $opts{upload} and my $upload = $opts{upload}) {
    unless (ref($upload) eq 'HASH') {
      warn "Please supply an HASH reference to 'upload'";
      return;
    }
    my %ok = map {$_ => 1} qw(ppd ar host user passwd);
    foreach (keys %{$upload}) {
      next if $ok{$_};
      warn "Unknown upload option '$_'\n";
      return;
    }
  }
  return 1;
}

sub arch_and_os {
  my ($opt_arch, $opt_os, $opt_noas) = @_;

  my ($arch, $os);
  if (defined $opt_arch) {
    $arch = ($opt_arch eq "") ? undef : $opt_arch;
  }
  else {
    $arch = $Config{archname};
    unless ($opt_noas) {
      if (length($^V) && ord(substr($^V, 1)) >= 8) {
	$arch .= sprintf("-%d.%d", ord($^V), ord(substr($^V, 1)));
      }
    }
  }
  if (defined $opt_os) {
    $os = ($opt_os eq "") ? undef : $opt_os;
  }
  else {
    $os = $Config{osname};
  }
  return ($arch, $os);
}

sub get_cfg_file {
  my $file;
  if (defined $ENV{PPM_CFG} and my $env = $ENV{PPM_CFG}) {
    if (-e $env) {
      $file = $env;
    }
    else {
      warn qq{Cannot find '$env' from \$ENV{PPM_CFG}};
    }
  }
  else {
    my $home = (WIN32 ? '/.ppmcfg' : "$ENV{HOME}/.ppmcfg");
    $file = $home if (-e $home);
  }
  return $file;
}

sub read_cfg {
  my ($file, $arch) = @_;
  my $default = 'default';
  my $cfg = Config::IniFiles->new(-file => $file, -default => $default);
  my @p;
  push @p, $cfg->Parameters($default) if ($cfg->SectionExists($default));
  push @p, $cfg->Parameters($arch) if ($cfg->SectionExists($arch));
  unless (@p > 1) {
    warn "No default or section for $arch found";
    return;
  }
  
  my $on = qr!^(on|yes)$!;
  my $off = qr!^(off|no)$!;
  my %legal_progs = map {$_ => 1} qw(tar gzip make perl);
  my %legal_upload = map {$_ => 1} qw(ppd ar host user passwd); 
  my (%cfg, %programs, %upload);
  foreach (@p) {
    my $val = $cfg->val($arch, $_);
    $val = 1 if ($val =~ /$on/i);
    if ($val =~ /$off/i) {
      delete $cfg{$_};
      next;
    }
    if ($_ eq 'add') {
      $cfg{$_} = [split ' ', $val];
      next;
    }
    if ($legal_progs{$_}) {
      $programs{$_} = $val;
    }
    elsif ($legal_upload{$_}) {
      $upload{$_} = $val;
    }
    else {
      $cfg{$_} = $val;
    }
  }
  $cfg{program} = \%programs if %programs;
  $cfg{upload} = \%upload if %upload;
  return check_opts(%cfg) ? %cfg : undef;
}

# merge two hashes, assuming the second one takes precedence 
# over the first in the case of duplicate keys
sub merge_opts {
  my ($h1, $h2) = @_;
  my %opts = (%{$h1}, %{$h2});
  if (defined $h1->{add} or defined $h2->{add}) {
    my @a;
    push @a, @{$h1->{add}} if $h1->{add};
    push @a, @{$h2->{add}} if $h2->{add};
    my %add = map {$_ => 1} @a;
    $opts{add} = [keys %add];
  }
  for (qw(program upload)) {
    next unless (defined $h1->{$_} or defined $h2->{$_});
    my %h = ();
    if (defined $h1->{$_}) {
      if (defined $h2->{$_}) {
	%h = (%{$h1->{$_}}, %{$h2->{$_}});
      }
      else {
	%h = %{$h1->{$_}};
      }
    }
    else {
      %h = %{$h2->{$_}};     
    }
    $opts{$_} = \%h;
  }
  return \%opts;
}

sub make_ppm {
  my $self = shift;
  die 'No software available to make a zip archive'
     if ($self->{opts}->{zip} and not $self->{has}->{zip});
  my $dist = $self->{opts}->{dist};
  if ($dist) {
    my $build_dir = $PPM::Make::Util::build_dir;
    chdir $build_dir or die "Cannot chdir to $build_dir: $!";
#    print "Working directory: $build_dir\n"; 
    die $ERROR unless ($dist = fetch_file($dist, no_case => $no_case));
#      if ($dist =~ m!$protocol! 
#          or $dist =~ m!^\w/\w\w/! or $dist !~ m!$ext!);
    print "Extracting files from $dist ....\n";
    my $name = $self->extract_dist($dist, $build_dir);
    chdir $name or die "Cannot chdir to $name: $!";
    $self->{file} = $dist;
  }
  die "Need a Makefile.PL or Build.PL to build"
    unless (-f 'Makefile.PL' or -f 'Build.PL');
  my $force = $self->{opts}->{force};
  $self->{cwd} = cwd;
  print "Working directory: $self->{cwd}\n";
  my $mb = -e 'Build.PL';
  $self->{mb} = $mb;
  die "This distribution requires Module::Build to build" 
    if ($mb and not HAS_MB);
  $self->check_script() if $self->{opts}->{script};
  $self->check_files() if $self->{opts}->{add};
  $self->adjust_binary() if $self->{opts}->{arch_sub};
  $self->build_dist() 
    unless (-d 'blib' and (-f 'Makefile' or ($mb and -f 'Build')) 
            and not $force);
  $self->parse_yaml if (-e 'META.yml');
  if ($mb) {
    $self->parse_build();
  }
  else {
#    $self->parse_makepl();
    $self->parse_make()
        unless ($self->{args}->{NAME} and $self->{args}->{AUTHOR});
  }
  $self->abstract();
  $self->author();
  $self->{version} = ($self->{args}->{VERSION} ||
                      parse_version($self->{args}->{VERSION_FROM}) ) 
    or warn "Could not extract version information";
  $self->make_html() unless (-d 'blib/html' and not $force);
  $dist = $self->make_dist();
  $self->make_ppd($dist);
#  if ($self->{opts}->{install}) {
#    die 'Must have the ppm utility to install' unless HAS_PPM;
#    $self->ppm_install();
#  }
  $self->make_cpan() if $self->{opts}->{cpan};
  if (defined $self->{opts}->{upload}) {
    die 'Please specify the location to place the ppd file'
      unless $self->{opts}->{upload}->{ppd}; 
    $self->upload_ppm();
  }
}

sub check_script {
  my $self = shift;
  my $script = $self->{opts}->{script};
  return if ($script =~ m!$protocol!);
  my ($name, $path, $suffix) = fileparse($script, '\..*');
  my $file = $name . $suffix;
  $self->{opts}->{script} = $file;
  return if (-e $file);
  copy($script, $file) or die "Copying $script to $self->{cwd} failed: $!";
}

sub check_files {
  my $self = shift;
  my @entries = ();
  foreach my $file (@{$self->{opts}->{add}}) {
    my ($name, $path, $suffix) = fileparse($file, '\..*');
    my $entry = $name . $suffix;
    push @entries, $entry;
    next if (-e $entry);
    copy($file, $entry) or die "Copying $file to $self->{cwd} failed: $!";
  }
  $self->{opts}->{add} = \@entries if @entries;
}

sub extract_dist {
  my ($self, $file, $build_dir) = @_;

  my $has = $self->{has};
  my ($tar, $gzip, $unzip) = @$has{qw(tar gzip unzip)};

  my ($name, $path, $suffix) = fileparse($file, $ext);
  if (-d "$build_dir/$name") {
      rmtree("$build_dir/$name", 1, 0) 
          or die "rmtree of $name failed: $!";
  }
 EXTRACT: {
    if ($suffix eq '.zip') {
      ($unzip eq 'Archive::Zip') && do {
	my $arc = Archive::Zip->new();
        die "Read of $file failed" unless $arc->read($file) == AZ_OK();
	$arc->extractTree();
	last EXTRACT;
      };
      ($unzip) && do {
	my @args = ($unzip, $file);
	print "@args\n";
	system(@args) == 0 or die "@args failed: $?";
	last EXTRACT;
      };

    }
    else {
      ($tar eq 'Archive::Tar') && do {
	my $arc = Archive::Tar->new($file, 1);
	$arc->extract($arc->list_files);
	last EXTRACT;
      };
      ($tar and $gzip) && do {
	my @args = ($gzip, '-dc', $file, '|', $tar, 'xvf', '-');
	print "@args\n";
	system(@args) == 0 or die "@args failed: $?";
	last EXTRACT;
      };
    }
    die "Cannot extract $file";
  }
  return $name;
}

sub adjust_binary {
  my $self = shift;
  my $binary = $self->{opts}->{binary};
  my $archname = $self->{ARCHITECTURE};
  return unless $archname;
  if ($binary) {
    if ($binary =~ m!$ext!) {
      if ($binary =~ m!/!) {
	$binary =~ s!(.*?)([\w\-]+)$ext!$1$archname/$2$3!;
      }
      else {
	$binary = $archname . '/' . $binary;
      }
    }
    else {
      $binary =~ s!/$!!;
      $binary .= '/' . $archname . '/';	
    }
  }
  else {
    $binary = $archname . '/';
  }
  $self->{opts}->{binary} = $binary;
}

sub build_dist {
  my $self = shift;
  my $binary = $self->{opts}->{binary};
  my $script = $self->{opts}->{script};
  my $exec = $self->{opts}->{exec};

  my $has = $self->{has};
  my ($make, $perl) = @$has{qw(make perl)};
  my $mb = $self->{mb};

  my $makepl = $mb ? 'Build.PL' : 'Makefile.PL';
  my @args = ($perl, $makepl);
  if (not $mb and my $makepl_arg = $CPAN::Config->{makepl_arg}) {
    push @args, (split ' ', $makepl_arg);
  }
  print "@args\n";
  system(@args) == 0 or die qq{@args failed: $?};

#  if ($mb) {
#    my $file = 'Build.PL';
#    unless (my $r = do $file) {
#      die "Can't parse $file: $@" if $@;
#      die "Can't do $file: $!" unless defined $r;
#      die "Can't run $file" unless $r;
#    }
#  }
#  else {
#    $self->write_makefile();
#  }

  my $build = 'Build';
  @args = $mb ? ($perl, $build) : ($make);
  if (not $mb and my $make_arg = $CPAN::Config->{make_arg}) {
    push @args, (split ' ', $make_arg);
  }
  print "@args\n";
  system(@args) == 0 or die "@args failed: $?";
 
  @args = $mb ? ($perl, $build, 'test') : ($make, 'test');
  print "@args\n";
#  unless (system(@args) == 0) {
#    die "@args failed: $?" unless $self->{opts}->{ignore};
#    warn "@args failed: $?";
#  }
  return 1;
}

sub parse_build {
  my $self = shift;
  my $bp = '_build/build_params';
#  open(my $fh, $bp) or die "Couldn't open $bp: $!";
#  my @lines = <$fh>;
#  close $fh;
#  my $content = join "\n", @lines;
#  my $c = new Safe();
#  my $r = $c->reval($content);
#  if ($@) {
#    warn "Eval of $bp failed: $@";
#    return;
#  }
  my $file = $self->{cwd} . '/_build/build_params';
  my $r;
  unless ($r = do $file) {
    die "Can't parse $file: $@" if $@;
    die "Can't do $file: $!" unless defined $r;
    die "Can't run $file" unless $r;
  }
  
  my $props = $r->[2];
  my %r = ( NAME => $props->{module_name},
            DISTNAME => $props->{dist_name},
            VERSION => $props->{dist_version},
            VERSION_FROM => $props->{dist_version_from},
            PREREQ_PM => $props->{requires},
            AUTHOR => $props->{dist_author},
            ABSTRACT => $props->{dist_abstract},
          );
  foreach (keys %r) {
      next unless $r{$_};
      $self->{args}->{$_} ||= $r{$_};
  }
  return 1;
}

sub parse_yaml {
  my $self = shift;
  my $props = LoadFile('META.yml');
  my %r = ( NAME => $props->{name},
            DISTNAME => $props->{distname},
            VERSION => $props->{version},
            VERSION_FROM => $props->{version_from},
            PREREQ_PM => $props->{requires},
            AUTHOR => $props->{author},
            ABSTRACT => $props->{abstract},
          );
  foreach (keys %r) {
    next unless $r{$_};
    $self->{args}->{$_} ||= $r{$_};
  }
  return 1;
}

sub parse_makepl {
  my $self = shift;
  open(my $fh, 'Makefile.PL') or die "Couldn't open Makefile.PL: $!";
  my @lines = <$fh>;
  close $fh;
  my $makeargs;
  my $content = join "\n", @lines;
  $content =~ s!\r!!g;
  $content =~ m!WriteMakefile(\s*\(.*?\bNAME\b.*?\))\s*;!s;
  unless ($makeargs = $1) {
    warn "Couldn't extract WriteMakefile args";
    return;
  }

  my $c = new Safe();
  my %r = $c->reval($makeargs);
  if ($@) {
    warn "Eval of Makefile.PL failed: $@";
    return;
  }
  unless ($r{NAME}) {
    warn "Cannot determine NAME in Makefile.PL";
    return;
  }
  foreach (keys %r) {
      next unless $r{$_};
      $self->{args}->{$_} ||= $r{$_};
  }
  return 1;
}

sub parse_make {
  my $self = shift;
  my $flag = 0;
  my @wanted = qw(NAME DISTNAME ABSTRACT ABSTRACT_FROM AUTHOR 
                  VERSION VERSION_FROM PREREQ_PM);
  my $re = join '|', @wanted;
  my @lines;
  open(my $fh, 'Makefile') or die "Couldn't open Makefile: $!";
  while (<$fh>) {
    if (not $flag and /MakeMaker Parameters/) {
      $flag = 1;
      next;
    }
    next unless $flag;
    last if /MakeMaker post_initialize/;
    next unless /$re/;
    chomp;
    s/^#*\s+// or next;
    push @lines, $_;
  }
  close($fh);
  my $make = join ',', @lines;
  $make = '(' . $make . ')';
  my $c = new Safe();
  my %r = $c->reval($make);
  die "Eval of Makefile failed: $@" if ($@);
  die 'Cannot determine NAME in Makefile' unless $r{NAME};
  for (@wanted) {
    next unless $r{$_};
    $self->{args}->{$_} ||= $r{$_};
  }
  return 1;
}

sub write_makefile {
  my $self = shift;
  my $r;
  my $cwd = $self->{cwd};
  my $file = 'Makefile.PL';
 MAKE: {
    local @ARGV;
    if (my $makepl_arg = $CPAN::Config->{makepl_arg}) {
      push @ARGV, (split ' ', $makepl_arg);
    }
    unless ($r = do "$cwd/$file") {
      die "Can't parse $file: $@" if $@;
      die "Can't do $file: $!" unless defined $r;
      die "Can't run $file" unless $r;
    }
  }
  my @wanted = qw(NAME DISTNAME ABSTRACT ABSTRACT_FROM AUTHOR 
                  VERSION VERSION_FROM PREREQ_PM);
  my %wanted;
  foreach (@wanted) {
    next unless defined $r->{$_};
    $wanted{$_} = $r->{$_};
  }
  $self->{args} = $r;
  return 1;
}

sub abstract {
  my $self = shift;
  my $args = $self->{args};
  unless ($args->{ABSTRACT}) {
    if (my $abstract = $self->guess_abstract()) {
      warn "Setting ABSTRACT to '$abstract'\n";
      $self->{args}->{ABSTRACT} = $abstract;
    }
    else {
      warn "Please check ABSTRACT in the ppd file\n";
    }
  }
}

sub guess_abstract {
  my $self = shift;
  my $args = $self->{args};
  my $cwd = $self->{cwd};
  my $result;
  for my $guess(qw(ABSTRACT_FROM VERSION_FROM)) {
    if (my $file = $args->{$guess}) {
      print "Trying to get ABSTRACT from $file ...\n";
      $result = parse_abstract($args->{NAME}, $file);
      return $result if $result;
    }
  }
  my ($hit, $guess);
  for my $ext (qw(pm pod)) {
    if ($args->{NAME} =~ /-|:/) {
      ($guess = $args->{NAME}) =~ s!.*[-:](.*)!$1.$ext!;
    }
    else {
      $guess = $args->{NAME} . ".$ext";
    }
    finddepth(sub{$_ eq $guess && ($hit = $File::Find::name) 
		    && ($hit !~ m!blib/!)}, $cwd);
    next unless (-f $hit);
    print "Trying to get ABSTRACT from $hit ...\n";
    $result = parse_abstract($args->{NAME}, $hit);
    return $result if $result;
  }
  return;
}

sub parse_abstract {
  my ($package, $file) = @_;
  my $basename = basename($file, qr/\.\w+$/);
  (my $stripped = $basename) =~ s!\.\w+$!!;
  (my $trans = $package) =~ s!-!::!g;
  my $result;
  my $inpod = 0;
  open(my $fh, $file) or die "Couldn't open $file: $!";
  while (<$fh>) {
    $inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
    next if !$inpod;
    chop;
    next unless /^\s*($package|$basename|$stripped|$trans)\s+--*\s+(.*)/;
    $result = $2;
    last;
  }
  close($fh);
  chomp($result);
  return $result;
}

sub author {
  my $self = shift;
  my $args = $self->{args};
  unless ($args->{AUTHOR}) {
    if (my $author = $self->guess_author()) {
      $self->{args}->{AUTHOR} = $author;
    }
    else {
      warn "Please check AUTHOR in the ppd file\n";
    }
  }
}

sub guess_author {
  my $self = shift;
  my $args = $self->{args};
  if (HAS_CPAN) {
    (my $mod = $args->{NAME}) =~ s!-!::!g;
    print "Trying to get AUTHOR from CPAN.pm ...\n";
    my $module = CPAN::Shell->expand('Module', $mod);
    unless ($module) {
      for (qw(VERSION_FROM ABSTRACT_FROM)) {
        if (my $from = $args->{$_}) {
          $from =~ s!^lib/!!;
          $from =~ s!\.pm$!!;
          $from =~ s!/!::!g;
          last if $module = CPAN::Shell->expand('Module', $from);
        }
      }
    }
    return unless $module;
    return unless (my $userid = $module->cpan_userid);
    return unless (my $author = CPAN::Shell->expand('Author', $userid));
    my $auth_string = $author->fullname;
    my $email = $author->email;
    $auth_string .= ' &lt;' . $email . '&gt;' if $email;
    if ($auth_string) {
      warn qq{Setting AUTHOR to "$auth_string"\n};
      return $auth_string;
    }
  }
  my $cwd = $self->{cwd};
  my $result;
  if (my $version_from = $args->{VERSION_FROM}) {
    print "Trying to get AUTHOR from $version_from ...\n";
    if ($result = parse_author($version_from)) {
      warn qq{Setting AUTHOR to "$result" (may require editing)\n};
      return $result;
    }
  }
  my ($hit, $guess);
  for my $ext (qw(pm pod)) {
    if ($args->{NAME} =~ /-|:/) {
      ($guess = $args->{NAME}) =~ s!.*[-:](.*)!$1.$ext!;
    }
    else {
      $guess = $args->{NAME} . ".$ext";
    }
    finddepth(sub{$_ eq $guess && ($hit = $File::Find::name) 
		    && ($hit !~ m!blib/!)}, $cwd);
    next unless (-f $hit);
    print "Trying to get AUTHOR from $hit ...\n";
    if ($result = parse_author($hit)) {
      warn qq{Setting AUTHOR to "$result" (may require editing)\n};
      return $result;
    }
  }
  return;
}

sub parse_author {
  my $file = shift;
  open(my $fh, $file) or die "Couldn't open $file: $!";
  my @author;
  local $_;
  while (<$fh>) {
    next unless /^=head1\s+AUTHOR/ ... /^=/;
    next if /^=/;
    push @author, $_;
  }
  close $fh;
  return unless @author;
  my $author = join '', @author;
  $author =~ s/^\s+|\s+$//g;
  return $author;
}

sub make_html {
  my $self = shift;
  my $args = $self->{args};
  my $cwd = $self->{cwd};
  unless (-d $html) {
    mkpath($html, 1, 0755) or die "Couldn't mkdir $html: $!";
  }
  my %pods = pod_find({-verbose => 1}, "$cwd/blib/");
  if (-d "$cwd/blib/script/") {
    finddepth( sub 
	       {$pods{$File::Find::name} = 
		  "script::" . basename($File::Find::name) 
		    if (-f $_ and not /\.bat$/ and contains_pod($_));
	      }, "$cwd/blib/script");
  }

  foreach my $pod (keys %pods){
    my @dirs = split /::/, $pods{$pod};
    my $isbin = shift @dirs eq 'script';

    (my $infile = File::Spec->abs2rel($pod)) =~ s!^\w+:!!;
    $infile =~ s!\\!/!g;
    my $outfile = (pop @dirs) . '.html';

    my @rootdirs  = $isbin? ('bin') : ('site', 'lib');
    (my $path2root = "../" x (@rootdirs+@dirs)) =~ s|/$||;
    
    (my $fulldir = File::Spec->catfile($html, @rootdirs, @dirs)) =~ s!\\!/!g;
    unless (-d $fulldir){
      mkpath($fulldir, 1, 0755) 
	or die "Couldn't mkdir $fulldir: $!";  
    }
    ($outfile = File::Spec->catfile($fulldir, $outfile)) =~ s!\\!/!g;
    
    my $htmlroot = "$path2root/site/lib";
    my $podroot = "$cwd/blib";
    my $podpath = join ":" => map { $podroot . '/' . $_ }  
      ($isbin ? qw(bin lib) : qw(lib));
    (my $package = $pods{$pod}) =~ s!^(lib|script)::!!;
    my $abstract = parse_abstract($package, $infile);
    my $title =  $abstract ? "$package - $abstract" : $package;
    my @opts = (
		'--header',
		"--title=$title",
		"--infile=$infile",
		"--outfile=$outfile",
		"--podroot=$podroot",
		"--htmlroot=$htmlroot",
		"--css=$path2root/Active.css",
	       );
    print "pod2html @opts\n";
    pod2html(@opts);# or warn "pod2html @opts failed: $!";
  }
  ###################################
}

sub make_dist {
  my $self = shift;
  my $args = $self->{args};
  my $has = $self->{has};
  my ($tar, $gzip, $zip) = @$has{qw(tar gzip zip)};
  my $force_zip = $self->{opts}->{zip};
  my $binary = $self->{opts}->{binary};
  my $name;
  if ($binary and $binary =~ /$ext/) {
    ($name = $binary) =~ s!.*/(.*)$ext!$1!;
  }
  else {
    $name = $args->{DISTNAME} || $args->{NAME};
    $name  =~ s!::!-!g;
  }

  $name .= "-$self->{version}" if ($self->{opts}->{vs} and $self->{version});

  my $is_Win32 = (not $self->{OS} or $self->{OS} =~ /Win32/i 
		  or not $self->{ARCHITECTURE} or
		  $self->{ARCHITECTURE} =~ /Win32/i);

  # TODO
  $is_Win32 = 1;

  my $script = $self->{opts}->{script};
  my $script_is_external = $script ? ($script =~ /$protocol/) : '';
  my @files;
  if ($self->{opts}->{add}) {
    @files = @{$self->{opts}->{add}};
  }

  my $arc = $force_zip ? ($name . '.zip') : ($name . '.tar.gz');
#  unless ($self->{opts}->{force}) {
#    return $arc if (-f $arc);
#  }
  unlink $arc if (-e $arc);

 DIST: {
    ($tar eq 'Archive::Tar' and not $force_zip) && do {
      $name .= '.tar.gz';
      my @f;
      my $arc = Archive::Tar->new();
      if ($is_Win32) {
        finddepth(sub { return unless -f $_;
                       push @f, $File::Find::name
                          unless $File::Find::name =~ m!blib/man\d!;
		       print $File::Find::name,"\n"}, 'blib');
      }
      else {
	finddepth(sub {push @f, $File::Find::name; 
		       print $File::Find::name,"\n"}, 'blib');
      }
      if ($script and not $script_is_external) {
	push @f, $script;
	print "$script\n";
      }
      if (@files) {
	push @f, @files;
	print join "\n", @files;
      }
      $arc->add_files(@f);
      $arc->write($name, 1);
      last DIST;
    };
    ($tar and $gzip and not $force_zip) && do {
      $name .= '.tar';
      my @args = ($tar, 'cvf', $name);

      if ($is_Win32) {
	my @f;
        finddepth(sub { 
                       push @f, $File::Find::name
                          if $File::Find::name =~ m!blib/man\d!;},
                             'blib');
	for (@f) {
	  push @args, "--exclude", $_;
	}
      }

      DEBUG "pwd=", `pwd`, " ls=", `ls`;

      push @args, 'blib';

      if ($script and not $script_is_external) {
	push @args, $script;
      }
      if (@files) {
	push @args, @files;
      }
      print "@args\n";
      system(@args) == 0 or die "@args failed: $?";
      @args = ($gzip, $name);
      print "@args\n";
      system(@args) == 0 or die "@args failed: $?";
      $name .= '.gz';
      last DIST;
    };
    ($zip eq 'Archive::Zip') && do {
      $name .= '.zip';
      my $arc = Archive::Zip->new();
      if ($is_Win32) {
        die "zip of blib failed" unless $arc->addTree('blib', 'blib',
                     sub{$_ !~ m!blib/man\d/! && print "$_\n";}) == AZ_OK();
      }
      else {
        die "zip of blib failed" unless $arc->addTree('blib', 'blib', 
                              sub{print "$_\n";}) == AZ_OK();
      }
      if ($script and not $script_is_external) {
        die "zip of $script failed"
           unless $arc->addTree($script, $script) == AZ_OK();
	print "$script\n";
      }
      if (@files) {
	for (@files) {
          die "zip of $_ failed" unless $arc->addTree($_, $_) == AZ_OK();
	  print "$_\n";
	}
      }
      die "Writing to $name failed" 
	unless $arc->writeToFileNamed($name) == AZ_OK();
      last DIST;
    };
    ($zip) && do {
      $name .= '.zip';
      my @args = ($zip, '-r', $name, 'blib');
      if ($script and not $script_is_external) {
	push @args, $script;
	print "$script\n";
      }
      if (@files) {
	push @args, @files;
	print join "\n", @files;
      }
      if ($is_Win32) {
	my @f;
        finddepth(sub {
                       push @f, $File::Find::name
                          unless $File::Find::name =~ m!blib/man\d!;},
                             'blib');
	for (@f) {
	  push @args, "-x", $_;
	}
      }
      
      print "@args\n";
      system(@args) == 0 or die "@args failed: $?";
      last DIST;
    };
    die "Cannot make archive for $name";
  }
  return $name;
}

sub make_ppd {
  my ($self, $dist) = @_;
  my $has = $self->{has};
  my ($make, $perl) = @$has{qw(make perl)};
  my $binary = $self->{opts}->{binary};
  if ($binary) {
    unless ($binary =~ /$ext/) {
      $binary =~ s!/$!!;
      $binary .= '/' . $dist;
    }
  }

  (my $name = $dist) =~ s!$ext!!;
  my $ppd = $name . '.ppd';
  my $args = $self->{args};
  my $os = $self->{OS};
  my $arch = $self->{ARCHITECTURE};
  my $d;
  
  $d->{SOFTPKG}->{NAME} = $d->{TITLE} = $name;
  $d->{SOFTPKG}->{VERSION} = cpan2ppd_version($self->{version});  
  $d->{OS}->{NAME} = $os if $os;
  $d->{ARCHITECTURE}->{NAME} = $arch if $arch;
  $d->{ABSTRACT} = $args->{ABSTRACT};
  $d->{AUTHOR} = $args->{AUTHOR};
  $d->{CODEBASE}->{HREF} = $binary || $dist;
  ($self->{archive} = $d->{CODEBASE}->{HREF}) =~ s!.*/(.*)!$1!;

  if ( my $script = $self->{opts}->{script}) {
    if (my $exec = $self->{opts}->{exec}) {
      $d->{INSTALL}->{EXEC} = $exec;
    }
    if ($script =~ m!$protocol!) {
      $d->{INSTALL}->{HREF} = $script;
      (my $name = $script) =~ s!.*/(.*)!$1!;
      $d->{INSTALL}->{SCRIPT} = $name;
    }
    else {
      $d->{INSTALL}->{SCRIPT} = $script;
    }
  }
  
  foreach my $dp (keys %{$args->{PREREQ_PM}}) {
    next if is_core($dp);
    my $results = mod_search($dp, no_case => 0, partial => 0);
    next unless (defined $results->{$dp});
    my $dist = file_to_dist($results->{$dp}->{cpan_file});
    next if (not $dist or $dist =~ m!^perl$! or $dist =~ m!^Test!);
    $self->{prereq_pm}->{$dist} = 
      $d->{PREREQ_PM}->{$dist} = cpan2ppd_version($args->{PREREQ_PM}->{$dp});
  }

  foreach (qw(OS ARCHITECTURE)) {
    delete $d->{$_}->{NAME} unless $self->{$_};
  }
  
  print_ppd($d, $ppd);
  $self->{ppd} = $ppd;
}

sub print_ppd {
  my ($d, $fn) = @_;
  open (my $fh, ">$fn") or die "Couldn't write to $fn: $!";
  my $title = html_escape($d->{TITLE});
  my $abstract = html_escape($d->{ABSTRACT});
  my $author = html_escape($d->{AUTHOR});
  print $fh <<"END";
<SOFTPKG NAME=\"$d->{SOFTPKG}->{NAME}\" VERSION=\"$d->{SOFTPKG}->{VERSION}\">
\t<TITLE>$title</TITLE>
\t<ABSTRACT>$abstract</ABSTRACT>
\t<AUTHOR>$author</AUTHOR>
\t<IMPLEMENTATION>
END
  
  foreach (keys %{$d->{PREREQ_PM}}) {
    print $fh 
      qq{\t\t<DEPENDENCY NAME="$_" VERSION="$d->{PREREQ_PM}->{$_}" />\n};
  }
  foreach (qw(OS ARCHITECTURE)) {
    next unless $d->{$_}->{NAME};
    print $fh qq{\t\t<$_ NAME="$d->{$_}->{NAME}" />\n};
  }
  
  if (my $script = $d->{INSTALL}->{SCRIPT}) {
    my $install = 'INSTALL';
    if (my $exec = $d->{INSTALL}->{EXEC}) {
      $install .= qq{ EXEC="$exec"};
    }
    if (my $href = $d->{INSTALL}->{HREF}) {
      $install .= qq{ HREF="$href"};
    }
    print $fh qq{\t\t<$install>$script</INSTALL>\n};
  }
  
  print $fh qq{\t\t<CODEBASE HREF="$d->{CODEBASE}->{HREF}" />\n};
  
  print $fh qq{\t</IMPLEMENTATION>\n</SOFTPKG>\n};
  $fh->close;

}

sub make_cpan {
  my $self = shift;
  my ($ppd, $archive) = ($self->{ppd}, $self->{archive});
  my %seen;
  my $man = 'MANIFEST';
  my $copy = $man . '.orig';
  unless (-e $copy) {
    rename($man, $copy) or die "Cannot rename $man: $!";
  }
  open(my $orig, $copy) or die "Cannot read $copy: $!";
  open(my $new, ">$man") or die "Cannot open $man for writing: $!";
  while (<$orig>) {
    $seen{ppd}++ if $_ =~ /$ppd/;
    $seen{archive}++ if $_ =~ /$archive/;
    print $new $_;
  }
  close $orig;
  print $new "\n$ppd\n" unless $seen{ppd};
  print $new "$archive\n" unless $seen{archive};
  close $new;
  my @args = ($self->{has}->{make}, 'dist');
  print "@args\n";
  system(@args) == 0 or die qq{system @args failed: $?};
  return;
}

sub upload_ppm {
  my $self = shift;
  my ($ppd, $archive) = ($self->{ppd}, $self->{archive});
  my $upload = $self->{opts}->{upload};
  my $ppd_loc = $upload->{ppd};
  my $ar_loc = $self->{opts}->{arch_sub} ?
    $self->{ARCHITECTURE} : $upload->{ar} || $ppd_loc;
  if (not File::Spec->file_name_is_absolute($ar_loc)) {
    ($ar_loc = File::Spec->catdir($ppd_loc, $ar_loc)) =~ s!\\!/!g;
  }

  if (my $host = $upload->{host}) {
    my ($user, $passwd) = ($upload->{user}, $upload->{passwd});
    die "Must specify a username and password to log into $host"
      unless ($user and $passwd);
    my $ftp = Net::FTP->new($host) or die "Cannot connect to $host";
    $ftp->login($user, $passwd) or die "Login for user $user failed";
    $ftp->cwd($ppd_loc) or die "cwd to $ppd_loc failed";
    $ftp->ascii;
    $ftp->put($ppd) or die "Cannot upload $ppd";
    $ftp->cwd($ar_loc) or die "cwd to $ar_loc failed";
    $ftp->binary;
    $ftp->put($archive) or die "Cannot upload $archive";
    $ftp->quit;
  }
  else {
    copy($ppd, "$ppd_loc/$ppd") 
      or die "Cannot copy $ppd to $ppd_loc: $!";
    unless (-d $ar_loc) {
        mkdir $ar_loc or die "Cannot mkdir $ar_loc: $!";
    }
    copy($archive, "$ar_loc/$archive") 
      or die "Cannot copy $archive to $ar_loc: $!";
  }
}

1;

__END__

=head1 NAME

PPM::Make - Make a ppm package from a CPAN distribution

=head1 SYNOPSIS

  my $ppm = PPM::Make->new( [options] );
  $ppm->make_ppm();

=head1 DESCRIPTION

See the supplied C<make_ppm> script for a command-line interface.

This module automates somewhat some of the steps needed to make
a I<ppm> (Perl Package Manager) package from a CPAN distribution.
It attempts to fill in the I<ABSTRACT> and I<AUTHOR> attributes of 
F<Makefile.PL>, if these are not supplied, and also uses C<pod2html> 
to generate a set of html documentation. It also adjusts I<CODEBASE> 
of I<package.ppd> to reflect the generated I<package.tar.gz> 
or I<package.zip> archive. Such packages are suitable both for 
local installation via

  C:\.cpan\build\package_src> ppm install

and for distribution via a repository.

Options can be given as some combination of key/value
pairs passed to the I<new()> constructor (described below) 
and those specified in a configuration file.
This file can either be that given by the value of
the I<PPM_CFG> environment variable or, if not set,
a file called F<.ppmcfg> at the top-level
directory (on Win32) or under I<HOME> (on Unix).
If the I<no_cfg> argument is passed into C<new()>,
this file will be ignored.

The configuration file is of an INI type. If a section
I<default> is specified as

  [ default ]
  option1 = value1
  option2 = value2

these values will be used as the default. Architecture-specific
values may be specified within their own section:

  [ MSWin32-x86-multi-thread-5.8 ]
  option1 = new_value1
  option3 = value3

In this case, an architecture specified as
I<MSWin32-x86-multi-thread-5.8> within PPM::Make will
have I<option1 = new_value1>, I<option2 = value2>,
and I<option3 = value3>, while any other architecture
will have I<option1 = value1> and I<option2 = value2>.
Options specified within the configuration file
can be overridden by passing the option into
the I<new()> method of PPM::Make.

Valid options that may be specified within the 
configuration file are those of PPM::Make, described below. 
For the I<program> and I<upload> options (which take hash references),
the keys (make, zip, unzip, tar, gzip),
or (ppd, ar, host, user, passwd), respectively,
should be specified. For binary options, a value
of I<yes|on> in the configuration file will be interpreted
as true, while I<no|off> will be interpreted as false.

=head2 OPTIONS

The available options accepted by the I<new> constructor are

=over

=item no_cfg => 1

If specified, do not attempt to read a F<.ppmcfg> configuration
file.

=item dist => value

If I<dist> is not specified, it will be assumed that one
is working inside an already unpacked source directory,
and the ppm distribution will be built from there. A value 
for I<dist> will be interpreted either as a CPAN-like source
distribution to fetch and build, or as a module name,
in which case I<CPAN.pm> will be used to infer the
corresponding distribution to grab.

=item no_case => boolean

If I<no_case> is specified, a case-insensitive search
of a module name will be performed.

=item binary => value

The value of I<binary> is used in the I<BINARY_LOCATION>
attribute passed to C<perl Makefile.PL>, and arises in
setting the I<HREF> attribute of the I<CODEBASE> field
in the ppd file.

=item arch_sub => boolean

Setting this option will insert the value of C<$Config{archname}>
(or the value of the I<arch> option, if given)
as a relative subdirectory in the I<HREF> attribute of the 
I<CODEBASE> field in the ppd file.

=item script => value

The value of I<script> is used in the I<PPM_INSTALL_SCRIPT>
attribute passed to C<perl Makefile.PL>, and arises in
setting the value of the I<INSTALL> field in the ppd file.
If this begins with I<http://> or I<ftp://>, so that the
script is assumed external, this will be
used as the I<HREF> attribute for I<INSTALL>.

=item exec => value

The value of I<exec> is used in the I<PPM_INSTALL_EXEC>
attribute passed to C<perl Makefile.PL>, and arises in
setting the I<EXEC> attribute of the I<INSTALL> field
in the ppd file. 

=item  add => \@files

The specified array reference contains a list of files
outside of the F<blib> directory to be added to the archive. 

=item zip => boolean

By default, a I<.tar.gz> distribution will be built, if possible. 
Giving I<zip> a true value forces a I<.zip> distribution to be made.

=item force => boolean

If a F<blib/> directory is detected, it will be assumed that
the distribution has already been made. Setting I<force> to
be a true value forces remaking the distribution.

=item ignore => boolean

If when building and testing a distribution, failure of any
supplied tests will be treated as a fatal error. Setting
I<ignore> to a true value causes failed tests to just
issue a warning.

=item os => value

If this option specified, the value, if present, will be used instead 
of the default for the I<NAME> attribute of the I<OS> field of the ppd 
file. If a value of an empty string is given, the I<OS> field will not 
be included in the  ppd file.

=item arch => value

If this option is specified, the value, if present, will be used instead 
of the default for the I<NAME> attribute of the I<ARCHITECTURE> field of 
the ppd file. If a value of an empty string is given, the 
I<ARCHITECTURE> field will not be included in the ppd file.

=item remove => boolean

If specified, the directory used to build the ppm distribution
(with the I<dist> option) will be removed after a successful install.

=item cpan => boolean

If specified, a distribution will be made using C<make dist>
which will include the I<ppd> and I<archive> file.

=item program => { p1 => '/path/to/q1', p2 => '/path/to/q2', ...}

This option specifies that C</path/to/q1> should be used
for program C<p1>, etc., rather than the ones PPM::Make finds. The
programs specified can be one of C<tar>, C<gzip>, C<zip>, C<unzip>,
or C<make>.

=item no_as => boolean

Beginning with Perl-5.8, Activestate adds the Perl version number to
the NAME of the ARCHITECTURE tag in the ppd file. This option
will make a ppd file I<without> this practice.

=item vs => boolean

This option, if enabled, will add a version string 
(based on the VERSION reported in the ppd file) to the 
ppd and archive filenames.

=item upload => {key1 => val1, key2 => val2, ...}

If given, this option will copy the ppd and archive files
to the specified locations. The available options are

=over

=item ppd => $path_to_ppd_files

This is the location where the ppd file should be placed,
and must be given as an absolute pathname.

=item ar => $path_to_archive_files

This is the location where the archive file should be placed.
This may either be an absolute pathname or a relative one,
in which case it is interpreted to be relative to that
specified by I<ppd>. If this is not given, and yet I<ppd>
is specified, then this defaults, first of all, to the
value of I<arch_sub>, if given, or else to the value
of I<ppd>.

=item host => $hostname

If specified, an ftp transfer to the specified host is
done, with I<ppd> and I<ar> as described above.

=item user => $username

This specifies the user name to login as when transferring
via ftp.

=item passwd => $passwd

This is the associated password to use for I<user>

=back

=back

=head2 STEPS

The steps to make the PPM distribution are as follows. 

=over

=item determine available programs

For building and making the distribution, certain
programs will be needed. For unpacking and making 
I<.tar.gz> files, either I<Archive::Tar> and I<Compress::Zlib>
must be installed, or a C<tar> and C<gzip> program must
be available. For unpacking and making I<.zip> archives,
either I<Archive::Zip> must be present, or a C<zip> and
C<unzip> program must be available. Finally, a C<make>
program must be present.

=item fetch and unpack the distribution

If I<dist> is specified, the corresponding file is
fetched (by I<LWP::Simple>, if a I<URL> is specified).
If I<dist> appears to be a module name, the associated
distribution is determined by I<CPAN.pm>. The distribution
is then unpacked.

=item build the distribution

If needed, or if specied by the I<force> option, the
distribution is built by the usual

  C:\.cpan\build\package_src> perl Makefile.PL
  C:\.cpan\build\package_src> nmake
  C:\.cpan\build\package_src> nmake test

procedure. A failure in any of the tests will be considered
fatal unless the I<ignore> option is used. Additional
arguments to these commands present in either I<CPAN::Config>
or present in the I<binary> option to specify I<BINARY_LOCATION>
in F<Makefile.PL> will be added.

=item parse Makefile.PL

Some information contained in the I<WriteMakefile> attributes
of F<Makefile.PL> is then extracted.

=item parse Makefile

If certain information in F<Makefile.PL> can't be extracted,
F<Makefile> is tried.

=item determining the ABSTRACT

If an I<ABSTRACT> or I<ABSTRACT_FROM> attribute in F<Makefile.PL> 
is not given, an attempt is made to extract an abstract from the 
pod documentation of likely files.

=item determining the AUTHOR

If an I<AUTHOR> attribute in F<Makefile.PL> is not given,
an attempt is made to get the author information using I<CPAN.pm>.

=item HTML documentation

C<pod2html> is used to generate a set of html documentation.
This is placed under the F<blib/html/site/lib/> subdirectory, 
which C<ppm install> will install into the user's html tree.

=item Make the PPM distribution

A distribution file based on the contents of the F<blib/> directory
is then made. If possible, this will be a I<.tar.gz> file,
unless suitable software isn't available or if the I<zip>
option is used, in which case a I<.zip> archive is made, if possible.

=item adjust the PPD file

The F<package_name.ppd> file generated by C<nmake ppd> will
be edited appropriately. This includes filling in the 
I<ABSTRACT> and I<AUTHOR> fields, if needed and possible,
and also filling in the I<CODEBASE> field with the 
name of the generated archive file. This will incorporate
a possible I<binary> option used to specify
the I<HREF> attribute of the I<CODEBASE> field. 
Two routines are used in doing this - C<parse_ppd>, for
parsing the ppd file, and C<print_ppd>, for generating
the modified file.

=item upload the ppm files

If the I<upload> option is specified, the ppd and archive
files will be copied to the given locations.

=back

=head1 REQUIREMENTS

As well as the needed software for unpacking and
making I<.tar.gz> and I<.zip> archives, and a C<make>
program, it is assumed in this that I<CPAN.pm> is 
available and already configured, either site-wide or
through a user's F<$HOME/.cpan/CPAN/MyConfig.pm>.

Although the examples given above had a Win32 flavour,
like I<PPM>, no assumptions on the operating system are 
made in the module. 

=head1 COPYRIGHT

This program is copyright, 2003, by Randy Kobes <randy@theoryx5.uwinnipeg.ca>.
It is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<make_ppm> for a command-line interface for making
ppm packages, L<ppm_install> for a command line interface
for installing CPAN packages via C<ppm>, L<tk-ppm> for
a Tk graphical interface to C<ppm> and the install utility
of PPM::Make, L<PPM::Make::Install>, and L<PPM>.

=cut

