#!/bin/perl

# attempts to get data from all active mesonet stations (which
# includes APRSWXNET and RAWS)

require "/usr/local/lib/bclib.pl";

my($url) = "http://mesowest.utah.edu/data/mesowest.out.gz";
my($out,$err,$res) = cache_command2("curl $url | gunzip", "age=150");

# store unzipped results
write_file($out, "/var/tmp/mesowest.out");

# get rid of header lines
$out=~s/^.*?\n(\s*STN)/$1/s;
$out=~s/^\s*/ /sg;
map(push(@res, [split(/\s+/,$_)]), split(/\n/,$out));
($hlref) = arraywheaders2hashlist(\@res);

# convert from mesowest headers to my own
@convert = (
 "STN:id",
 "SLAT:latitude",
 "SLON:longitude",
 "SELV:elevation:m:ft:0",
 "TMPF:temperature",
 "SKNT:windspeed:kt:mph:1",
 "DRCT:winddir",
 "GUST:gust:kt:mph:1",
 "ALTI:pressure",
 "DWPF:dewpoint",
 "WTHR:events"
);

# TODO: parse WTHR (base 80)
# TODO: put station names in stations.db and then retrieve here

for $i (@{$hlref}) {

  # the resulting hash
  my(%hash) = ();

  # TODO: improve this
  $hash{type} = "MNET$i->{MNET}";

  # time (it's really YYYYMMDD)
  $i->{"YYMMDD/HHMM"}=~/^(\d{4})(\d{2})(\d{2})\/(\d{2})(\d{2})$/ || warn ("BAD TIME: $i->{'YYMMDD/HHMM'}");
  $hash->{time} = "$1-$2-$3 $4:$5:00";
  # TODO: does meso data include cloudcover or only as part of weather?
  $hash->{observation} = join(", ",$i->{raw_array});

  for $j (@convert) {
    my($f1,$f2,$u1,$u2,$r) = split(/:/,$j);
    # start by copying file field to hash field
    $hash{$f2} = $i->{$f1};
    # unit conversion
    if ($u1 && $u2) {$hash{$f2} = convert($hash{$f2},$u1,$u2);}
    # rounding
    if (length($r)) {$hash{$f2} = round2($hash{$f2},$r);}
    # empties
    if ($hash{$f2} == -9999) {$hash{$f2} = "NULL";}
  }

  debug(var_dump("hash",{%hash}));
}











