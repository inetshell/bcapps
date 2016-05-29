(* attempts to answer: https://www.quora.com/unanswered/If-you-drew-a-single-straight-line-bisecting-America-so-that-both-land-and-population-were-nearly-equally-divided-which-way-would-the-line-point 

https://www.census.gov/geo/maps-data/data/gazetteer2010.html

[[ussplit.gif]]

With the several caveats below, the line above splits the continental
USA (48 contiguous states and the federal enclave District of
Columbia) into both equal areas and equal populations:

  - The formula for this line is:

$\text{latitude}=-0.093365 \text{longitude}+29.8953$

meaning it's ONLY A LINE in the equiangular map above. It would not be
a line in a Mercator or orthographic projection of the USA.

Although there's no such thing as a straight line on a spherical
surface, the best approximation is a great circle path (or
"geodesic"). The line above is NOT a geodesic.

  - The map above is not to scale: the horizontal scale is 58.75
  seconds of arc per pixel and the vertical scale is 1.5 minutes
  (90.00 seconds) of arc per pixel. This ratio would be accurate at
  49.25 degrees north latitude, which is only the northern edge of the
  map.

  - Based on the US Census 2010 data, there were 153,334,478 living
  below (south and west) of the line and 153,340,528 living above
  (north and east) of this line for a split of 49.999% to 50.001%

  - The area split isn't quite as good: 4,036,057,550,093 square
  meters below the line, and 4,045,809,542,357 square meters, for a
  split of 49.94% to 50.06%

  - To make this calculation I downloaded the census tract population
  and position data from
  https://www.census.gov/geo/maps-data/data/gazetteer2010.html under
  "Census Tracts" (direct link to 2.4MB file:
  http://www2.census.gov/geo/docs/maps-data/data/gazetteer/Gaz_tracts_national.zip)

  - The 74,002 census tract points appear are the small pink-purple
  dots on the map.

  - As an approximation, I assumed the entire population and area of a
  census tract was at a single point, which is, of course,
  incorrect. A more accurate model may yield better results.

  - I then created an SQLite3 database: it's tracts.db in
  https://github.com/barrycarter/bcapps/tree/master/QUORA.

  - I then wrote a Perl program (bc-us-split.pl in the same directory)
  to find various lines that divide the US into equal populations or
  areas, and then found the line that best satisfies both conditions.

  - The metropolitan areas on the map are from
  https://www.statcrunch.com/app/index.php?dataid=1232319 with some
  minor modifications.

  - Using census tract data (instead of city data, or county data as
  I'd originally planned) has an interesting effect: the city of
  Denver is split nearly in two by this line, and Provo and Virginia
  Beach are somewhat split as well.

  - The map was created using Mathematica, see bc-us-split.m in the
  directory noted earlier.

  - As noted on
  https://www.census.gov/geo/maps-data/data/gazetteer2010.html, the
  area of tract (which includes both land and water) has the note
  "Created for statistical purposes only", which may mean it's not
  super-accurate. To improve my result, you may want to use a better
  source.

  - This is not necessarily the only line that splits the US this
  way. There were several other almost-as-close candidates that I
  found, and perhaps much better candidates that I didn't
  find. Additionally, improving the accuracy of area or population
  counting could change this line dramatically, as one of the former
  almost-as-close candidates could become the closest candidate.

  - At some point, I'd like to extend this answer with lines that
  split equally among population or area, but not both, since I ended
  up incidentally computing these lines in my Perl script.

  - I used Census 2010 data since it was the easiest data I could
  find. More recent data is doubtless available.

  - I would appreciate anyone checking my results and/or extending
  what I've done.

  - If you want to extend what I've done here and get more accurate
  areas, you may want to consider the approach I used for:
  http://gis.stackexchange.com/a/191054/1462

*)

<</home/barrycarter/BCGIT/QUORA/metros.txt
Read["!bzcat -v -k /home/barrycarter/BCGIT/QUORA/blockgroups.m.bz2"]
usa = Import["/home/barrycarter/BCGIT/STACK/us_states.kml", "Data"];
state[n_] := usa[[1,2,2,n]]
states = Table[i, {i,Flatten[{1,Range[3,10],Range[12,50]}]}];

(* state outlines *)
ostates = Table[state[i],{i,states}];

(* text for cities *)
ctext = Table[Text[i[[2]], {i[[4]], i[[3]]}, {-1.1,0.5}], {i, metros}];

(* points for cities *)
cpts = Table[Point[{i[[4]],i[[3]]}], {i, metros}];

(* bg points *)
bgpts = Table[Point[i], {i,blockgroups}];

(* the line *)
(* g2 = Plot[-0.093365*x + 29.8953056335449, {x,-125,-67}] *)

(* the intercepts for equal population, as tangent of degree *)

eqpops = {
{10, 53.9440783329819},
{20, 69.431301579708},
{30, 87.8172382866115},
{40, 110.373007014355},
{50, 142.163059074888},
{130, -67.3365063493077},
{140, -36.9708072760325},
{150, -14.1713345029829},
{160, 4.69300791508756},
{170, 22.0356264027452}
};

eqareas = {
{10, 56.3685505198672},
{20, 74.7680296639373},
{30, 95.8633784244303},
{40, 121.624135583797},
{130, -79.4154063414104},
{140, -44.448135467482},
{150, -18.6737734264183}
{160, 2.73207908515797},
{170, 21.6520364129615}
};

poplines = Table[Tan[i[[1]]*Degree]*x + i[[2]], {i, eqpops}]

g5 = Plot[poplines, {x,-125,-67}];

g0 = Graphics[{
 RGBColor[1,0,0],
 PointSize[.0001],
 Opacity[1],
(* bgpts, *)
 PointSize[.001],
 RGBColor[1,0.5,0.5],
 cpts,
 RGBColor[0,0,0],
 ctext,
 EdgeForm[Thin],
 Opacity[0.1],
 ostates
}];

(* note 58 degrees wide, 48 degrees high *)

g1 = Show[{g0,g2,g5}, AspectRatio -> 48/2/44.43,
 PlotRange -> {{-125,-67}, {24.5,49.5}}]

Export["/tmp/test.gif", g1, ImageSize -> {1024,768}]

Export["/tmp/test.gif", g1, ImageSize -> {44.43*40*2,48*40}]
Run["display -geometry 800x600 /tmp/test.gif&"]


Export["/tmp/test.gif", g1, ImageSize -> {1024*4,768*4}]


showit



Show[{g1,g2,g3}, AspectRatio -> 1]
showit

g = Table[{
 EdgeForm[Thin],
 Opacity[0.1],
 state[i]
}, {i,states}];

(* is 1/2 degree per frame a noticeably jerky rotation at high res? *)

Plot[Tan[0.5*Degree]*x,{x,-1,1}, PlotRange -> { {-1,1}, {-1,1}}]

t1217 = Table[
 Plot[Tan[d*Degree]*x,{x,-1,1}, PlotRange -> { {-1,1}, {-1,1}}],
{d,0,360,0.5}];

Export["/tmp/test.gif", t1217, ImageSize -> {1024,768}]

(* trying to find proper range for intercept *)

Plot[50*x, {x,-180,180}, AspectRatio -> 1]
showit


Solve[m*-180 + b == -90, b]

eqpop2 = Sort[eqpop];
test1734 = Table[{i[[2]],i[[3]]}, {i,eqpop}];
test1736 = Table[{i[[1]],i[[3]]/i[[2]]}, {i,eqpop}];

ListPlot[(Transpose[eqpop2][[3]]-38.6)/Transpose[eqpop2][[2]]]
