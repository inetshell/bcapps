# Barry Carter's Perl library (carter.barry@gmail.com)

# required libs
# NOTE: Some people believe you should only 'use' things that the lib
# itself needs, not things that programs calling the lib may
# need. Personally, I just don't care
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Date::Parse;
use POSIX;
use Text::Unidecode;
use MIME::Base64;
use utf8;
use Statistics::Distributions qw(uprob udistr);
use Math::Round;
require JSON;

# HACK: defining constants here is probably bad
$PI = 4.*atan(1);
$DEGRAD=$PI/180; # degrees to radians
$EARTH_RADIUS = 6371/1.609344; # miles

# HACK: not sure this is right way to do this
our(%globopts);
our(@tmpfiles);

# largest possible path
$ENV{PATH} = "/sw/bin/:/bin/:/usr/bin/:/usr/local/bin/:/usr/X11R6/bin/:/usr/lib/nagios/plugins:$ENV{HOME}/bin:$ENV{HOME}/PERL";

=item list2hash(@list)

Converts @list to a hash where all elements of @list map to 1

=cut

sub list2hash {
  my(@list) = @_;
  my(%hash);
  for $i (@list) {$hash{$i} = 1;}
  return %hash;
}

=item defaults($x)

given a string like "FOO=1&X=BLAH", sets $FOO and $X in globopts hash,
unless they're already set (allows a program to set default options
where user hasn't already set options)

=cut

sub defaults {
  my(%hash) = str2hash($_[0]);

  for $i (sort keys %hash) {
    if (defined($globopts{$i})) {next;}
    $globopts{$i} = $hash{$i};
  }

  # calls parse_options again to do any special processing
  # TODO: could this cause an infinite loop?
  parse_options();
}

=item str2hash($str)

Given $str like x=1&y=2&z=3, return the hash mapping x->1, y->2, z->3

=cut

sub str2hash {
  # TODO: can I combine these into one line (earlier attempt to do so failed)
  my(%hash) = split(/[\&\=]/,$_[0]);
  return %hash;
}

=item parse_options()

Parses things like --foo and --bar=1 on the command line and removes
them from @ARGV

=cut

sub parse_options {

  # find arguments that set options and remove them from ARGV
  my(@x)=grep(/^\-\-[a-z]/i,@ARGV);
  @ARGV=grep(!/^\-\-[a-z]/i,@ARGV);


  for $i (@x){
    # remove the --
    $i=~s/^\-\-//;

    if ($i=~/^(.*?)=(.*)$/) {
      # for cases like --bar=1
      $globopts{$1}=$2;
    } else {
      # if its just --foo, assume --foo=1
      $globopts{$i}=1;
    }
  }
}

=item unfold($ref)

Given a reference to any object, descends into it and returns XML-y
string representation

=cut

sub unfold {
  my(@aa)=@_;
  my(@ac);
  my(%ad);
  
  # if someone sends a list call unfold with a ref to that list
  if ($#aa>0) {return(unfold(\@aa));}

  # it's not a list so only the first element counts
  my($aa)=$aa[0];
  my($ab)=ref($aa);
  if ($ab eq "") {return($aa);}

  # recursively print object (or at least return string to print)
  if ($ab eq "SCALAR") {
    push(@ac,"<scalar $aa>",unfold($$aa),"</scalar $aa>");
  } elsif ($ab eq "ARRAY" || UNIVERSAL::isa($aa,"ARRAY")) {
    push(@ac,"<array $aa>",map(unfold($_),@$aa),"</array $aa>");
  } elsif ($ab eq "HASH" || UNIVERSAL::isa($aa,"HASH")) {
    %ad=%$aa;
    push(@ac,"<hash $aa>");
    for $i (keys %ad) {
      if (!ref($i) && !ref($ad{$i})) {
	push(@ac,"$i: $ad{$i}");
      } else {
	push(@ac,"<key>",unfold($i),"</key>");
	push(@ac,"<val>",unfold($ad{$i}),"</val>");
      }
    }
    push(@ac,"</hash $aa>");
  } elsif ($ab eq "REF") {
    push(@ac,"<ref $aa>",unfold($$aa),"</ref $aa>");
  } else {
    debug("NO CONDITION CAUGHT","AA IS",@aa,"AB: $ab");
  }

  return(join("\n",@ac)."\n");
}

=item debug(@list)

Print list of messages to the standard error, separated by
newlines if --debug given at command line

=cut

sub debug {
  if($globopts{debug}) {
    print STDERR join("\n",@_),"\n";
  }
}

=item dodie($perlcmd)

Try to run Perl code $perlcmd, die if there's an error

=cut

sub dodie {eval($_[0])||die("COMMAND FAILS: $_[0], $!");}


=item cache_command($command, $options)

Runs $command and returns stdout, stderr, and exit status. If command
was run recently, return cached output. $options:

 salt=xyz: store results in file determined by hashing command w/ salt
 retry=n: retry command n times if it fails (returns non-0)
 sleep=n: sleep n seconds between retries
 age=n: if output file is less than n seconds old + no error, return cached
 nocache=1: don't really cache the results (also global --nocache)
 fake=1: don't run the command at all, just say what would be done
 retfile=1: return the filename where output is cached, not output itself
 cachefile=x: use x as cachefile; don't use hash to determine cachefile name
 ignoreerror: assume return code from command is 0, even if it's not

=cut

sub cache_command {
  my($command,$options) = @_;
  my($count,$res);

  # TODO: combine/functionalize next few lines
  my(%defaults) = parse_form("retry=1");
  my(%opts) = parse_form($options);
  for $i (keys %defaults) {
    $opts{$i} = $defaults{$i} unless (exists $opts{$i});
  }

  # TODO: generalize setting specific options from global ones
  if ($globopts{nocache}) {$opts{nocache}=1; $opts{age}=-1;}

  if ($opts{fake}) {
    print "NOT RUNNING: $command\n";
    return;
  }

  # temp file
  my($file) = "/tmp/cache-".sha1_hex("$opts{salt}$command$opts{salt}");
  if ($opts{cachefile}) {$file = $opts{cachefile};}
  my($fileage) = (-M $file)*86400;
  debug("FILE: $file, AGE: $fileage");

  # if file is young enough, return existing values
  if (-f $file && (!read_file("$file.res") || $opts{ignoreerror})
      && ($fileage < $opts{age})) {
    if ($opts{retfile}) {return $file;}
    return (read_file($file), read_file("$file.err"), $res);
  }

  debug("FILE AGE: $opts{age} VS $fileage");

  # run command
  do {
    # if we've run this command already, sleep between runs
    if ($count) {
      debug("Command failed, trying again ($count)");
      sleep($opts{sleep});
    }

    debug("Running command: $command");
    $res = system("($command) 1> $file 2> $file.err");
    $count++;
  } until ($res==0 || $count>$opts{retry} || $opts{ignoreerror});

  # do this so we know if it failed
  write_file($res,"$file.res");

  # if not caching, delete these files when done
  if ($opts{nocache}) {
    debug("PUSHING TO tmpfiles: $file, $file.err, $file.res");
    push(@tmpfiles,$file,"$file.err","$file.res");
  }

  if ($opts{retfile}) {return $file;}
  return (read_file($file), read_file("$file.err"), $res, $file);
}

=item write_file($string, $file)

Write $string to $file

=cut

sub write_file {
  local(*A);
  open(A,">$_[1]")||warnlocal("Can't open $_[1], $!");
  print A $_[0];
  close(A);
}

=item read_file($filename)

Return the entire contents of $filename as a string

=cut

sub read_file {
  # many ways to do this; below not necessarily optimal
  local(*A,$/);
  undef $/;
  open(A,$_[0])||warnlocal("Can't open $_[0], $!");
  my($suck)=<A>;
  close(A);
  return($suck);
}

=item trim($str)

Trims leading/trailing spaces from a string

=cut

sub trim {
    $_[0]=~s/^\s+//isg;
    $_[0]=~s/\s+$//isg;
    return($_[0]);
}

=item min(@list)

Returns minimal item of @list

(not part of POSIX standard?!)

=cut

sub min {
  my($min) = $_[0];
  for $i (@_) {if ($i<$min) {$min=$i;}}
  return $min;
}

=item max(@list)

Returns maximal item of @list

(not part of POSIX standard?!)

=cut

sub max {
  my($max) = $_[0];
  for $i (@_) {if ($i>$max) {$max=$i;}}
  return $max;
}

=item my_tmpfile($prefix="file")

Return a filename in /tmp that is not being used and starts with
$prefix. Appending $$ to filename avoids race condition when forking.

I dislike the regular tmpfile, so use this instead

=cut

sub my_tmpfile {
  my($prefix) = @_;
  unless ($prefix) {$prefix="file";}
  my($x)=rand();
  while (-f "/tmp/$prefix$x$$") {$x=rand();}
  push(@tmpfiles, "/tmp/$prefix$x$$");
  return("/tmp/$prefix$x$$");
}

=item sqlite3($query,$db)

Run the query $query on the sqlite3 db (file) $db and return results
in raw format.

<h>Modules, who needs 'em!</h>

=cut

sub sqlite3 {
  my($query,$db) = @_;
  my($qfile) = (my_tmpfile("sqlite"));

  # ugly use of global here
  $SQL_ERROR = "";

  # if $query doesnt have ;, add it, unless it starts with .
  unless ($query=~/^\./ || $query=~/\;$/) {$query="$query;";}
  debug("WROTE: $query to $qfile");
  write_file($query,$qfile);
  my($cmd) = "sqlite3 -batch -line $db < $qfile";
  my($out,$err,$res,$fname) = cache_command($cmd,"nocache=1");
  debug("OUT: $out, ERR: $err, RES: $res, FNAME: $fname");

  if ($res) {
    warnlocal("SQLITE3 returns $res: $out/$err, CMD: $cmd");
    $SQL_ERROR = "$res: $out/$err FROM $cmd";
    return "";
  }
  return $out;
}

=item sqlite3hashlist($query,$db)

Returns a list of hashes representing the results of $query on $db

=cut

sub sqlite3hashlist {
  my($query,$db) = @_;
  my($raw) = sqlite3($query,$db);
  my($hashref) = {};
  my(@res) = ();
  my($count) = 0;
  my($cur);

  # KLUDGE: for empty case
  unless ($raw) {return @res;}

  for $i (split("\n",$raw)) {
    # standard column=val line
    if ($i=~/^\s*(.*?)\s+\=\s+(.*)$/) {
      $cur=$1;
      $$hashref{$cur}=$2;
      next;
    }

    # blank line between results
    if ($i=~/^\s*$/) {
      push(@res,$hashref);
      $hashref = {};
      next;
    }

    # continuation line
    $$hashref{$cur}.=$i;
  }

  push(@res,$hashref); # the last one
  return @res;
}

=item sqlite3val($query,$db)

For queries that return a single row/column, return that row/column

=cut

sub sqlite3val {
  my($query,$db) = @_;
  my(@res) = sqlite3hashlist($query,$db);
  # TODO: if I were really clever, I could combine the two lines below!
  my(@temp) = values %{$res[0]};
  return $temp[0];
}

=item sqlite3cols($tabname,$db)

Return a hash mapping columns in tabname to their "type"

=cut

sub sqlite3cols {
  my($tabname,$db) = @_;
  my($raw) = sqlite3(".schema $tabname",$db);
  my(%ret);

  unless ($raw=~/create table $tabname \((.*?)\)/is) {
    warnlocal("Schema return value not understood");
    return;
  }

  my($schema) = $1;

  for $i (split(/\,/,$schema)) {
    $i=~/^\s*(.*?)\s+(.*)$/||warnlocal("BAD SCHEMA LINE: $i");
    $ret{$1}=$2;
  }
  
  return %ret;
}

=item webdie($str)

The die() command doesn't work well for CGI; this is die for CGI scripts

=cut

sub webdie {
  my($str) = @_;
  print "<p>ERROR: $str<p>\n";
  # exiting w/ 0 to avoid confusing lighttpd
  exit(0);
}

=item cmdfile()

Return contents and name of first command-line argument to program
(not argument to function). Complains if program is called sans
argument

=cut

sub cmdfile {
    my($f)=$ARGV[0]||die("Usage: $0 [options] <filename>");
    if ($#ARGV>=1) {
      die("Usage: $0 [options] <filename>; multiple files ignored, use xargs -n 1");
    }
    unless (-f $f) {die("NO SUCH FILE: $f");}
    unless (-r $f) {die("NO READ PERM: $f");}
    return(read_file($f),$f);
}

=item tmpdir($prefix="file")

Create and return a directory in /tmp that is not being used and
starts with $prefix.

NOTE: Appending $$ to filename below avoids race condition when forking.

=cut

sub tmpdir {
  # if we already have a tmpdir (perhaps passed as --tmpdir=), use it
  if ($globopts{tmpdir}) {return $globopts{tmpdir};}

  my($prefix) = @_;
  unless ($prefix) {$prefix="dir";}
  my(@lets)=("a".."z","A".."z","0".."9");
  my(@file);
  my($file);

  do {
    for $i (1..16) {
      my($rand) = rand($#lets);
      push(@file, $lets[$rand]);
    }
    $file = "/tmp/$prefix-".join("",@file)."-$$";
    } until (!(-f $file));

  mkdir($file);
  push(@tmpdirs, $file);
  # only create one tmpdir per program: lets subroutines call tmpdir w/o
  # fear of cluttering up /tmp
  $globopts{tmpdir} = $file;
  return($file);
}

=item warnlocal(@msgs)

Localized version of warn() in case I want to overwrite it. Individual
scripts can further overwrite this. This version just does warn()
unless --nowarn is set

=cut

sub warnlocal {
  unless ($globopts{nowarn}) {warn(join("\n",@_));}
}

=item gcddist($x,$y,$u,$v)

Great circle distance between latitude/longitude x,y and
latitude/longitude u,v in miles Source: http://williams.best.vwh.net/avform.htm

=cut

sub gcdist {
    my(@x)=@_;
    my($x,$y,$u,$v)=map {$_*=$PI/180} @x;
    my($c1) = cos($x)*cos($y)*cos($u)*cos($v);
    my($c2) = cos($x)*sin($y)*cos($u)*sin($v);
    my($c3) = sin($x)*sin($u);
    return ($EARTH_RADIUS*acos($c1+$c2+$c3));
}

=item hsv2rgb($hue,$sat,$val, $options)

Given hue, saturation, and value of a color, convert to RGB using *my
own formula* which is not necessarily the "correct" formula. $options:

kml: output in KML format (aabbggrr) not HTML (rrggbb)
opacity: for KML, the opacity in hex format

format=decimal: return as integers

=cut

sub hsv2rgb {
  my($hue,$sat,$val,$options) = @_;
  my($r,$g,$b);
  my(%opts) = parse_form($options);
  $hue=$hue-floor($hue);
  $hv=floor($hue*6);

  # can't get given/when to work, so...
  if ($hv==0) {$r=1; $g=6*$hue; $b=0;} elsif
    ($hv==1) {$r=2-6*$hue; $g=1; $b=0;} elsif
    ($hv==2) {$r=0; $g=1; $b=6*$hue-2;} elsif
    ($hv==3) {$r=0; $g=4-6*$hue; $b=1;} elsif
    ($hv==4) {$r=6*$hue-4; $g=0; $b=1;} elsif
    ($hv==5) {$r=1; $g=0; $b=6-6*$hue;} else
      {$r=0; $g=0; $b=0;}
  debug("HSV: $hue -> $r $g $b");
  $r=min($r+1-$sat,1)*$val;
  $g=min($g+1-$sat,1)*$val;
  $b=min($b+1-$sat,1)*$val;

  if ($opts{kml}) {
    return sprintf("#$opts{opacity}%0.2x%0.2x%0.2x",$b*255,$g*255,$r*255);
  } elsif ($opts{format} eq "decimal") {
    return sprintf("%0.2d,%0.2d,%0.2d",$r*255,$g*255,$b*255);
  } else {
    return sprintf("#%0.2x%0.2x%0.2x",$r*255,$g*255,$b*255);
  }
}

=item mod($x,$y)

Returns $x modulo $y, neither has to be an integer

=cut

sub mod {
  my($x,$y) = @_;
  return $x-$y*floor($x/$y);
}

=item urlencode($str)

URL encodes $str

=cut

sub urlencode {
  my($str) = @_;
  $str=~s/([^a-zA-Z0-9])/"%".unpack("H2",$1)/iseg;
  $str=~s/ /\+/isg;
  return $str;
}

=item sph2xyz($theta,$phi,$r, $options)

Converts spherical ($theta,$phi,$r) to Cartesian ($x,$y,$z)

 degrees=1: assume theta and phi are in degrees, not radians

=cut

sub sph2xyz {
  my($th,$ph,$r,$options)=@_;
  my(%opts) = parse_form($options);
  if ($opts{degrees}) {$th=$th*$DEGRAD; $ph=$ph*$DEGRAD;}
  return($r*cos($ph)*cos($th),$r*cos($ph)*sin($th),$r*sin($ph));
}


=item voronoi(\@points, $options)

Returns the Voronoi tesselation (in polygons) for a list of 2-D
points. The list must be passed by reference, and is actually a 1-D
list where each 2 element pair is treated like a 2-element list.

This subroutine is a thin wrapper around qhull, and just
subroutine-ifys what I've already done in bc-temperature-voronoi.pl

Options:
 infinityok: include polygons with points at infinity (not working)
 infinityclip: include polygons w/ pts at infinity, but remove infinity points
 default: ignore polygons w/ pts at infinity

=cut

sub voronoi {
  # TODO: @pts is really a 2-D array, but we pass it as a 1-D array (bad?)
  my($pts, $options) = @_;
  my(@pts) = @{$pts};
  my(%opts) = parse_form($options);
  my(@ret) = ();
  # TODO: this dir goes away at end of prog, not end of subroutine (bad?)
  chdir(tmpdir());

  # put points into input file
  # TODO: below seems tedious; shorter way to do this?
  local(*A);
  open(A,">points");
  print A "2\n";
  print A ($#pts+1)/2 ."\n";
  for ($i=0; $i<=$#pts; $i+=2) {
    print A "$pts[$i] $pts[$i+1]\n";
  }
  close(A);

  debug("POINTS",read_file("points"));

  system("qvoronoi s o < points > output");

  # break output into lines/polygons
  my(@regions) = split(/\n/, read_file("output"));

  # number of dimensions
  my($di) = shift(@regions);
  # number of points, regions, and something else (#infinite regions?)
  my($pts, $regions, $x) = split(/\s+/,shift(@regions));

  debug("REGIONS:",@regions);

  # going thru regions (which start at $pts+1; first $pts entries are points)
  for $i ($pts+1..$#regions) {
    debug("POLYGON $i",$regions[$i]);

    # TODO: ignoring unbounded regions now, but should fix
    if ($regions[$i]=~/ 0( |$)/ && !$opts{infinityok}) {next;}

    # the numbers of the points making up this polygon
    my(@points)=split(/\s+/,$regions[$i]);
    debug("POINTS",@points);
    # the first one is dimension (uninteresting)
    shift(@points);

    # map the rest to actual point coords
    map($_=trim($regions[$_]),@points);

    # if we somehow have no points, ignore
    unless (@points) {next;}

    debug("POINTS",@points);

    # add polygon to result list (must use ref here)
    # must use $i to compensate for skipped polygons
    $ret[$i-$pts] = \@points;
  }

  debug("RET:",@ret);

  return @ret;
}

=item to_mercator($lat,$lon)

Converts $lat, $lon (degrees) to google maps' yx Mercator projects
(top left = 0,0; bottom right = 1,1); can return abs($y)>1 for far
south/north latitudes. Options:

 order=(xy|yx): return coordinates in xy or yx format (latter is default)

NOTE: return order is yx, not xy

=cut

sub to_mercator {
  my($lat,$lon, $options) = @_;
  my(%opts) = parse_form($options);

  my($y) = 1/2-1*(log(tan($PI/4+$lat/180*$PI/2))/2/$PI);
  if ($opts{order} eq "xy") {
    return ($lon+180)/360, $y;
    # else below is actually optional, but omitting it is confusing
  } else {
    return $y,($lon+180)/360;
  }
}

=item convert_time($secs, $format, $options)

Convert time interval in seconds to years/months/days/etc based on
$format (documented below, but very strftime-like).

=cut

sub convert_time {
  my($sec, $format, $options) = @_;
  my(%secs);

  # requestable components (straight from strftime):
  # %C = centuries, %Y = years, %m = months, %U = weeks
  # %d = days, %H = hours, %M = minutes, %S = seconds

  # number of seconds for the above (Gregorian calendar sans leap seconds)
  # Year = 365.2425 days (so seconds for months/years/centuries looks weird)
  %secs = ("S" => 1, "M" => 60, "H" => 3600, "d" => 86400, "U" => 604800,
	   "m" => 2629746, "Y" => 31556952, "C" => 3155695200);

  # figure out what components are requested in $format; we have to
  # return them biggest-to-smallest, not in the order specified
  my(@components)=($format=~/%([CYmUdHMS])/g);

  # and sort them
  @components = sort {$secs{$b} <=> $secs{$a}} @components;

  # and convert
  for $i (@components) {
    # compute how many whole $i units in $sec and subtract them off
    my($units) = floor($sec/$secs{$i});
    debug("SECBEFORE: $sec");
    $sec -= $secs{$i}*$units;
    debug("UNITS: $units","SECAFTER: $sec");
    # and substitute in format
    $format=~s/%$i/$units/g;
  }

  return $format;

}

=item forex_quotes()

Obtain current FOREX quotes; return as hash of bid/ask values

<h>Unsolved problem: How to spell FoReX</h>

=cut

sub forex_quotes {
  my(%hash); # for return values
  my($out,$err,$res) =  cache_command("curl -A 'Barrys Brow<h>no</h>ser' www.forexpros.com/common/quotes_platform/quotes_platform_data.php | tidy -xml","retry=5&sleep=1&age=30");

  # loop through each parity
  while ($out=~s%([A-Z]{3})/([A-Z]{3})(.*?</div>)\s*</div>\s*</div>%%s) {
    my($parity, $data) = ("$1$2", $3);
    # prices for parity
    my(@prices) = ($data=~m%<div class="quotes_platform_16" dir="ltr">(.*?)</div>\s*<div class="quotes_platform_17">(.*?)</div>%isg);
    $hash{$parity}{bid} = $prices[0] + $prices[1]/10000;
    $hash{$parity}{ask} = $prices[2] + $prices[3]/10000;
  }

  return %hash;
}

=item nadex_quotes($parity, $options)

<h>The double use of the word 'options' here (financial instrument vs
parameters to a subroutine) amuses me</h>

Obtains NADEX option quotes for $parity, given as "USD-CAD" (for example).

Return values are $hash{"USDCAD"}{strike}{Unix_exp_time}{bid|ask|updated}

Options:
  nointra=1: Do not obtain intradaily options
  cache=t: Cache results for t seconds (default: 15m)

This function REQUIRES a file called "nadex-cookie.txt":

To obtain this cookie (requires Firebug):
  - Log into nadex.com (bugmenot.com has a demo username/pw)
  - Turn on Firebug and go to the Net/All panel
  - On main screen, click on any specific option
  - In Firebug, look at your first GET request
  - Copy/paste the cookie into a nadex-cookie.txt file
  - The cookie will look something like sample-data/nadex-cookie.txt
  - Do not use Firefox's cookies.sqlite: it doesn't work

TODO: automate cookie obtaining procedure

TODO: try to identify bad cookie earlier w/o multiple web accesses first

=cut

sub nadex_quotes {
 my($parity, $options) = @_;
 my(%hash); # to hold return values
 $parity = uc($parity);
 unless ($parity=~/\-/) {
   warnlocal("PARITY MUST CONTAIN: -");
   return;
 }

 my($cookie) = read_file("/home/barrycarter/nadex-cookie.txt");
 chomp($cookie);
 my($dataq)=0;
 # putting defaults first lets $options override
 my(%opts) = parse_form("cache=600&$options");

 # HACK: I'm sometimes logged in w/ my live account and sometimes w/
 # my demo account, so I never know what nadex-cookie.txt has (I
 # updated it manually frequently from whicheever account I'm logged
 # into)
 $cookie=~/(demo|www)\.nadex\.com/isg;
 my($prehost) = $1;
 unless ($prehost) {warnlocal("nadex_quotes fails; bad cookie"); return;}
 debug("PREHOST: $prehost, COOKIE: $cookie");

 # TODO: using /tmp here is ugly, but I don't see a way around it.
 # I can't use cache-command, since I'm using curl's wildcarding feature

 # commands to obtain daily, weekly, and intra-daily options
 my($daily_cmd) = "curl -v -L -k -o /tmp/daily#1-#2.txt -v -L -H 'Cookie: $cookie' 'https://$prehost.nadex.com/dealing/pd/cfd/displaySingleMarket.htm?epic=N{B}.D.$parity.OPT-1-[1-21].IP'";
# my($daily_cmd) = "curl -v -L -k -o /tmp/daily#1-#2.txt -v -L -H 'Cookie: $cookie' 'https://$prehost.nadex.com/dealing/pd/cfd/displaySingleMarket.htm?epic=N{B}.D.$parity.OPT-2-[1-21].IP'";
 my($weekly_cmd) = "curl -v -L -k -o /tmp/weekly#1-#2.txt -v -L -H 'Cookie: $cookie' 'https://$prehost.nadex.com/dealing/pd/cfd/displaySingleMarket.htm?epic=N{B}.W.$parity.OPT-1-[1-14].IP'";
 my($intra_cmd) = "curl -v -L -k -o intra#1-#2-#3.txt -v -L -H 'Cookie: $cookie' 'https://$prehost.nadex.com/dealing/pd/cfd/displaySingleMarket.htm?epic=N{B}.I.$parity.OPT-[1-8]-[1-3].IP'";

 # and obtain data (since I'm using curl -o, below doesn't actually
 # return anything, so I ignore the return value)

 cache_command($daily_cmd, "age=$opts{cache}");
 cache_command($weekly_cmd, "age=$opts{cache}");
 unless ($opts{nointra}) {cache_command($daily_cmd, "age=$opts{cache}");}

 # parse results
 # TODO: in theory, could get old intra results here
 for $i (glob ("/tmp/daily*.txt /tmp/weekly*.txt /tmp/intra*.txt")) {
   my($all) = read_file($i);

   # option name
   unless ($all=~m%<title>(.*?)</title>%) {
     warnlocal("NO DATA IN: $i");
     next;
   }

   $title = $1;
   $title=~s/\|.*//;
   $title=~s/>\s+/>/g;

   # skip bad
   if ($title=~/^sorry/i) {next;}

   # confirm we got at least SOME data
   $dataq = 1;

   # title pieces + cleanup
   my($par, $strdir, $tim, $dat) = split(/\s/, $title);
   $par=~s/\///isg;
   for $j ($tim,$dat) {$j=~s/[\(\)]//isg;}
   $strdir=~s/>//isg;

   # Unix time
   # TODO: EST5EDT does NOT work below, but should; this will be
   # inaccurate once we leave DST
   $utime = str2time("$dat $tim GMT-4");
   debug("$utime <- $dat $tim");

   # last updated time
   my($updated) = 0;
   while ($all=~s%<span class="updated updateTime left">(.*?)</span>%%g) {
     $updated=$1;
   }

   # convert updated to time + calculate minute
   # str2time() defaults to today
   debug("UPTIME: $updated");
   my($uptime) = str2time("$updated EDT5EST");

   # TODO: below is ugly, there should be better way
   # however, if that's in the future, assume yesterday update
   if ($uptime > time()) {$uptime-=86400;}
   # if it's too far in the past, add one day
   if (time() - $uptime > 86400) {$uptime+=86400;}

   # grab values
   my(@vals)=();
   while ($all=~s%<span class="valueNotFX">(.*?)</span>%%) {
     $val = $1;
     $val=~s/<.*?>//isg;
     push(@vals, $val);
   }

  ($obid, $oask) = @vals;

   # TODO: not sure skipping no bid/ask is a good idea here
   if ($obid eq "-" || $oask eq "-") {next;}

   $hash{$par}{$strdir}{$utime}{bid} = $obid;
   $hash{$par}{$strdir}{$utime}{ask} = $oask;
   $hash{$par}{$strdir}{$utime}{updated} = $uptime;
 }

 unless ($dataq) {
   warnlocal("GOT NO DATA: BAD COOKIE? MARKET CLOSED? NETWORK DOWN?");
   # <h>warnlocal("ELVES ON STRIKE? DEMONS ATTACKING? BAD MOON PHASE?")</h>
   return;
 }

 return %hash;
}

=item nestify($str)

Given a $str (that looks like contents of data/moonxyz.txt for
example), return a nested array of contents).

HACK: this is pretty much a kludge function to read Mathematica
output. There are probably MUCH better ways to do this, but using an
"inside out" recursive approach has a certain uniqueness.

=cut

sub nestify {
  my($all) = @_;
  my($n)=-1;
  my(@res);

  # convert all {stuff} and [stuff] into list refs
  while ($all=~s/[\{\[]([^\{\}\[\]]*)[\}\]]/f1($1)/eisg) {}

  # TODO: this conflicts w/ f1 in outer scope, if any; same for f2
  sub f1 {
    my($str) = @_;
    $str=~s/\n/ /isg;
    $str=~s/\s+/ /isg;
    $res[++$n] = $str;
#    debug("$str -> RES$n");
    return "RES$n";
  }

  # now turn it into a proper list of lists (of lists...)
  return f2($all);

  sub f2 {
    my(@ret);
    my($val) = @_;
    for $i (split(/[\,\s)]+\s*/,$val)) {
      if ($i=~/RES(\d+)/) {
	push(@ret, [f2($res[$1])]);
      } else {
	push(@ret, $i);
      }
    }
    return @ret;
  }
}

=item forex_quote($parity, $time)

Obtains price of $parity (as "USD/CAD") at or near $time (in Unix seconds)

Requires: free API username/password from
http://api.efxnow.com/forum/index.php

TODO: confusing name, since it's close to forex_quotes(); however, may
get rid of forex_quotes() as using efxnox.com's API seems easier
anyway

# TODO: default time to now?

=cut

sub forex_quote {
  my($parity, $time) = @_;
  my($price);
  
  # obtain username/password/brand
  my($username,$password,$brand) = split("\n",read_file("/home/barrycarter/efx-info.txt"));

  # obtain key (needed for any sort of access)
  my($key) = cache_command("curl 'http://api.efxnow.com/DEMOWebServices2.8/Service.asmx/GetRatesServerAuth?UserID=$username&PWD=$password&Brand=$brand'","age=3600&retry=5");

  # strip XML and spaces
  $key=~s/<.*?>//isg;
  $key=~s/\s//isg;

  # Convert Unix time to
  # http://api.efxnow.com/DEMOWebServices2.8/Service.asmx?op=GetHistoricRatesDataSet
  # use a 5 minute boundary on each side (TODO: too much? too little?)
  # NOTE: cheating and using ISO-8601, but EFX accepts that too
  # TODO: in theory, will get data for nearby times too, but not caching it:
  # ie: forex_quote($x, $y) and forex_quote($x, $y+1) requires 2 API accesses
  # EFX uses ET, sigh

  my($tz) = $ENV{TZ};
  $ENV{TZ} = "EST5EDT";
  my($st) = strftime("%F\T%H:%M:%S", localtime($time-300));
  my($en) = strftime("%F\T%H:%M:%S", localtime($time+300));
  $ENV{TZ} = $tz;

  my($url) = "http://api.efxnow.com/DEMOWebServices2.8/Service.asmx/GetHistoricRatesDataSet?Key=$key&Quote=$parity&StartDateTime=$st&EndDateTime=$en";
  my($rates) = cache_command("curl '$url'", "age=86400");

  debug("URL: $url", "RATES: $rates");

  # TODO: probably better way to keep track of mintime (using "large
  # value" is bad)
  my($mintime) = 1e+9;

  # parse
  while ($rates=~s%<HistoricRates[^>]*?>(.*?)</HistoricRates>%%is) {
    my($quote) = $1;
    my(%hash);
    while ($quote=~s%<(.*?)>(.*?)</\1>%%) {$hash{$1}=$2;}

    # how far away is this quote, time-wise?
    my($deltat) = abs(str2time($hash{Time}) - $time);

    # if it's the closest so far, record it
    if ($deltat < $mintime) {
      $mintime = $deltat;
      $price = ($hash{Bid}+$hash{Offer})/2;
    }
  }

  return $price;
}


=item hermione($x, \@xvals, \@yvals)

Computes the Mathematica interpolation (which I have dubbed the
"Hermione interpolation") for @xvals -> @yvals at $x

<h>"oh barry, do be careful!"</h>

=cut

sub hermione {
  my($x,$xvals,$yvals) = @_;
  my(@xvals) = @{$xvals};
  my(@yvals) = @{$yvals};

  # compute size of x intervals, assuming they are all the same
  my($intsize) = ($xvals[-1]-$xvals[0])/$#xvals;

  # what interval is $x in and what's its position in this interval?
  # interval 0 = the 1st interval
  my($xintpos) = ($x-$xvals[0])/$intsize;
  my($xint) = floor($xintpos);
  my($xpos) = $xintpos - $xint;

  my($ret) =  hermm1($xpos)*$yvals[$xint-1] +
              herm0($xpos)*$yvals[$xint] +
              hermp1($xpos)*$yvals[$xint+1] +
       	      hermp2($xpos)*$yvals[$xint+2];

  return $ret;

  # I dub these the Hermione polynomials
  sub hermm1 {my($x)=@_; ($x-2)*($x-1)*$x/-6;}
  sub herm0 {my($x)=@_; ($x-2)*($x-1)*($x+1)/2;}
  sub hermp1 {my($x)=@_; $x*($x+1)*($x-2)/-2;}
  sub hermp2 {my($x)=@_; ($x-1)*$x*($x+1)/6;}
}

=item matrixmult(\@x,\@y)

Multiply matrices (2D arrays) x and y

=cut

sub matrixmult {
    my($a,$b)=@_;
    my(@a)=@$a;
    my(@b)=@$b;
    my($rows,$cols)=($#a,$#{$b[0]});
    my($share)=$#b;
    my(@ans);
    for $i (0..$rows) {
	for $j (0..$cols) {
	    for $k (0..$share) {
		$ans[$i][$j]+= $a[$i][$k]*$b[$k][$j];
	    }
	}
    }
    return(@ans);
}


=item postition($object, $t=now, $options)

Determine the position (right ascension and declination) of $object at
time $t, using Hermite approximation. Requires
data/{$object}fake[xy].txt and only accurate for the span in that
file.

Returns answers in degrees, even for RA

TODO: I really need to start creating sub libraries?

=cut

sub position {
  my($obj, $t) = @_;
  unless ($t) {$t = time();}
  my(@data) = (read_file("data/${obj}fakex.txt"), 
	       read_file("data/${obj}fakey.txt"));
  my(@nest) = (nestify($data[0]), nestify($data[1]));
  my(@xvals0) = @{$nest[0]};
  my(@x2vals0) = @{$nest[1]};
  my(@yvals, @xvals, @yvals2, @xvals2);

  for $i (@xvals0) {
    my(@j) = @{$i};
    $j[0]=~s/\*\^(\d+)/e+$1/isg;
    push(@xvals, $j[0]);
    push(@yvals, $j[1]);
  }

  # TODO: blech! redundant code! (@xvals could be an array of arrays?)
  for $i (@x2vals0) {
    my(@j) = @{$i};
    $j[0]=~s/\*\^(\d+)/e+$1/isg;
    push(@xvals2, $j[0]);
    push(@yvals2, $j[1]);
  }

  # obtain psuedo-xy coordinates
#  debug("XV2:",@xvals2);
  my($xcoord) = hermione($t, \@xvals, \@yvals);
  my($ycoord) = hermione($t, \@xvals2, \@yvals2);

  # computing pos
  my($ra) = atan2($ycoord,$xcoord)/$PI*12;
  if ($ra<0) {$ra+=24;}
  my($dec) = (sqrt($xcoord**2+$ycoord**2)-$PI)/$PI*180;

  return $ra,$dec;
}

=item gmst($t=now)

Compute the Greenwich Mean Siderial Time at Unix time t

=cut

sub gmst {
  my($t)=@_;
  unless ($t) {$t = time();}
  my($aa)=6.59916+.9856002585*($t-$MILLSEC)/86400/15+($t%86400)/3600;
  return(24*($aa/24-int($aa/24)));
}

=item greeks_bin($cur, $str, $exp, $vol)

Return the greeks and fair value of a binary option, given $cur, the
current price of the underlying, $str, the option strike price, $exp,
the time to expiration in years, and $vol, the volatility (per year).

Returned values (in order):
  - fair value
  - delta: per pip
  - theta: per hour (since this is mostly for NADEX)
  - vega: per .01 change

=cut

# greeks + value of binary option
sub greeks_bin {
  debug("GREEKS_BIN",@_,"ENDARG");
  my($cur, $str, $exp, $vol) = @_;

  # nesting subroutines = bad?
  sub bin_value {
    my($cur, $str, $exp, $vol) = @_;

    # easy case
    if ($exp <= 0) {return ($cur>$str?1:0);}

    return uprob(log($str/$cur)/($vol*sqrt($exp)));
  }

  # things to return: fair value, delta, theta, etc
  my($val) = bin_value($cur, $str, $exp, $vol);
  # TODO: this is NOT the correct way to calculate delta, theta, etc
  my($delta) = bin_value($cur+.0001, $str, $exp, $vol) - $val;
  # TODO: this could yield a negative expiration time
  my($theta) = bin_value($cur, $str, $exp-1/365.2425/24, $vol) - $val;
  my($vega) = bin_value($cur, $str, $exp, $vol+.01) - $val;

  return ($val, $delta, $theta, $vega);

}

=item bin_volt($price, $strike, $exp, $under)

Computes the volatility of a binary option, given its current $price,
the $strike price, the years to expiration $exp, and the price of the
underlying instrument $under

NOTE: I realize all my valuations are for "call" style options, but
this is probably OK.

NOTE: will pretty much obsolete nadex-vol.pl (?)

NOTE: see older versions of bc-nadex-vol.pl for formula derivation

=cut

sub bin_volt {
  my($price, $strike, $exp, $under) = @_;
  # can't calculate volatility if price is 50
  if ($price == 50) {return 0;}
  return log($strike/$under)/udistr($price/100)/sqrt($exp);
}



=item post_to_wp($body, $options)

Posts $body as a new WordPress post with the following options:

  - site: site to post to
  - author: post author
  - password: password for posting
  - subject: subject/title of post (if editing, use current subject)
  - timestamp: UNIX timestamp of post
  - category: category of post
  - live: whether to make post live instantly (default=no)

Optional:

  - action: wp.editPage to edit existing page/post
  - postid: id of page/post (if editing existing)
  - wp_slug: slug (autoset for new posts)

=cut

sub post_to_wp {
  my($body, $options) = @_;
  my(%opts) = parse_form($options);
  my(%defaults) = parse_form("live=0&action=metaWeblog.newPost");
  for $i (keys %defaults) {
    $opts{$i} = $defaults{$i} unless (exists $opts{$i});
  }

  # timestamp (in ISO8601 format)
  my($timestamp) = strftime("%Y%m%dT%H:%M:%S", gmtime($opts{timestamp}));

  # if editing, new strings to insert in request
  my($strs);
  if ($opts{postid}) {
    @strs = ("<param><value><string>$opts{postid}</string></value></param>",
	     "<member><name>wp_slug</name><value><string>$opts{wp_slug}</string></value></member>");
  }

my($req) =<< "MARK";

<?xml version="1.0"?>
<methodCall> 
<methodName>$opts{action}</methodName> 
<params>

<param><value><string>x</string></value></param>

$strs[0]

<param><value><string>$opts{author}</string></value></param> 

<param><value><string>$opts{password}</string></value></param>

<param> 
<struct> 

$strs[1]

<member><name>categories</name> 
<value><array><data><value>$opts{category}</value></data></array></value> 
</member> 

<member>
<name>description</name> 
<value><string><![CDATA[$body]]></string></value>
</member> 

<member> 
<name>title</name> 
<value>$opts{subject}</value> 
</member> 

<member> 
<name>dateCreated</name> 
<value>
<dateTime.iso8601>$timestamp</dateTime.iso8601> 
</value> 
</member> 

</struct> 
</param> 

<param><value><boolean>$opts{live}</boolean></value></param> 

</params></methodCall>
MARK
;

  write_file($req,"/tmp/request");
  debug($req);

  if ($globopts{fake}) {return;}

  # curl sometimes sends 'Expect: 100-continue' which WP doesn't like.
  # The -H 'Expect:' below that cancels this
  system("curl -H 'Expect:' -o /tmp/answer --data-binary \@/tmp/request http://$opts{site}/xmlrpc.php");

  debug($req);

  debug(read_file("/tmp/answer"));
}


=item xmlrpc($site, $method, \@params, $options)

Runs the XMLRPC $method on $site, using @params as the parameters
(must be a listref, not a list).

$site is the XMLRPC endpoint (eg, http://wordpress.barrycarter.info/xmlrpc.php)

@params are in the format "value:type" [currently can't pass values
with colons in them... \: does NOT work as escape <h>though it does
make a cute emoticon</h>]

$options currently unused

TODO: only supports simple non-struct requests at the moment

=cut

sub xmlrpc {
  chdir(tmpdir());
  my($site, $method, $params, $options) = @_;
  my(@params) = @$params;
  my($call) = << "MARK";
<?xml version="1.0"?><methodCall>
<methodName>$method</methodName><params>
MARK
;

  for $i (@params) {
    if ($i=~/^(.*?):(.*)$/) {
      $call .= "<param><value><$2>$1</$2></value></param>\n";
    } else {
      $call .= "<param><value>$i</value></param>\n";
    }
  }

  $call .= "</params></methodCall>";
  write_file($call, "input.txt");

  # make the call
  ($out, $err, $res) = cache_command("curl --data-binary \@input.txt http://wordpress.barrycarter.info/xmlrpc.php");

  return $out;

}

=item findroot(\&f, $x1, $x2, $e, $maxsteps=50)

Find where f [a one-argument function] reaches 0 (to an accuracy of
$e) between $x1 and $x2. Stop if $maxsteps reached before specified
accuracy

<h>I wrote this function years ago, so it's not as polished as my
current coding</h>

=cut

sub findroot {
    my($f,$x1,$x2,$e,$maxsteps)=@_;
    if ($maxsteps==0) {$maxsteps=50;}
    my($le,$ri)=($x1,$x2);
    my($steps,$mid,$fmid);

    # value of the function at interval edges
    my($fle,$fri)=(&$f($le),&$f($ri));

    # same sign on both sides of interval?

    # TODO: same sign -> product is positive (ugly workaround to
    # non-imported signum function)

    if ($fle*$fri > 0) {
      debug("FLE: $fle, FRI: $fri");
      warnlocal("INVALID BINARY SEARCH");
      return();
    }

    # infinite loop broken by $maxsteps
    for (;;) {
	$steps++;

	# find value at midpoint
	$mid=($le+$ri)/2;
	$fmid=&$f($mid);

	# close enough? return midpoint
	if (abs($fmid)<$e) {return($mid);}

	# too many steps?
	if ($steps>$maxsteps) {
	  warnlocal("NO ROOT FOUND");
	  return();
	}

	# find which side the midpoint matches and continue w/ FOR loop
	# NOTE: could've used recursion here, though I doubt it'e more efficient
	# NOTE: ugly use to check same signedness here, see note above
	if ($fle*$fmid>0) {
	    $le=$mid;
	    $fle=$fmid;
	} else {
	    $ri=$mid;
	    $fri=$fmid;
	}
    }
}

=item findmin (\&f,$a,$d,$e,$maxsteps=50)

A non-calculus technique (the "interval technique", <h>formally known
as "Caesar's divisa in partes tres" method</h>) to find the minimum of
f [a one-argument function] on the interval [$a, $d], provided that:

  - f is continuous on [$a,$d]
  - f has a UNIQUE local minimum in [$a,$d]
  - f has no local maximum in [$a,$d]
  - <h>Other conditions I've now forgotten</h>

<h>Like findroot, I wrote this ages ago, so my coding style sucks more
than normal</h>

=cut

sub findmin {
    my($f,$a,$d,$e,$maxsteps,$steps,$b,$c)=@_;
    if ($maxsteps==0) {$maxsteps=50;}
    
    for (;;) {
	$steps++;

	# break interval into 3 pieces, and find function value on those pieces
	# intervals are [$a,$b], [$b,$c], and [$c,$d]
	($b,$c)=($a*2/3+$d/3,$a/3+$d*2/3);
	($fa,$fb,$fc,$fd)=(&$f($a),&$f($b),&$f($c),&$f($d));

	# too many steps?
	if ($steps>$maxsteps) {
	  warnlocal("NO MIN FOUND");
	  return();
	}

	if ($fc>=$fb && $fd>=$fc) {
	  # if f($d) > f($c) > f($b), then min can't be in [$c,$d]
	  debug("OMIT SEGMENT 3");
	  $d=$c;
	} elsif ($fb<=$fa && $fc<=$fb) {
	  # if f($a) > f($b) > f($c), min can't be in [$a,$b]
	  debug("OMIT SEGMENT 1");
	  $a=$b;
	} elsif ($fb<=$fa && $fd>=$fc) {
	  # if f($b) < f($a) AND f($c) < $f(d), min must be in [$b,$c]
	  debug("OMIT SEGMENTS 1 and 3");
	  ($a,$d)=($b,$c);
	} else {
	  # impossible, unless intial parameters bad
	  warn("INVALID MIN SEARCH");
	  return();
	}

	if (($d-$a)<$e) {return(($a+$d)/2);}
    }
}

=item stardate($time)

Returns $time in somewhat human (<h>Vulcan, Andorran, Betazoid, etc</h>)
readable format, yyyymmdd.hhmmss

<h>I've coded this many different ways over the years: I think I
finally found the right way to do this!</h>

=cut

sub stardate {strftime("%Y%m%d.%H%M%S", gmtime($_[0]));}

=item datestar($str)

Does the opposite of stardate(): given a date in
yyyymmdd[.][hh][mm][ss] format, return Unix time.

TODO: has to be a much shorter way to do this?

=cut

sub datestar {
  my($str) = @_;
  my(@frac);
  # yyyymmdd must be present
  $str=~s/^(\d{4})(\d{2})(\d{2})//;
  my($y,$m,$d) = ($1,$2,$3);

  # hh, mm, ss may be present (along with dots?)
  while ($str=~s/^\.?(\d{2})//) {push(@frac, $1);}
  # if any of above missing, use 0s
  push(@frac,"00","00","00");
  return str2time("$y-$m-$d $frac[0]:$frac[1]:$frac[2]");
}

=item minus(\@l1, \@l2)

Returns the set-theoretic difference of list l1 and l2, which must be
passed as pointers

=cut

sub minus {
  my($x,$y)=@_;
  my(%z);

  for $i (@$x) {$z{$i}=1;}
  for $i (@$y) {delete $z{$i};}
  return keys %z;
}

# cleanup files created by my_tmpfile (unless --keeptemp set)

sub END {
  local $?;
  if ($globopts{keeptemp}) {return;}

  for $i (@tmpfiles) {
    debug("DELETING: $i");
    unlink($i);
  }

  for $i (@tmpdirs) {
    debug("RM -R: $i");
    system("rm -r $i");
  }
}

# parse_form = alias for str2hash (but some of my code uses it)
sub parse_form {return str2hash(@_);}

# suck = alias for read_file (I was young and foolish...)
sub suck {return read_file(@_);}

# automatically call parse_options (don't expect calling prog to do this)
&parse_options;

1;
