## LB, 2015-03-11
## Python script to get relevant data for new calibrator star
## format output as SQL insert statement

import sys

import numpy as np
from astropy import coordinates
from astropy import units as u
from astroquery.simbad import Simbad

ra_in=sys.argv[1]
dec_in=sys.argv[2]

Q=Simbad()
Q.add_votable_fields('otype')

C_in=coordinates.SkyCoord(ra_in, dec_in, unit=('deg','deg'), frame='icrs')

res=Q.query_region(C_in,radius='1 degree')

id=res['MAIN_ID'][0].decode()
objClass=res['OTYPE'][0].decode()


print("{id} is of class {objClass}".format(id=id, objClass=objClass))
