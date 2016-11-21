#!/bin/bash
##
##
## PURPOSE
##    SINFONI data reduction script
##
## PARAMETERS
##    $1   what to do: $1=0: just check if data exist, $1=1: just spred datareduction; 2: just IDL; 3: just calibration + combine; 4: everything
##    $2   night to be reduced (e.g. "2011-02-23") or dateobs (e.g. "2011-02-24T04:47:57.9841") of the reference file
##         In the first case, the first OBJECT file will be used as reference file; in the latter case
##         the file belonging to this dateobs will be used as reference file.
##         In both cases, all observations of this night taken in the same setting as the reference file will be reduced
## 
##    $3   night in which dark calibration files have been taken [optional; required if $5/$6 are set]
##    $4   night in which lamp+flat calibration files have been taken [optional; required, if $3 is given and if $5/$6 are given]
##
##    $5   earliest dateobs (e.g. 2008-03-09T09:17:52.3896) to search for object + sky files with refdit, refgrat1, refopti1  [optional]
##    $6   latest dateobs to search for object + sky files with refdit, refgrat1, refopti1  [optional; required, if $5 is given]
##
##    $7   use only this STD + associated SKY (e.g. "2009-02-17T05:20:08.5527")
##
##         if $3 is set then $4 must also be set;
##         if $5 is set then $6 must also be set;
##         i.e. this script accepts either 2, 4, 6 or 7 parameters
##
## CHANGE LOG
## 2015-09-11   Changed database name from obs to sinfo and adapted this script accordingly
## 2015-04-27   No longer repeating mxcor/skysub if files exist
## 2015-04-24   Now checking for standard star entry in database at beginning of data reduction
## 2015-04-14   Now using standard badpix map of calibration directory of epoch instead of creating my own for each observation
##              Main reason for change: bad pixel generation using spread tools often fails with Segmentation Fault
## 2015-04-14   Added check for SINFONI epoch, combined template directories into one and made time-dependent
## 2014-02-19   Added check for STD files
## 2013-08-27   Multiple changes, more automisation, bug fixes
## 2012-12-21   Added check for standard star entry in database
## 2012-12-17   bug fix: added missing mode-dependencies; before routine crashed when reducing grat1='K' data
## 2012-12-13   now writing missing files to a list, so that they can be downloaded; lamp state 'FFFFF' is now also recognized as 'off' (previously only 'FFFFFF'); bug fixes
## 2012-12-12   changed all 'cd' commands to use absolute paths; bug fixes
## 2012-12-11   now removing all links prior to setting them; background: symbolic links can apparently not be copied from one place to another using Finder's drag-and-drop copy process, i.e. with the previous implementation (simply copying links) the data reduction in a night directory would no longer work once the reduced data had been transferred.
## 2012-12-11   begin of change log
## 2012-09-06   created
##
##
## FILE NAME CONVENTIONS
##    cube_[0-9]*\.fits -- raw reduced data for obj + std
##    cube_sky_[0-9]*\.fits -- raw reduced data for sky
##    cube_[0-9]*_crop\.fits -- cropped data (by lac3dall) for obj + std
##    cube_sky_[0-9]*_crop\.fits -- cropped data (by lac3dall) for std
##    cube_[0-9]*_crop_x\.fits -- output from lac3dall (cleaned cube) for obj + std
##    cube_[0-9]*_crop_n\.fits -- output from lac3dall (noise cube) for obj + std
##    cube_sky_[0-9]*_crop_x\.fits -- output from lac3dall (cleaned cube) for sky
##    cube_sky_[0-9]*_crop_n\.fits -- output from lac3dall (noise cube) for sky
##    cube_[0-9]*_crop_x_x\.fits -- output from mxcor
##    cube_[0-9]*_crop_x_x_s\.fits -- output from skysub
##    cube_[0-9]*_crop_x_x_s_f\.fits -- flux calibrated cube
##    cube_[0-9]*_crop_x_x_s_f_a\.fits -- atmospheric and flux calibrated cube
##
##
## CAVEATS
##    - in nights with multiple targets with same settings (DIT,GRAT1,OPTI1), this script will combine all this data; workaround run combine manually, or there will be a melange of targets in one cube...
##
## OTHER NOTES
##    - currently selecting both list of darks and also individual darks, should simplify
##    - always execute script with $1=0 first -- it checks whether the directory exists
##
##
###
### --------------------------------------------------------------------------------------
### INITIALIZATION: build list of files, get reference values for dit, opti1, grat1
### --------------------------------------------------------------------------------------
###
#
# exit script if any error occurs 
set -e
#
# load old python version, set environment variables
source $HOME/spred/use_spred
#
# set some variables
dbfile="$OBSDB"
missingfile="$SINFOLOCAL/missingDPIDs.txt"
refdate=$2
filesexist=1
delta_t_max=1800 # maximum allowed time difference between target and sky, in seconds (=30 min, sufficient according to davies2007b)
#
# test if parameter is night or dateobs

if [[ $refdate == *T* ]]; then
	# we have a dateobs
	reffile=`sqlite3 $dbfile "select arcfile from sinfo where dateobs like '$refdate%';"`
	night=`sqlite3 $dbfile "select night from sinfo where dateobs like '$refdate%';"`
else
	# we have a night
	night=$2
	reffile=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='OBJECT' limit 1;"`
fi

if [ "$#" -ge 5 ]; then
	reffile=`sqlite3 $dbfile "select arcfile from sinfo where dateobs='$5';"`
fi

refdit=`sqlite3 $dbfile "select dit from sinfo where arcfile='$reffile';"`
refopti1=`sqlite3 $dbfile "select opti1 from sinfo where arcfile='$reffile';"`
refgrat1=`sqlite3 $dbfile "select grat1 from sinfo where arcfile='$reffile';"`
refHHMMSS=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$reffile';"`

idlfile=idlfile_$refHHMMSS.pro

list_calcubes="list_calcubes_${refHHMMSS}.txt"
list_calcubes_center="list_calcubes_center_${refHHMMSS}.txt"

cube_combined="cube_combined_${refHHMMSS}.fits"

##
## configure what the script actually does
##
do_prep=0
do_link=0
do_detcal=0
do_cubecal=0
do_dataredstd=0
do_datared=0
do_mx_sky=0
do_idl=0
do_atmocalib=0
do_combine=0
#
setup=$1
#
if [ $setup -eq 0 ]; then
	do_prep=1
elif [ $setup -eq 1 ]; then
	do_prep=1
	do_link=1
	do_detcal=1
	do_cubecal=1
	do_dataredstd=1
	do_datared=1
	do_mx_sky=1
elif [ $setup -eq 2 ]; then
	do_prep=1
	do_idl=1
elif [ $setup -eq 3 ]; then
	do_prep=1
	do_atmocalib=1
	do_combine=1
elif [ $setup -eq 4 ]; then
	do_prep=1
	do_link=1
	do_detcal=1
	do_cubecal=1
	do_dataredstd=1
	do_datared=1
	do_mx_sky=1
	do_idl=1
	do_atmocalib=1
	do_combine=1
else
	echo "First parameter must be 0-4."
	exit
fi
#
# determine variables (nights) to look for calibration files
if [ "$#" -eq 2 ]; then
	night_darks=$night
	night_flat_wave=$night_darks
	sinfolog "$2"
elif [[ "$#" -eq 4 || "$#" -eq 6 || "$#" -eq 7 ]]; then
	## give a different night as second argument in case no appropriate calibration files are available.
	night_darks=$3
	night_flat_wave=$4
	sinfolog "$2 $3 $4"
else
	echo "Script needs to be called with 2, 4, 6 or 7 parameters (see script)."
	exit
fi
#
# cd to $SINFOREDDIR, create night dir, if necessary
cd $SINFOREDDIR
#
# determine appropriate template directory; this depends on grat1 and observing time
#
year=`echo $night | awk -F "-" '{print $1}'`
month=`echo $night | awk -F "-" '{print $2}'`
day=`echo $night | awk -F "-" '{print $3}'`
yymmdd="$year$month$day"
epoch0="20050408"
epoch1="20060224"
epoch2="20130919"

if [ "$yymmdd" -ge "$epoch2" ]; then
	templatedir="template_$epoch2"
elif [ "$yymmdd" -ge "$epoch1" ]; then
	templatedir="template_$epoch1"
else
	templatedir="template_$epoch0"
fi

if [ ! -d "$night" ]; then
	mkdir $night
	cp -r $SINFOLOCAL/$templatedir/* $night
	sinfolog "Created directory $SINFOREDDIR/$night and copied template directory structure from $templatedir."
else
	## assume we start a new reduction with $1=0 first, i.e. the script checks if the directory exists (e.g. other data in that night have been reduced already)
	if [ "$1" -eq "0" ]; then
		echo "Data reduction directory already exists. Delete it or move it somewhere else and restart this script."
		exit
	fi
fi

cd $night
#
# build list of object files
if [[ "$#" -eq 2 || "$#" -eq 4 ]]; then
	obj=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='OBJECT' and dit=$refdit and opti1='$refopti1' and grat1='$refgrat1';"`
	sky=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='SKY' and dit=$refdit and opti1='$refopti1' and grat1='$refgrat1';"`
elif [[ "$#" -eq 6 || "$#" -eq 7 ]]; then
	obj=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='OBJECT' and dit=$refdit and opti1='$refopti1' and grat1='$refgrat1' and dateobs between '$5' and '$6';"`
	sky=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='SKY' and dit=$refdit and opti1='$refopti1' and grat1='$refgrat1' and dateobs between '$5' and '$6';"`
else
	echo "Script must be called with 2, 4, 6 or 7 parameters."
fi

objsky="$obj $sky"
for f in $objsky; do
	fpath=$SINFODATA/$night/$f
	if [ ! -f $fpath ]; then
		sinfolog "Object/sky file $fpath not available."
		echo $f | awk -F ".fits" '{ print $1 }' >> $missingfile
		filesexist=0
	fi
done


### check if standard stars are known (same check is done again at beginning of std data reduction section)
#
# get list of all standard star observations of the night in the relevant mode
if [ "$#" -eq 7 ]; then
	stds=`sqlite3 $dbfile "select arcfile from sinfo where dateobs=\"$7\";"`
else
	stds=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='STD' and opti1=$refopti1 and grat1='$refgrat1';"`
fi
for std in $stds; do
	#
	# check if calibrator exists in database, otherwise exit
	ra_std=`sqlite3 $dbfile "select ra from sinfo where arcfile='$std';"`
	dec_std=`sqlite3 $dbfile "select dec from sinfo where arcfile='$std';"`
	##
	## define 10 arcsec search box, i.e. 0.0028
	searchrad=$(echo "scale=6;10/3600" | bc)
	ra_min=$(echo "$ra_std - $searchrad" | bc)
	ra_max=$(echo "$ra_std + $searchrad" | bc)
	dec_min=$(echo "$dec_std - $searchrad" | bc)
	dec_max=$(echo "$dec_std + $searchrad" | bc)
	##
	## get number of standard stars near that position, exit if != 1
	nstd_db=`sqlite3 $dbfile "select count(*) from std where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"`
	if [ ! $nstd_db -eq 1 ]; then
		sinfolog "Standard star $std at $ra_std $dec_std is not in database. Ignoring this one."
		continue
	fi
done
		
###
### --------------------------------------------------------------------------------------
### PREPARATION: Check that required calibration files exist
### --------------------------------------------------------------------------------------
###
##
## --------------------------------------------------------------------------------------
## TEST IF NECESSARY RAW FILES ARE AVAILABLE
## Requirements:
##
## (1) three or more DARK files of same DIT as given OBJECT files -- automatically checked
## (2) three or more short DARK files (< 20 s) for bad pixel detection -- automatically checked
## (3) ten or more FLAT,LAMP files (5 pairs with LAMP ON/OFF) of same GRAT1, OPTI1 as OBJECT files -- automatically checked
## (4) two WAVE,LAMP files (1 pair with LAMP ON/OFF) of same GRAT1, OPTI1 as OBJECT files -- automatically checked
## (5) standard files of same settings and between object files -- to be checked manually
## (6) sufficiently frequent SKY files between object files -- to be checked manually
## --------------------------------------------------------------------------------------
##


if [ $do_prep -eq 1 ]; then
	#
	# Find shortest dark files (at least three) that exist on disk
	shortestdit_available=`sqlite3 $dbfile "select dit from sinfo where night='$night_darks' and dit < 30 and dprtype='DARK' order by dit limit 1;"`
	ndark_short=`sqlite3 $dbfile "select count(*) from sinfo where night='$night_darks' and dprtype='DARK' and dit='$shortestdit_available';"`
	if [ $ndark_short -lt 3 ]; then sinfolog "less than three short dark files found. Exiting." & exit; fi
	dark_short1=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_darks' and dprtype='DARK' and dit=$shortestdit_available limit 1;"`
	dark_short2=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_darks' and dprtype='DARK' and dit=$shortestdit_available limit 1 offset 1;"`
	dark_short3=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_darks' and dprtype='DARK' and dit=$shortestdit_available limit 1 offset 2;"`
	echo $night_darks
	
	f_dark_short1=$SINFODATA/$night_darks/$dark_short1
	f_dark_short2=$SINFODATA/$night_darks/$dark_short2
	f_dark_short3=$SINFODATA/$night_darks/$dark_short3

	if [ ! -f $f_dark_short1 ]; then
		sinfolog "short dark file 1 $f_dark_short1 does not exist."
		echo $dark_short1 | awk -F ".fits" '{ print $1 }' >> $missingfile
		filesexist=0
	fi
	if [ ! -f $f_dark_short2 ]; then
		sinfolog "short dark file 2 $f_dark_short2 does not exist."
		echo $dark_short2 | awk -F ".fits" '{ print $1 }' >> $missingfile
		filesexist=0
	fi
	if [ ! -f $f_dark_short3 ]; then
		sinfolog "short dark file 3 $f_dark_short3 does not exist."
		echo $dark_short3 | awk -F ".fits" '{ print $1 }' >> $missingfile
		filesexist=0
	fi
	#
	# check that DITs are equal
	dit_short1=`sqlite3 $dbfile "select dit from sinfo where arcfile='$dark_short1';"`
	dit_short2=`sqlite3 $dbfile "select dit from sinfo where arcfile='$dark_short2';"`
	dit_short3=`sqlite3 $dbfile "select dit from sinfo where arcfile='$dark_short3';"`
	if [ ! $dit_short1 == $dit_short2 ] || [ ! $dit_short1 == $dit_short3 ]; then
		sinfolog "DITs of short dark files differ. Exiting"
		exit
	fi
	#
	# find dark files for OBJ/SKY calibration (at least three)
	darks_obj=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_darks' and dprtype='DARK' and dit=$refdit limit 3;"`
	ndark_obj=`echo $darks_obj | wc -w`
	if [ ! $ndark_obj -eq 3 ]; then sinfolog "number of dark files for object DIT $refdit != 3. Exiting." & exit; fi
	for dark_obj in $darks_obj; do
		f_dark_obj=$SINFODATA/$night_darks/$dark_obj
		if [ ! -f $f_dark_obj ]; then
			sinfolog "DARK file $f_dark_obj does not exist."
			echo $dark_obj | awk -F ".fits" '{ print $1 }' >> $missingfile
			filesexist=0
		fi
	done
	dark_obj1=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_darks' and dprtype='DARK' and dit=$refdit limit 1;"`
	dark_obj2=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_darks' and dprtype='DARK' and dit=$refdit limit 1 offset 1;"`
	dark_obj3=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_darks' and dprtype='DARK' and dit=$refdit limit 1 offset 2;"`
	f_dark_obj1=$SINFODATA/$night_darks/$dark_obj1
	f_dark_obj2=$SINFODATA/$night_darks/$dark_obj2
	f_dark_obj3=$SINFODATA/$night_darks/$dark_obj3
	#
	# find FLAT files
	flats=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_flat_wave' and dprtype LIKE '%FLAT%' and dprtype!='DISTORTION,FLAT,NS' and opti1=$refopti1 and grat1='$refgrat1' limit 10;"`
	nflats=`echo $flats | wc -w`
	if [ ! $nflats -eq 10 ]; then sinfolog "number of FLAT files != 5 pairs. Double check!" & exit; fi
	for iflat in $flats; do
		fflat=$SINFODATA/$night_flat_wave/$iflat
		if [ ! -f $fflat ]; then
			sinfolog "FLAT file $fflat does not exist."
			echo $iflat | awk -F ".fits" '{ print $1 }' >> $missingfile
			filesexist=0
		fi
	done
	#
	# find WAVE files
	waves=`sqlite3 $dbfile "select arcfile from sinfo where night='$night_flat_wave' and dprtype LIKE '%WAVE%' and dprtype!='DISTORTION,WAVE,NS' and opti1=$refopti1 and grat1='$refgrat1' order by dateobs limit 2;"`
	nwaves=`echo $waves | wc -w`
	if [ ! $nwaves -eq 2 ]; then sinfolog "number of WAVE files < 1 pair. Double check!" & exit; fi
	for iwave in $waves; do
		fwave=$SINFODATA/$night_flat_wave/$iwave
		if [ ! -f $fwave ]; then
			sinfolog "WAVE file $fwave does not exist."
			echo $iwave | awk -F ".fits" '{ print $1 }' >> $missingfile
			filesexist=0
		fi
	done
	#
	# find STD files
	std=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype LIKE '%STD%' and opti1=$refopti1 and grat1='$refgrat1';"`
	nstd=`echo $std | wc -w`
	if [ $nstd -eq 0 ]; then sinfolog "Found no STD files with opti1=$refopti1 and grat1=$refgrat1. Exiting." & exit; fi
	for istd in $std; do
		fstd=$SINFODATA/$night/$istd
		if [ ! -f $fstd ]; then
			sinfolog "STD file $fstd does not exist."
			echo $istd | awk -F ".fits" '{ print $1 }' >> $missingfile
			filesexist=0
		fi
	done
	#
	if [ $filesexist == 1 ]; then sinfolog "Necessary raw data is available."; else exit; fi
fi
###
### --------------------------------------------------------------------------------------
### LINK DARK FILES
### --------------------------------------------------------------------------------------
###
if [ $do_link -eq 1 ]; then
	if [ ! $do_prep -eq 1 ]; then sinfolog "Need to set do_prep=1 to run linking process." & exit; fi
	cd $SINFOREDDIR/$night/dark
	#
	# link short dark files
	short1="dark.short.1.fits"
	short2="dark.short.2.fits"
	short3="dark.short.3.fits"
	if [ -h $short1 ]; then rm $short1; fi
	if [ -h $short2 ]; then rm $short2; fi
	if [ -h $short3 ]; then rm $short3; fi
	ln -s $f_dark_short1 $short1
	ln -s $f_dark_short2 $short2
	ln -s $f_dark_short3 $short3
	sinfolog "Linked short dark files."
	#
	# link dark files for object/sky observations
	long1="dark.long.1.fits"
	long2="dark.long.2.fits"
	long3="dark.long.3.fits"
	if [ -h $long1 ]; then rm $long1; fi
	if [ -h $long2 ]; then rm $long2; fi
	if [ -h $long3 ]; then rm $long3; fi
	ln -s $f_dark_obj1 $long1
	ln -s $f_dark_obj2 $long2
	ln -s $f_dark_obj3 $long3
	sinfolog "Linked object/sky dark files."
fi
###
### --------------------------------------------------------------------------------------
### GENERATE LIST OF FLAT CALIBRATION FILES, PRODUCE FLATFIELD CALIBRATION FILES, PRODUCE BAD PIXEL MAP
### --------------------------------------------------------------------------------------
###
if [ $do_detcal -eq 1 ]; then
	flatlist="$SINFOREDDIR/$night/flat/flat.list"
	if [ ! -f $flatlist ]; then
		for flat in $flats; do
			lamps=`sqlite3 $dbfile "select lamps from sinfo where arcfile='$flat';"`
			if [[ $lamps == "FFFFFF" ]] || [[ $lamps == "FFFFF" ]]; then lamptext="Off";
			elif [[ $lamps == *T* ]]; then lamptext="On";
			else sinfolog "lamps in unknown state: $lamps. Exiting." & exit; fi
			echo "$SINFODATA/$night_flat_wave/$flat $lamptext" >> $flatlist
		done
	fi
	#
	cd $SINFOREDDIR/$night/flat
	if [ ! -f flat.fits ]; then
		spredCreateFlat.py -f flat.ini
		sinfolog "Produced flat field files"
	fi
	#
	cd $SINFOREDDIR/$night/badpix
	if [ ! -f badpix.fits ]; then
		sinfolog "Badpix map is missing"
	fi

## Now (2015-04-14) using badpix map from standard calibration directory because the spredCreateBadpix.py routine often crashes with Segmentation fault.
##
#	if [ ! -f badpix.fits ] || [ ! -f badpix.flat.fits ] || [ ! -f badpix.dark.long.fits ] || [ ! -f badpix.dark.short.fits ]; then
#		spredPrepFrame.py -f prep.dark.long.ini
#		spredPrepFrame.py -f prep.dark.short.ini
#		spredCreateBadpix.py -f badpix.dark.long.ini
#		spredCreateBadpix.py -f badpix.dark.short.ini
#		spredCreateBadpix.py -f badpix.flat.ini
#		spredCombineMasks.py badpix.dark.long.fits badpix.dark.short.fits badpix.fits
#		spredCombineMasks.py badpix.fits badpix.flat.fits badpix.fits
#		sinfolog "Produced bad pixel map"
#	fi
fi
###
### --------------------------------------------------------------------------------------
### CUBE CALIBRATION
### --------------------------------------------------------------------------------------
###
if [ $do_cubecal -eq 1 ]; then
	cd $SINFOREDDIR/$night/lookup
	#
	columnfile="columns.fits"
	indexfile="index.list"
	rowsfile="rows.fits"
	if [ -f $columnfile ]; then
		rm $columnfile
		ln -s $SINFOLOCAL/$templatedir/lookup/columns.fits $columnfile
	fi
	if [ -f $indexfile ]; then
		rm $indexfile
		ln -s $SINFOLOCAL/$templatedir/lookup/index.list $indexfile
	fi
	if [ -f $rowsfile ]; then
		rm $rowsfile
		ln -s $SINFOLOCAL/$templatedir/lookup/rows.fits $rowsfile
	fi

	cd $SINFOREDDIR/$night/	
	linefile="slitpos/line.list"
	slitposfile="slitpos/slitpos.ini"
	distancefile="distances/distances.list"
	distortionfile="distortion/distortion.list"
	firstcolfile="firstcol/firstcol.list"
	waveinifile="wave/wave.ini"
	if [ -h $linefile ]; then rm $linefile; fi
	if [ -h $slitposfile ]; then rm $slitposfile; fi
	if [ -h $distancefile ]; then rm $distancefile; fi
	if [ -h $distortionfile ]; then rm $distortionfile; fi
	if [ -h $firstcolfile ]; then rm $firstcolfile; fi
	if [ -h $waveinifile ]; then rm $waveinifile; fi
	#
	if [ "$refgrat1" == 'H+K' ]; then
		ln -s $SINFOLOCAL/$templatedir/slitpos/line_H+K.list $linefile
		ln -s $SINFOLOCAL/$templatedir/slitpos/slitpos_H+K.ini $slitposfile
		ln -s $SINFOLOCAL/$templatedir/distances/distances_H+K.list $distancefile
		ln -s $SINFOLOCAL/$templatedir/distortion/distortion_H+K.list $distortionfile
		ln -s $SINFOLOCAL/$templatedir/firstcol/firstcol_H+K.list $firstcolfile
		ln -s $SINFOLOCAL/$templatedir/wave/wave_H+K.ini $waveinifile
	elif [ "$refgrat1" == 'K' ]; then
		ln -s $SINFOLOCAL/$templatedir/slitpos/line_K.list $linefile
		ln -s $SINFOLOCAL/$templatedir/slitpos/slitpos_K.ini $slitposfile
		ln -s $SINFOLOCAL/$templatedir/distances/distances_K.list $distancefile
		ln -s $SINFOLOCAL/$templatedir/distortion/distortion_K.list $distortionfile
		ln -s $SINFOLOCAL/$templatedir/firstcol/firstcol_K.list $firstcolfile
		ln -s $SINFOLOCAL/$templatedir/wave/wave_K.ini $waveinifile
	elif [ "$refgrat1" == 'H' ]; then
#		ln -s $SINFOLOCAL/template/slitpos/line_H.list $linefile
#		ln -s $SINFOLOCAL/template/slitpos/slitpos_H.ini $slitposfile
#		ln -s $SINFOLOCAL/template/distances/distances_H.list $distancefile
#		ln -s $SINFOLOCAL/template/distortion/distortion_H.list $distortionfile
		sinfolog "I don't know full calibration set for H band data!"
		exit
	else sinfolog "unknown refgrat1: $refgrat1. Exiting." & exit; fi
	#
	cd $SINFOREDDIR/$night/slitpos
	if [ ! -f slitpos.list ]; then
		slitposlist="prep.list"
		if [ -f $slitposlist ]; then rm $slitposlist; fi
		for wave in $waves; do
			lamps=`sqlite3 $dbfile "select lamps from sinfo where arcfile='$wave';"`
			if [[ $lamps == "FFFFFF" ]] || [[ $lamps == "FFFFF" ]]; then lamptext="Off";
			elif [[ $lamps == *T* ]]; then lamptext="On";
			else sinfolog "lamps in unknown state: $lamps. Exiting." & exit; fi
			echo "$SINFODATA/$night_flat_wave/$wave $lamptext" >> $slitposlist
		done
		spredPrepFrame.py -f prep.ini
		spredCreateSlitpos.py -f slitpos.ini
	fi
	#
	cd $SINFOREDDIR/$night/wave
	if [ ! -f wave.fits ] || [ ! -f resampled.fits ] || [ ! -f cube.fits ]; then
		linefile="line.list"
		prepfile="prep.list"
		if [ -h $linefile ]; then rm $linefile; fi
		if [ -h $prepfile ]; then rm $prepfile; fi
		ln -s ../slitpos/line.list $linefile
		ln -s ../slitpos/prep.list $prepfile

		spredPrepFrame.py -f prep.ini
		spredCreateWavemap.py -f wave.ini ## lots of errors
		spredCreateResampled.py -f resampled.ini
		spredCreateCube.py -f cube.ini
	fi
	#
	cd $SINFOREDDIR/$night/lookup
	if [ ! -f X.fits ] || [ ! -f Y.fits ] || [ ! -f Z.fits ] || [ ! -f cX.fits ]; then
		spredCreateLookup.py ../distortion/distortion.list ../wave/wave.fits ../distances/distances.list ../firstcol/firstcol.list
	fi
	#
	sinfolog "Finished cube calibration"
fi

###
### --------------------------------------------------------------------------------------
### DATA REDUCTION of STD
### --------------------------------------------------------------------------------------
###
if [ $do_dataredstd -eq 1 ]; then
	sinfolog "Starting STD data reduction"
	cd $SINFOREDDIR/$night/standard
	#
	# get list of all standard star observations of the night in the relevant mode
	if [ "$#" -eq 7 ]; then
		stds=`sqlite3 $dbfile "select arcfile from sinfo where dateobs=\"$7\";"`
	else
		stds=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='STD' and opti1=$refopti1 and grat1='$refgrat1';"`
	fi

	for std in $stds; do
		#
		# check if calibrator exists in database, otherwise exit
		ra_std=`sqlite3 $dbfile "select ra from sinfo where arcfile='$std';"`
		dec_std=`sqlite3 $dbfile "select dec from sinfo where arcfile='$std';"`
		##
		## define 10 arcsec search box, i.e. 0.0028
		searchrad=$(echo "scale=6;10/3600" | bc)
		ra_min=$(echo "$ra_std - $searchrad" | bc)
		ra_max=$(echo "$ra_std + $searchrad" | bc)
		dec_min=$(echo "$dec_std - $searchrad" | bc)
		dec_max=$(echo "$dec_std + $searchrad" | bc)
		##
		## get number of standard stars near that position, exit if != 1
		nstd_db=`sqlite3 $dbfile "select count(*) from std where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"`
		if [ ! $nstd_db -eq 1 ]; then
			sinfolog "Standard star $std at $ra_std $dec_std is not in database. Ignoring this one."
			continue
		fi
		#
		# for each std get closest std,sky in same mode. If more than $delta_t_max apart, warn and exit
		dateobs_std=`sqlite3 $dbfile "select dateobs from sinfo where arcfile='$std';"`
		
		HHMMSS=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$std';"`
		std_sky=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='SKY,STD' order by abs((strftime('%s','$dateobs_std') - strftime('%s',dateobs))) limit 1;"`
		#
		# difference in time between std and std_sky in seconds
		delta_t_sec=`sqlite3 $dbfile "select abs(strftime('%s','$dateobs_std') - strftime('%s',dateobs)) from sinfo where arcfile='$std_sky';"`

		if [ $delta_t_sec -gt $delta_t_max ]; then
			sinfolog "Difference between std ($std) and std,sky ($std_sky) is $delta_t_sec s (> $delta_t_max s). Using DARK instead."
			## using $night for DARK; perhaps change this to night_darks...?
			dit_std=`sqlite3 $dbfile "select dit from sinfo where arcfile='$std';"`
			std_sky=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='DARK' and dit=$dit_std limit 1;"`
			if [ ! -f "$SINFODATA/$night/$std_sky" ]; then
				sinfolog "DARK file for STD ($SINFODATA/$night/$std_sky) does not exist."
				echo $std_sky | awk -F ".fits" '{ print $1 }' >> $missingfile
				exit
			fi
		fi
		#
		# name of files for this standard will be prep_HHMMSS.ini, cube_HHMMSS.ini etc.
		prepinifile=prep_$HHMMSS.ini
		listfile=prep_$HHMMSS.list
		prepfile=prep_$HHMMSS.fits
		cubeinifile=cube_$HHMMSS.ini
		cubefile=cube_$HHMMSS.fits
		if [ -f "$cubefile" ]; then sinfolog "Cube file $cubefile exists. Continuing..." & continue; fi
		if [ -f "$listfile" ]; then rm $listfile; fi
		echo "$SINFODATA/$night/$std On" >> $listfile
		echo "$SINFODATA/$night/$std_sky Off" >> $listfile
		#
		# create prep?.ini: replace lines starting with InFile and OutFile
		cp $SINFOLOCAL/$templatedir/standard/prep.ini $prepinifile
		sed "s/InFile.*/InFile=$listfile/g" $prepinifile > tmp
		sed "s/OutName.*/OutName=$prepfile/g" tmp > tmp2
		mv tmp2 $prepinifile
		rm tmp
		spredPrepFrame.py -f $prepinifile
		#
		# create cube?.ini
		cp $SINFOLOCAL/$templatedir/standard/cube.ini $cubeinifile
		sed "s/InFrame.*/InFrame=$prepfile/g" $cubeinifile > tmp
		sed "s/OutName.*/OutName=$cubefile/g" tmp > tmp2
		mv tmp2 $cubeinifile
		rm tmp
		spredCreateCube.py -f $cubeinifile
		sinfolog "Done reducing standard star cube $std ($cubefile)."
	done
fi
###
### --------------------------------------------------------------------------------------
### DATA REDUCTION OBJECT and SKY FILES
### --------------------------------------------------------------------------------------
###
# produce file lists in working directory with object+dark files (prep$i.list) and sky+dark (prep$i_sky.list); reduce using spredPrepFrame, spredCreateCube
if [ $do_datared -eq 1 ]; then
	sinfolog "Starting object and sky data reduction"
	cd $SINFOREDDIR/$night/data
	for objfile in $obj
	do
		HHMMSS=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$objfile';"`
		prepinifile=prep_$HHMMSS.ini
		listfile=prep_$HHMMSS.list
		prepfile=prep_$HHMMSS.fits
		cubefile=cube_$HHMMSS.fits
		cubeinifile=cube_$HHMMSS.ini
		if [ -f "$cubefile" ]; then sinfolog "Cube file $cubefile exists. Continuing..." & continue; fi
		if [ -f "$listfile" ]; then rm $listfile; fi
		echo "$SINFODATA/$night/$objfile On" >> $listfile
		for dark_obj in $darks_obj
		do
			echo "$SINFODATA/$night_darks/$dark_obj Off" >> $listfile
		done
		# create prep?.ini: replace lines starting with InFile and OutFile
		cp prep.ini $prepinifile
		sed "s/InFile.*/InFile=$listfile/g" $prepinifile > tmp
		sed "s/OutName.*/OutName=$prepfile/g" tmp > tmp2
		mv tmp2 $prepinifile
		rm tmp
		spredPrepFrame.py -f $prepinifile
	
		# create cube?.ini
		cp cube.ini $cubeinifile
		sed "s/InFrame.*/InFrame=$prepfile/g" $cubeinifile > tmp
		sed "s/OutName.*/OutName=$cubefile/g" tmp > tmp2
		mv tmp2 $cubeinifile
		rm tmp
		spredCreateCube.py -f $cubeinifile
		sinfolog "Done reducing object file cube $objfile ($cubefile)." 
	done
	
	# same as above but for sky files
	for skyfile in $sky
	do
		HHMMSS=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$skyfile';"`
		prepinifile=prep_sky_$HHMMSS.ini
		listfile=prep_sky_$HHMMSS.list
		prepfile=prep_sky_$HHMMSS.fits
		cubefile=cube_sky_$HHMMSS.fits
		cubeinifile=cube_sky_$HHMMSS.ini
		if [ -f "$cubefile" ]; then sinfolog "Cube file $cubefile exists. Continuing..." & continue;	fi
		if [ -f "$listfile" ]; then rm $listfile; fi
		echo "$SINFODATA/$night/$skyfile On" >> $listfile
		for darkfile in $dark
		do
			echo "$SINFODATA/$night_darks/$darkfile Off" >> $listfile
		done
		# create prep?.ini: replace lines starting with InFile and OutFile
		cp prep.ini $prepinifile
		sed "s/InFile.*/InFile=$listfile/g" $prepinifile > tmp
		sed "s/OutName.*/OutName=$prepfile/g" tmp > tmp2
		mv tmp2 $prepinifile
		rm tmp
		spredPrepFrame.py -f $prepinifile
	
		# create cube?.ini
		cp cube.ini $cubeinifile
		sed "s/InFrame.*/InFrame=$prepfile/g" $cubeinifile > tmp
		sed "s/OutName.*/OutName=$cubefile/g" tmp > tmp2
		mv tmp2 $cubeinifile
		rm tmp
		spredCreateCube.py -f $cubeinifile
		sinfolog "Done reducing sky cube $skyfile ($cubefile)."
	done
	sinfolog "Finished with spredCreateCube tasks."
fi
###
### --------------------------------------------------------------------------------------
### MXCOR and SKYSUB -- produce idlfile that has then to be executed in IDL
### --------------------------------------------------------------------------------------
###
if [ $do_mx_sky -eq 1 ]; then
	sinfolog "Creating idlfile for mxcor and skysub"
	cd $SINFOREDDIR/$night/data
	if [ -f "$idlfile" ]; then
		rm $idlfile
	fi

	nskysub=0
	for objfile in $obj; do
		#
		# test if skysub file exists
		fskysub=cube_${HHMMSS_obj}_crop_x_x_s.fits
		if [[ -e $fskysub ]]; then continue; fi
		#
		# for each object get closest sky in same mode. If more than $delta_t_max apart, warn and exit
		dateobs_obj=`sqlite3 $dbfile "select dateobs from sinfo where arcfile='$objfile';"`
		sky=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='SKY' order by abs((strftime('%s','$dateobs_obj') - strftime('%s',dateobs))) limit 1;"`
		#
		# difference in time between object and sky in seconds
		delta_t_sec=`sqlite3 $dbfile "select abs(strftime('%s','$dateobs_obj') - strftime('%s',dateobs)) from sinfo where arcfile='$sky';"`
		if [ $delta_t_sec -gt $delta_t_max ]; then sinfolog "Difference between object ($objfile) and sky ($sky) is $delta_t_sec s (> $delta_t_max s). Exiting." & exit; fi
		#
		# define file names
		HHMMSS_obj=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$objfile';"`
		cubefile=cube_${HHMMSS_obj}_crop_x.fits
		cubefile_x=cube_${HHMMSS_obj}_crop_x_x.fits
		HHMMSS_sky=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$sky';"`
		skyfile_closest=cube_sky_${HHMMSS_sky}_crop_x.fits
		#
		# write IDL file
		echo mxcor, \'$cubefile\', \'$skyfile_closest\' >> $idlfile   ## produces cube_$HHMMSS_crop_x_x.fits files
		echo skysub, \'$cubefile_x\', \'$skyfile_closest\', /tbsub, minfrac=0.3 >> $idlfile  ## produces cube_$HHMMSS_crop_x_x_s.fits files
		nskysub=$nskysub+1
	done
	echo exit >> $idlfile
	if [[ $nskysub -eq 0 ]]; then sinfolog "Nothing to do for IDL (probably all skysub files already exist)."; fi
	sinfolog "Created $idlfile."
fi


###
### --------------------------------------------------------------------------------------
### EXECUTE IDL batch script to run lac3dall (crop cubes, run lac3d), mxcor and skysub
### --------------------------------------------------------------------------------------
###
if [ $do_idl -eq 1 ]; then
	sinfolog "Starting computer-power intensive IDL processes..."
	sinfolog "Starting lac3d -- this will take a while"
	cd $SINFOREDDIR/$night
	idl -e lac3dall
	sinfolog "Starting mxcor and skysub"
	cd $SINFOREDDIR/$night/data
	##
	## crude way of checking whether mxcor/skysub has been run: check if number of _x_x_s.fits files is same as number of _crop.fits files
	## need grep to exclude cube_sky* files.
	##
	n_crop=$(find . | egrep "cube_[0-9]{6}_crop.fits" | wc -l)
	n_mxsky=$(find . | egrep "cube_[0-9]{6}_crop_x_x_s.fits" | wc -l)
	if [ $n_crop -eq $n_mxsky ]; then
		sinfolog "It appears mxcor and skysub have been completed successfully. Skipping this step."
	else
		idl $idlfile
	fi
	sinfolog "Finished with computer-power intensive IDL processes."
fi


###
### --------------------------------------------------------------------------------------
### ATMOSPHERIC and FLUX CALIBRATION: currently a mix of IDL and shell scripts
### --------------------------------------------------------------------------------------
###
if [ $do_atmocalib -eq 1 ]; then
	cd $SINFOREDDIR/$night/standard
	ncubes=`find * | egrep "^cube_[0-9]{6}_crop_x\.fits$" | wc -l`
	if [ $ncubes -eq 0 ]; then
		sinfolog "No reduced standard star cubes found."
		exit
	fi
	sinfolog "Extracting standard star spectra"
	idl -e c2a
	sinfolog "Starting atmospheric calibration"
	cd $SINFOREDDIR/$night/data

	for iobj in $obj; do
		#
		# select closest standard star
		dateobs_obj=`sqlite3 $dbfile "select dateobs from sinfo where arcfile='$iobj';"`
		HHMMSS_obj=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$iobj';"`
		closestcal=`sqlite3 $dbfile "select arcfile from sinfo where night='$night' and dprtype='STD' and opti1=$refopti1 and grat1='$refgrat1' order by abs((strftime('%s','$dateobs_obj') - strftime('%s',dateobs))) limit 1;"`
		HHMMSS_standard=`sqlite3 $dbfile "select strftime('%H%M%S',dateobs) from sinfo where arcfile='$closestcal';"`
		ra_std=`sqlite3 $dbfile "select ra from sinfo where arcfile='$closestcal';"`
		dec_std=`sqlite3 $dbfile "select dec from sinfo where arcfile='$closestcal';"`
		#
		# first: atmospheric calibration with spectrum extracted from standard such that SNR is maximized (small aperture)
		atmofile=../standard/atmosphere_${HHMMSS_standard}.fits
#		atmofile_corrected=../standard/atmosphere_${HHMMSS_standard}_corrected.fits
		cube_std_in=../standard/cube_${HHMMSS_standard}_crop_x.fits
		cube_std_out=../standard/cube_${HHMMSS_standard}_crop_x_a.fits
		cube_in=cube_${HHMMSS_obj}_crop_x_x_s.fits
		cube_out=cube_${HHMMSS_obj}_crop_x_x_s_a.fits
		cube_calib=cube_${HHMMSS_obj}_crop_x_x_s_a_f.fits
		# check if data is reduced and available
		if [ ! -f $atmofile ]; then sinfolog "Atmospheric transmission spectrum ($atmofile) missing. Exiting." & exit; fi
#		if [ ! -f $atmofile_corrected ]; then sinfolog "Corrected atmospheric transmission spectrum ($atmofile_corrected) missing. Exiting." & exit; fi
		if [ ! -f $cube_in ]; then sinfolog "Cube file ($cube_in) missing. Exiting." & exit; fi
		#
		spredDivCubeBySpec.py $cube_in $atmofile $cube_out
		if [ ! -f $cube_std_out ]; then spredDivCubeBySpec.py $cube_std_in $atmofile $cube_std_out; fi
		#
		# define 10 arcsec search box, i.e. 0.0028
		searchrad=$(echo "scale=6;10/3600" | bc)
		ra_min=$(echo "$ra_std - $searchrad" | bc)
		ra_max=$(echo "$ra_std + $searchrad" | bc)
		dec_min=$(echo "$dec_std - $searchrad" | bc)
		dec_max=$(echo "$dec_std + $searchrad" | bc)
		Hmag=`sqlite3 $dbfile "select Hmag from std where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"`
		Kmag=`sqlite3 $dbfile "select Kmag from std where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"`
		std_name=`sqlite3 $dbfile "select name from std where ra between $ra_min and $ra_max and dec between $dec_min and $dec_max;"`
		#
		# second: flux calibration with spectrum extracted from std star such that entire flux is included
		spectrum_std_atmo=../standard/spectrum_${HHMMSS_standard}_a_total.fits
		idl -e flux_calib2 -args $Hmag $Kmag "$cube_std_out" "$spectrum_std_atmo" "$cube_out" "$cube_calib" "$std_name"
		echo $cube_calib >> $list_calcubes
	done
	sinfolog "Done with atmospheric and flux calibration of all cubes."
fi
###
### --------------------------------------------------------------------------------------
### CENTROID POSITIONS, CUBE COMBINATION
### --------------------------------------------------------------------------------------
###
if [ $do_combine -eq 1 ]; then
	sinfolog "Determining center position in each cube in K band"
	cd $SINFOREDDIR/$night/data
	
	if [ ! -f $list_calcubes ]; then echo "Missing file $list_calcubes; exiting"; exit; fi
	if [ -f $list_calcubes_center ]; then echo "File $list_calcubes_center exists; exiting"; exit; fi

	idl -e cube_get_center_list -args "$list_calcubes" "$list_calcubes_center"

	if [ ! -f $list_calcubes_center ]; then
		sinfolog "$list_calcubes_center does not exist. Exiting."
		exit
	else
		sinfolog "Now combining cubes to $cube_combined using $list_calcubes_center."
		spredCombineCubesbySlice.py $list_calcubes_center 2 $cube_combined
		sinfolog "Created combined cube $cube_combined."
	fi
fi
sinfolog "Done reducing data for reference file $reffile."

sinfolog "Next: Manually combine cubes from various nights."