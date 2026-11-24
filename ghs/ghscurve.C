// Standalone checks of the GHS transfer curve in tksao/frame/ghs.h.
// Built and run by ghs.sh:
//   c++ -std=c++11 -O2 -I../tksao/frame ghs/ghscurve.C -o $O/ghscurve
// Prints PASSED/FAILED lines; exit status is the number of failures.

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <vector>
#include "ghs.h"

static int nfail = 0;
static void check(const char* what, int ok, const char* detail = "")
{
  if (ok)
    printf("PASSED %s\n", what);
  else {
    printf("FAILED %s\n       %s\n", what, detail);
    nfail++;
  }
}

static GhsParams P(double sf, double b, double sp, double lp, double hp)
{
  GhsParams g;
  g.sf = sf; g.b = b; g.sp = sp; g.lp = lp; g.hp = hp;
  return g;
}

int main()
{
  const double lo = 90, hi = 1090;
  const double sfs[] = {0.5, 2, 5, 10, 15};
  const double bs[] = {-5, -1, -0.5, 0, 1, 3, 10, 15};
  // (sp, lp, hp) in data units; NAN = auto. Includes the edge cases
  // LP = SP, HP = SP, LP = SP = HP, SP at either limit, values outside
  // the limits, and LP > SP (must clamp).
  const double pts[][3] = {
    {NAN, NAN, NAN}, {190, 140, 690}, {190, 190, 690}, {190, 140, 190},
    {190, 190, 190}, {lo, lo, NAN}, {hi, 390, hi}, {-50, -100, 5000},
    {101.3, NAN, NAN}, {300, 500, NAN},
  };
  const int npts = sizeof(pts)/sizeof(pts[0]);

  char buf[256];
  int mono = 1, ends = 1, inv = 1, cont = 1;
  long tabdiff = 0, tabtot = 0;
  int tabmax = 0;

  for (double sf : sfs)
    for (double b : bs)
      for (int pp=0; pp<npts; pp++) {
	GhsParams g = P(sf, b, pts[pp][0], pts[pp][1], pts[pp][2]);
	GhsCurve c(g, lo, hi);

	// monotonic, inverse round trip
	const int N = 50000;
	double prev = -1;
	for (int ii=0; ii<=N; ii++) {
	  double xx = double(ii)/N, yy = c(xx);
	  if (yy < prev - 1e-12 && mono) {
	    snprintf(buf, sizeof(buf), "sf=%g b=%g pts#%d x=%g", sf, b, pp, xx);
	    check("curve is monotonic", 0, buf);
	    mono = 0;
	  }
	  prev = yy;
	  if (yy > 1e-9 && yy < 1-1e-9 && fabs(c.inverse(yy)-xx) > 1e-6 && inv) {
	    snprintf(buf, sizeof(buf), "sf=%g b=%g pts#%d x=%g inv=%g",
		     sf, b, pp, xx, c.inverse(yy));
	    check("inverse round trip", 0, buf);
	    inv = 0;
	  }
	}

	// endpoints
	if ((fabs(c(0)) > 1e-9 || fabs(c(1)-1) > 1e-9) && ends) {
	  snprintf(buf, sizeof(buf), "sf=%g b=%g pts#%d c(0)=%g c(1)=%g",
		   sf, b, pp, c(0), c(1));
	  check("curve runs from 0 to 1", 0, buf);
	  ends = 0;
	}

	// continuous across LP, SP, HP (the joins of the piecewise curve)
	for (int kk=0; kk<3; kk++) {
	  double vv = pts[pp][kk];
	  if (!isfinite(vv))
	    continue;
	  double xx = (vv-lo)/(hi-lo);
	  if (xx <= 1e-6 || xx >= 1-1e-6)
	    continue;
	  double jump = fabs(c(xx+1e-10) - c(xx-1e-10));
	  // slope can reach ~1e7 at sf=15, so allow slope*2e-10
	  if (jump > 1e-2 && cont) {
	    snprintf(buf, sizeof(buf), "sf=%g b=%g pts#%d at x=%g jump=%g",
		     sf, b, pp, xx, jump);
	    check("curve is continuous at LP/SP/HP", 0, buf);
	    cont = 0;
	  }
	}

	// table filled in runs from the inverse vs. forward evaluation
	const int ss = 1<<14, cnt = 2048;
	std::vector<int> run(ss, -1);
	int start = 0;
	for (int kk=0; kk<cnt && start<ss; kk++) {
	  int stop = c.cellStop(kk, cnt, ss);
	  for (int ii=start; ii<stop; ii++)
	    run[ii] = kk;
	  if (stop > start)
	    start = stop;
	}
	for (int ii=0; ii<ss; ii++) {
	  int ff = (int)(c(double(ii)/ss)*cnt);
	  ff = ff<0 ? 0 : ff>=cnt ? cnt-1 : ff;
	  int dd = abs(ff-run[ii]);
	  tabtot++;
	  if (dd)
	    tabdiff++;
	  if (dd > tabmax)
	    tabmax = dd;
	}
      }

  if (mono) check("curve is monotonic", 1);
  if (inv) check("inverse round trip", 1);
  if (ends) check("curve runs from 0 to 1", 1);
  if (cont) check("curve is continuous at LP/SP/HP", 1);
  snprintf(buf, sizeof(buf), "%ld of %ld entries differ, max %d cells",
	   tabdiff, tabtot, tabmax);
  check("run-filled table matches forward table (max 1 cell, < 0.5%)",
	tabmax <= 1 && tabdiff < tabtot/200, buf);

  // stretch factor 0 is the identity
  {
    GhsCurve c(P(0, 5, 300, 200, 800), lo, hi);
    double worst = 0;
    for (int ii=0; ii<=1000; ii++)
      worst = fmax(worst, fabs(c(ii/1000.)-ii/1000.));
    snprintf(buf, sizeof(buf), "max |c(x)-x| = %g", worst);
    check("stretch 0 is the identity", worst < 1e-12, buf);
  }

  // closed forms with SP = LP = low, HP = high
  {
    double D = expm1(4.0), worst = 0;
    GhsCurve c(P(4, -1, lo, lo, hi), lo, hi);
    for (int ii=0; ii<=1000; ii++) {
      double xx = ii/1000.;
      worst = fmax(worst, fabs(c(xx) - log1p(D*xx)/log1p(D)));
    }
    snprintf(buf, sizeof(buf), "max error %g", worst);
    check("b=-1 is ln(1+Dx)/ln(1+D)", worst < 1e-12, buf);

    worst = 0;
    GhsCurve e(P(4, 0, lo, lo, hi), lo, hi);
    for (int ii=0; ii<=1000; ii++) {
      double xx = ii/1000.;
      worst = fmax(worst, fabs(e(xx) - expm1(-D*xx)/expm1(-D)));
    }
    snprintf(buf, sizeof(buf), "max error %g", worst);
    check("b=0 is (1-exp(-Dx))/(1-exp(-D))", worst < 1e-12, buf);
  }

  // auto is the same as the limits
  {
    GhsCurve a(P(6, 3, NAN, NAN, NAN), lo, hi);
    GhsCurve l(P(6, 3, lo, lo, hi), lo, hi);
    double worst = 0;
    for (int ii=0; ii<=1000; ii++)
      worst = fmax(worst, fabs(a(ii/1000.)-l(ii/1000.)));
    snprintf(buf, sizeof(buf), "max diff %g", worst);
    check("auto sp/lp/hp == low/low/high", worst == 0, buf);
  }

  // symmetry: SP in the middle, LP/HP auto, b=0: c(0.5+t) = 1 - c(0.5-t)
  {
    GhsCurve c(P(5, 0, (lo+hi)/2, NAN, NAN), lo, hi);
    double worst = 0;
    for (int ii=0; ii<=500; ii++) {
      double tt = ii/1000.;
      worst = fmax(worst, fabs(c(.5+tt) - (1-c(.5-tt))));
    }
    snprintf(buf, sizeof(buf), "max asymmetry %g", worst);
    check("curve is point-symmetric about a central SP", worst < 1e-12, buf);
  }

  // linear (tangent) below LP and above HP
  {
    GhsCurve c(P(5, 2, 590, 340, 840), lo, hi);
    double x0 = .05, x1 = .1, x2 = .15;   // all below LP = 0.25
    double d1 = c(x1)-c(x0), d2 = c(x2)-c(x1);
    double h0 = .8, h1 = .9, h2 = 1.0;   // all above HP = 0.75
    double e1 = c(h1)-c(h0), e2 = c(h2)-c(h1);
    snprintf(buf, sizeof(buf), "below LP %g vs %g, above HP %g vs %g",
	     d1, d2, e1, e2);
    check("curve is linear below LP and above HP",
	  fabs(d1-d2) < 1e-12 && fabs(e1-e2) < 1e-12, buf);
  }

  // degenerate limits don't produce NaN
  {
    GhsCurve c(P(5, 2, 100, 50, 200), 100, 100);
    int ok = 1;
    for (int ii=0; ii<=10; ii++)
      if (!isfinite(c(ii/10.)) || !isfinite(c.inverse(ii/10.)))
	ok = 0;
    check("low == high gives finite values", ok);
  }

  printf("%d failed\n", nfail);
  return nfail;
}
