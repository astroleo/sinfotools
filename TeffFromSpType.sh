#!/bin/bash
## can only handle spectral types of the sort [OBAFG][0-9\.](1-3)["I","II","III","IV","V"]
## pro TeffFromSpType, SpType
SpType=$1
SpClass=${SpType:0:1}
rest=${SpType:1:${#SpType}}

##
## test whether subclass is 0-9 or decimal; round to nearest integer if decimal
a=`echo ${rest:0:3} | grep "\."`
if [ -z "$a" ]; then
	subclass=${rest:0:1}
	rest=${rest:1:${#rest}}
else
	subclass=`python3.3 -c "print(round(${rest:0:3}))"`
	rest=${rest:3:${#rest}}
fi

##
## determine luminosity class
if [ "$rest" == "I" ]; then
	file_Teff="T_eff_I.txt"
elif [ "$rest" == "II" ]; then
	## using same T_eff as for supergiants, should be about right (see HRD)
	file_Teff="T_eff_I.txt"
elif [ "$rest" == "III" ]; then
	file_Teff="T_eff_III.txt"
elif [ "$rest" == "IV" ]; then
	## using same T_eff for sub-giants as for giants, should be about right (see HRD)
	file_Teff="T_eff_V.txt"
elif [ "$rest" == "V" ]; then
	file_Teff="T_eff_V.txt"
else
	echo "Error: Luminosity class $rest unknown or peculiar spectrum."
	exit
fi

##
## determine T_eff
grep ${SpClass}${subclass} $SINFOTOOLS/calib/$file_Teff | awk -F " " '{print $2}'
