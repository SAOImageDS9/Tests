// Write points and their NESTED pixels from fitsy/hpxnest.h, for
// Tests/hips/nesttest.py to check against healpy.
//
//   c++ -O2 -I fitsy Tests/hips/nesttest.C -o nesttest
//   ./nesttest > points.txt
//
// Lines: "a nside lon lat pix" (ang2pix) and "c nside pix lon lat"
// (pix2ang, the pixel centre). Points: random over the sphere, every
// face/region boundary (lat +-41.8103 = asin(2/3), lon multiples of 45),
// the poles, lon 0/360/-x, and all nside 2^0 .. 2^29.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "hpxnest.h"

int main()
{
  srand48(12345);
  double zlim = asin(2./3)*180/M_PI;
  for (int kk=0; kk<=29; kk++) {
    long long nside = 1LL << kk;
    // random over the sphere (uniform in z)
    for (int ii=0; ii<4000; ii++) {
      double lon = drand48()*360;
      double lat = asin(2*drand48() - 1)*180/M_PI;
      printf("a %lld %.17g %.17g %lld\n", nside, lon, lat,
	     hpxAng2Nest(nside, lon, lat));
    }
    // edges: region boundary, poles, meridians, wrap
    double lats[] = {zlim, -zlim, zlim+1e-9, zlim-1e-9, -zlim+1e-9,
		     -zlim-1e-9, 90, -90, 89.9999999, -89.9999999, 0,
		     1e-12, -1e-12, 60, -60};
    double lons[] = {0, 45, 90, 135, 180, 225, 270, 315, 359.9999999999,
		     -10, 370, 1e-12, 89.999999999, 90.000000001};
    for (double bb : lats)
      for (double ll : lons)
	printf("a %lld %.17g %.17g %lld\n", nside, ll, bb,
	       hpxAng2Nest(nside, ll, bb));
    // pixel centres
    long long npix = 12*nside*nside;
    for (int ii=0; ii<2000; ii++) {
      long long pix = (long long)(drand48()*npix);
      if (ii < 12)
	pix = ii*nside*nside;           // each face's first pixel
      else if (ii < 24)
	pix = (ii-11)*nside*nside - 1;  // and last
      double lon, lat;
      hpxNest2Ang(nside, pix, &lon, &lat);
      printf("c %lld %lld %.17g %.17g\n", nside, pix, lon, lat);
    }
  }
  return 0;
}
