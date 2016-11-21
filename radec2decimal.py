#!/usr/local/bin/python3
from astropy.coordinates import SkyCoord
from astropy import units as u
import sys

if len(sys.argv) != 3:
	raise ValueError("sys.argv does not contain 2 entries", sys.argv)

ra = sys.argv[1]
dec = sys.argv[2]
radec = ra + " " + dec
#print(radec)

c=SkyCoord(radec,unit=(u.hourangle,u.deg))
print(c.ra.value,c.dec.value)