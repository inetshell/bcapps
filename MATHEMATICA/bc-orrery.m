(*

I can maybe answer this too:

START ANSWER TO http://astronomy.stackexchange.com/questions/13965/

NOTE: I am using a "geocentric" frame of reference, where both the
moons and the sun orbit the planet, and creating a

We note from @Hohmannfan's answer that (answering your questions out
of order for simplicity):

  - Moon B will eclipse the sun every $\frac{10385}{304}$ (~ 34.16)
  days. In this time period, the sun completes $\frac{31}{304}$th of
  an orbit and moon B completes $1\frac{31}{304}$ orbits, lapping the
  sun once.

  - Moon A will eclipse the sun every $\frac{26130}{257}$ (~ 101.67)
  days. The sun will complete $\frac{78}{257}$ of an orbit, and Moon A
  will lap it by completing $1\frac{78}{257}$ orbits.

  - Moon B will overlap Moon A once every $\frac{2418}{47}$ (~ 51.44)
  days, in which Moon A will complete $\frac{31}{47}$ of an orbit and
  Moon B will lap it by completing $1\frac{31}{47}$ orbits.

However, as @Hohmannfan notes, there's no guarantee that the moons
will be *full* when they overlap.

There's also no guarantee that the two moons will *ever* both eclipse
the sun at the exact same time, although they will get arbitrarily
close to doing so:

Suppose the sun's position is $r$ when the two moons first overlap
each other, where $r$ is measured in orbits. For example $r=\frac{1}{2}$

TODO: sim arg






If we make the oversimplifying assumption that moon B is eclipsing
moon A and moon A is eclipsing the sun at time 0, we note from
@Hohmannfan's answer that (answering your questions out of order for
simplicity):









TODO: caveats, unlikely, near conjuncts, not perfect multiples,
mention other prob, fiction, but.... inter general

END ANSWER TO http://astronomy.stackexchange.com/questions/13965/ 


This is an interesting question. I've previously computed planetary
conjunctions *as viewed from Earth*:
https://astronomy.stackexchange.com/questions/11141 but not as viewed
from the Sun.

It turns out this is much easier to compute, since the planets follow
nearly circular orbits around the Sun.

TODO: stellarium

TODO: note significantly more accurate calculations with CSPICE

TODO: note that I've ignored dwarf planets except for Pluto

TODO: ecliptic latitude (and show "bad" conjunctions?)

TODO: snapshots from orrery

TODO: 3+ planets (including specific n years mention in question)

TODO: inner planets

TODO: does Bode's "law" help?

TODO: note EMBary vs E

TODO: does R^3/T^2 help any? (I don't think so, but...)

TODO: mention this program

*)

(*

Helper function: given the t=0 "current" orbital positions of two
planets (as a number between 0 and 1 [this unit is known as a 'turn'])
and their periods, return:

  - time of first alignment

  - interval between alignments

TODO: clean this up to be symmetric and allow for d1-d2 > .5 (which
gives a "late" first alignment)

*)

(* TODO: is my abs value correct? I think so, but comment if, order of ops *)

orbhelp[{p1_,d1_},{p2_,d2_}]={((d1-d2)*p1*p2)/(p1-p2),Abs[p1*p2/(p1-p2)]};

(*

Given (something that limits iterations), a tolerance (in orbits
[turns]) and the periods and t=0 current positions of an arbitrary
number of planets, find when the tolerance is met. Call looks like

conjuncts[1000, 0.01, { {p1,d1}, {p2,d2}, ... }]

TODO: if this gets ugly memory-wise, can intersect on the fly?

TODO: would starting with the largest (two) periods here be useful
(and then trimming the results?)

TODO: allow for searches with intervals if starting with 10 degrees
for example and narrowing down

*)

conjuncts[n_, d_, lol_] := Module[{int, tab, newint},

 int = Interval[{-Infinity, Infinity}];

 tab= Flatten[Table[orbhelp[lol[[i]],lol[[j]]], 
  {i,1,Length[lol]}, {j,i+1, Length[lol]}],1];

 (* TODO: same number of iterations for each planet is wasteful *)

 For[i=1, i<=Length[tab], i++,
  newint = Apply[Interval,
  Flatten[Table[{tab[[i,1]] + {m-d,m+d}*tab[[i,2]]}, {m,-n,n}],1]];
  int = IntervalIntersection[int, newint];
 ];

 Return[int];

]

q13965 = {{335,0}, {78, 0}, {31, 0}};

ints = conjuncts[10000, 0.5/360, q13965]

a1 = (31*78)/(78-31)

a2 = (31*335)/(335-31)

a3 = (78*335)/(335-78)

lcm = LCM[a1,a2,a3]

(* 810030 days = 2418 years in "their" time *)






(* given an interval that is a list of intervals, find their midpoints *)

midpoints[ints_] := Map[Mean,Apply[List,ints]]


(* true gas giants based on p_elem_t1.txt *)

(* epoch is 2000 *)

giants = {
 {360/(3034.74612775/100), 34.39644051/360},
 {360/(1222.49362201/100), 49.95424423/360},
 {360/(428.48202785/100), 313.23810451/360},
 {360/(218.45945325 /100), -55.12002969}
};

giantsol = conjuncts[5000, 10/360, giants];

giant2 = conjuncts[5000, 5/360, giants];

giant3 = conjuncts[5000, 2/360, giants];

(* http://ssd.jpl.nasa.gov/txt/p_elem_t2.txt *)

(* below is raw cut and paste, I clean it up later *)

plans = {

{Mercury, 0.38709843, 0.20563661, 7.00559432, 252.25166724,
77.45771895, 48.33961819, 0.00000000, 0.00002123, -0.00590158,
149472.67486623, 0.15940013, -0.12214182},

{Venus, 0.72332102, 0.00676399, 3.39777545, 181.97970850,
131.76755713, 76.67261496, -0.00000026, -0.00005107, 0.00043494,
58517.81560260, 0.05679648, -0.27274174},

{EMBary, 1.00000018, 0.01673163, -0.00054346, 100.46691572,
102.93005885, -5.11260389, -0.00000003, -0.00003661, -0.01337178,
35999.37306329, 0.31795260, -0.24123856},

{Mars, 1.52371243, 0.09336511, 1.85181869, -4.56813164, -23.91744784,
49.71320984, 0.00000097, 0.00009149, -0.00724757, 19140.29934243,
0.45223625, -0.26852431},

{Jupiter, 5.20248019, 0.04853590, 1.29861416, 34.33479152,
14.27495244, 100.29282654, -0.00002864, 0.00018026, -0.00322699,
3034.90371757, 0.18199196, 0.13024619},

{Saturn, 9.54149883, 0.05550825, 2.49424102, 50.07571329, 92.86136063,
113.63998702, -0.00003065, -0.00032044, 0.00451969, 1222.11494724,
0.54179478, -0.25015002},

{Uranus, 19.18797948, 0.04685740, 0.77298127, 314.20276625,
172.43404441, 73.96250215, -0.00020455, -0.00001550, -0.00180155,
428.49512595, 0.09266985, 0.05739699},

{Neptune, 30.06952752, 0.00895439, 1.77005520, 304.22289287,
46.68158724, 131.78635853, 0.00006447, 0.00000818, 0.00022400,
218.46515314, 0.01009938, -0.00606302},

{Pluto, 39.48686035, 0.24885238, 17.14104260, 238.96535011,
224.09702598, 110.30167986, 0.00449751, 0.00006016, 0.00000501,
145.18042903, -0.00968827, -0.00809981} }

(* this lets us do exact analysis *)

plans = Rationalize[plans,0]

(* the format above is:

name, a, e, I, L, long.peri., long.node., AU, AU/Cy, rad, rad/Cy, deg,
deg/Cy, deg, deg/Cy, deg, deg/Cy, deg, deg/Cy

*)

(* fields of interest:

1 = name
2 = distance (AU)
5 = longitude at epoch (2000-01-01 12:00:00?) (degrees)
11 = increase in longitude per century (degrees)

For consistency, NOT using AstronomicalData below

*)

Table[{
data[i[[1]]][period] = 36525/i[[11]],
data[i[[1]]][sangle] = i[[5]],
data[i[[1]]][distance] = i[[2]]
}, {i,plans}]

pos[i_][t_] = data[i][distance]*
              {Cos[data[i][sangle]*Degree + 2*Pi*t/data[i][period]],
	      Sin[data[i][sangle]*Degree + 2*Pi*t/data[i][period]]};

(* angle, in degrees, corrected for 0-360 *)

angle[i_][t_] = Mod[data[i][sangle] + t*360/data[i][period],360]

Plot[angle[Jupiter][t],{t,0,100}]

(* distance between two angles in degrees, assuming both are 0 < x <
360 [over 180 = less than 180] *)

angdist[a1_,a2_] = If[Abs[a1-a2]<180, Abs[a1-a2], 360-Abs[a1-a2]]

Plot[angdist[angle[Jupiter][t], angle[Saturn][t]], {t,0,100}]

(* maximum angular distance *)

maxangdist[list_] := Max[Flatten[Table[angdist[list[[i]],list[[j]]],
 {i,1,Length[list]}, {j,i+1,Length[list]}]]]

Plot[maxangdist[{
 angle[Jupiter][t], angle[Saturn][t], angle[Uranus][t]}], 
{t,0,1000}, PlotRange -> {0,30}]

Plot[maxangdist[{angle[Jupiter][t], angle[Saturn][t],
angle[Uranus][t], angle[Neptune][t]}], {t,0,10000}, PlotRange -> {0,30}]

Minimize[{maxangdist[
 {angle[Jupiter][t], angle[Saturn][t], angle[Uranus][t], angle[Neptune][t]}],
 t>0 && t<100}, t]

FindMinimum[{maxangdist[
 {angle[Jupiter][t], angle[Saturn][t], angle[Uranus][t], angle[Neptune][t]}],
 t>0 && t<1000}, t]

Plot[maxangdist[
 {angle[Jupiter][t], angle[Saturn][t], angle[Uranus][t], angle[Neptune][t]}],
 {t,0,1000}]

(* TODO: consider changing these *)

data[Saturn][color] = RGBColor[{0.9,0.9,0}]
data[Jupiter][color] = RGBColor[{0,1,0}]

angle[i_][t_] = data[i][sangle] + t*360/data[i][period]

t0 = FindInstance[angle[Jupiter][t] == angle[Saturn][t], t][[1,1,2]]

tend = Solve[angle[Jupiter][t]==360+angle[Saturn][t],t][[1,1,2]]

pp[t_] := ParametricPlot[{pos[Jupiter][u], pos[Saturn][u]}, {u,t0,t0+t},
 PlotStyle -> {data[Jupiter][color], data[Saturn][color]}]

g0[t_] = Graphics[{
 Line[{{0,0}, pos[Saturn][t0]}],
 data[Saturn][color], 
 Line[{{0,0}, pos[Saturn][t0+t]}],
 data[Jupiter][color], 
 Line[{{0,0}, pos[Jupiter][t0+t]}],
 RGBColor[{0,0,0}],
 Dashed, Line[{{0,0}, pos[Saturn][tend]}],
 PointSize[0.05],
 data[Jupiter][color], Point[pos[Jupiter][t0+t]],
 data[Saturn][color], Point[pos[Saturn][t0+t]]
}];

text[t_] := Graphics[{Text[Style["Years: "<>ToString[t], Large], 
 Scaled[{.84,.03}]]}];

g1[t_] := Show[{g0[t],pp[t],text[t]}, Axes -> True, Ticks -> False,
 PlotRange -> {{-data[Saturn][distance]-.5, data[Saturn][distance]+.5},
  {-data[Saturn][distance]-.5, data[Saturn][distance]+.5}}]

showit2 := Module[{file}, file = StringJoin["/tmp/math", 
       ToString[RunThrough["date +%Y%m%d%H%M%S", ""]], ".jpg"]; 
     Export[file, %, ImageSize -> {600, 400}]; 
     Run[StringJoin["display ", file, "&"]]; ]
g1[5]
showit2

(* t1 = Table[g1[t],{t,-0.50,tend-t0,0.15}]; *)

t1 = Table[g1[t],{t,-0.01,data[Saturn][period],0.15}];

Export["/tmp/orbits.gif",t1, ImageSize -> {600,400}]

ParametricPlot[{pos[Jupiter][t], pos[Saturn][t]}, {t,0,data[Jupiter][period]}]

ParametricPlot[{pos[Jupiter][t], pos[Saturn][t]}, {t,0,6}]
