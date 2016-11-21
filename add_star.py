## LB, 2015-03-11
## Python script to get relevant data for new calibrator star
## format output as SQL insert statement

import sys

import numpy as np
from astropy import coordinates
from astropy import units as u
from astroquery.simbad import Simbad

from subprocess import call

Q=Simbad()
Q.add_votable_fields('sptype')
Q.add_votable_fields('fluxdata(J)')
Q.add_votable_fields('fluxdata(H)')
Q.add_votable_fields('fluxdata(K)')


if len(sys.argv) == 2:
	# we have a name
	name_in=sys.argv[1]
	res=Q.query_object(name_in)
elif len(sys.argv) == 3:
	# we got RA/DEC
	ra_in=sys.argv[1]
	dec_in=sys.argv[2]
	C_in=coordinates.SkyCoord(ra_in, dec_in, unit=('deg','deg'), frame='icrs')
	res=Q.query_region(C_in,radius='1 degree')
else:
	raise Warning

id=res['MAIN_ID'][0].decode()
C_out=coordinates.SkyCoord(
	res['RA'][0].decode()+' '+res['DEC'][0].decode(),
	unit=(u.hourangle,u.deg))

ra_out=C_out.ra.deg
dec_out=C_out.dec.deg
sptype=res['SP_TYPE'][0].decode()
J=res['FLUX_J'][0]
H=res['FLUX_H'][0]
K=res['FLUX_K'][0]

## generate a prototype of proper class
a=np.float32(1.0)

## test if result is a magnitude (float) or not available (masked)
if (type(J)==type(a)) & (type(H)==type(a)) & (type(K)==type(a)):
	sql = "insert into std(ra,dec,name,Jmag,Hmag,Kmag,SpType) values({ra_out},{dec_out},\"{id}\",{J},{H},{K},\"{sptype}\");".format(ra_out=ra_out, dec_out=dec_out, id=id, J=J, H=H, K=K, sptype=sptype)
	print(sql)
else:
	print("{id}: no J, H and/or K mag for this star in Simbad".format(id=id))