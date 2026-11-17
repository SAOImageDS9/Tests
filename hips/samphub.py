#!/usr/bin/env python
"""A private SAMP hub for the HiPS SAMP tests (astropy.samp).

usage: python -I samphub.py <lockfile>

Writes its lockfile at <lockfile> (point ds9 at it with
SAMP_HUB=std-lockurl:file://<lockfile>), so the user's ~/.samp and any
running hub are left alone. Runs until killed.
"""
import sys
import time
import warnings
warnings.simplefilter("ignore")
from astropy.samp import SAMPHubServer

hub = SAMPHubServer(lockfile=sys.argv[1], web_profile=False)
hub.start()
try:
    while True:
        time.sleep(1)
finally:
    hub.stop()
