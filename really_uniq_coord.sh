#!/bin/bash
#
# takes a list of (sorted) coordinates and outputs only the ones that are separated by more than
# $maxdist arcseconds from each other

## adapter from 6really_uniq_coord.sh (which used hh:mm:ss format for input coordinates)

count=0
maxdist=5

while read LINE
do
	ra1=`echo "$LINE" | awk '{print $1}'`
	dec1=`echo "$LINE" | awk '{print $2}'`
	ra=`echo "3600 * $ra1/1" | bc` #ra in arcseconds (int)
	dec=`echo "3600 * $dec1/1" | bc` #dec in arcseconds (int)

	[ $count -eq 0 ] && ra_1=0 && dec_1=0

	dist=`echo "(0.5+sqrt(($ra - $ra_1)^2 + ($dec - $dec_1)^2))/1" | bc`
	if [ $dist -gt $maxdist ]; then
		## query simbad
		echo "Querying SIMBAD for unique coordinates: $ra1 $dec1"
		python3.4 $SINFOTOOLS/get_object_class.py $ra1 $dec1 | tee -a radec_classes.txt
	fi
	let ra_1=$ra
	let dec_1=$dec
	let count++
done < $1