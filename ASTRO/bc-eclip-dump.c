// dumps the ecliptic coordinates for planet as viewed from earth in format useful to bc-ecliptic-map.pl

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "SpiceUsr.h"
#include "SpiceZfc.h"
#include "SpiceZpr.h"
// this the wrong way to do things
#include "/home/barrycarter/BCGIT/ASTRO/bclib.h"

// this lets me change function definition and times in all place

// these are only approx!
// DE431 starts -13199.6509168566, ends 17191.1606672279 is my scheme
// #define SYEAR -13199
// #define EYEAR 17191
#define SYEAR 2010
#define EYEAR 2016

int main (int argc, char **argv) {

  SpiceInt planet = atoi(argv[1]);

  SpiceDouble i,lt,ra,dec,range;
  SpiceDouble v[3];
  furnsh_c("/home/barrycarter/BCGIT/ASTRO/standard.tm");

  for (i=(SYEAR-2000.)*31556952; i<=(EYEAR-2000.)*31556952; i+=86400) {

    // planet ecliptic coords as viewed from earth, converted to spherical
    spkezp_c(planet,i,"ECLIPJ2000","NONE",399,v,&lt);
    recrad_c(v,&range,&ra,&dec);

    printf("%d %f %f %f %f %f\n", planet, et2jd(i), ra, dec,
	   earthangle(i,0,planet), earthangle(i,planet,10));

  }
  return(0);
}