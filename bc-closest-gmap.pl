#!/bin/perl

# Find which portions of globe are closest to given point(s) (Voronoi)

# Note: starting with Paris <h>(the one in France, not Texas)</h> and
# Albuquerque <h>(two major world hubs)</h>; had to add more later;
# min is 5 says qhull [but I was using wrong prog, meant qconvex]

require "bclib.pl";

# Perl doesn't define pi?
$pi = 4*atan(1);

# latitude and longitude of points
%points = (
 "Albuquerque" => "35.08 -106.66",
 "Paris" => "48.87 2.33",
 "Barrow" => "71.26826 -156.80627",
 "Wellington" => "-41.2833 174.783333"
# "Rio de Janeiro" => "-22.88  -43.28"
);

# convert to 3D
for $i (sort keys %points) {
  ($lat,$lon) = split(/\s+/, $points{$i});
  $z = sin($lat/180*$pi);
  $x = cos($lat/180*$pi)*cos($lon/180*$pi);
  $y = cos($lat/180*$pi)*sin($lon/180*$pi);

  # we need to number points for qhull
  $qhull[$n] = "$x $y $z";
  $city[$n++] = $i;
}

open(A,">/tmp/qclose.txt");

# 3D points and how many
print A "3\n$n\n";

for $i (0..$#city) {
 print A "$qhull[$i]\n";
}

close(A);

# qhull does the real work
# http://www.qhull.org/html/qh-faq.htm#vsphere
# TODO: this doesn't tell what two cities we're separating
@res = `qconvex n < /tmp/qclose.txt`;
debug(@res);

# TODO: really should be using chdir(tmpdir()) universally
open(B,">/home/barrycarter/BCINFO/sites/TEST/gmarkclose.txt");

# first two lines are dull
for $i (2..$#res) {
  # plane equation
  ($x0,$y0,$z0,$c0) = split(/\s+/, $res[$i]);

  # for many values of x/y, calculate z (and thus lat/long point)
  for ($x=-1; $x<=1; $x+=.1) {
    for ($y=-1; $y<=1; $y+=.1) {
      $z = ($c0-$x0*$x-$y0*$y)/$z0;
      $lon = atan2($y,$x)/$pi*180;
      $lat = asin($z)/$pi*180;
      # TODO: this is NOT the correct way to check for "not a number"
      if ($lat eq "nan" || $lon eq "nan") {next;}
      # google API probably doesn't understand 'e' notation
      if ($lat=~/e/ || $lon=~/e/) {next;}

      # create marker
      print B << "MARK";

new google.maps.Marker({
 position: new google.maps.LatLng($lat,$lon),
 map: map, 
 title:"TEST"
});

MARK
;
    }
  }
}





