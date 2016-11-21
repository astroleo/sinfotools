#!/bin/bash
## can only handle simple spectral types of the sort [OBAFGK][0-9]
SpClass=${1:0:2}

##
## test whether proper spectral class
if [[ ! $SpClass =~ [OBAFGK][0-9] ]]; then
	sinfolog "TeffFromSpType_simple: Spectral type not like [OBAFGK][0-9]."
	echo "Error: Spectral type not like [OBAFGK][0-9]." ## issue error to be caught by SpTypeFromFile.pro
	echo 0
	exit
fi

file_Teff="T_eff_V_interpolated.txt"
##
## determine T_eff
T_eff=`grep $SpClass $SINFOTOOLS/calib/$file_Teff | awk -F " " '{print $2}'`

##
## T_eff should be between 2000 and 60000 K
if [[ $T_eff -lt 2000 || $T_eff -gt 60000 ]]; then
	echo "Error: Could not determine T_eff ($T_eff)."
else
	echo $T_eff
fi
