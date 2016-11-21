## LB, 2015-03-12
## Python script to get redshift for a galaxy
## and print redshifted wavelength of a given rest wavelength

import sys

import numpy as np
from astropy import coordinates
from astropy import units as u
from astroquery.ned import Ned

id=sys.argv[1]
line=np.float(sys.argv[2])

Q=Ned.query_object(id)
z=Q['Redshift'][0]
zline=(1+z)*line

print("Redshift of {id} is {z}".format(id=id,z=z))
print("{line} is redshifted to {zline}".format(line=line,zline=zline))
