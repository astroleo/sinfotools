#!/bin/bash
##
## Written by Leonard Burtscher (burtscher@mpe.mpg.de)
##
## MODIFICATION RECORD
## 2013-01-16   added rescue.sh to this script. Workflow now: this script sorts data into
##                the proper directories in $SINFODATA-RAW, "rescue.sh" calls "rescue.
##                dpuser" to debias the files and moves the modified files to $SINFODATA
## 2012-11-28   initial version, adapted from filesorter.sh (for MIDI data)
##
## PURPOSE
##
## 
## The purpose of this script is to sort SINFONI data according to observation
## date.
##
## For every file moved it will output one line to STDOUT; if a file already 
## exists at the target location, the file is not moved and a message is
## displayed
##
##
##
############ DEFINITIONS ############
##
## Absolute path to directory with files to be sorted
sdir=$SINFODATAIN
##
## Absolute path to archive (with sorted files)
adir=$SINFODATARAW
##
## Define beginning of night
## set night begin = 14:00 UT (= 11:00 / 9:00 local time)
nightbegin=14
######## END OF DEFINITIONS ########

currentdir=`pwd`
cd $sdir

filelist=`(find . -name SINFO.\*.fits)`
for i in $filelist; do
	##
	## check if file is a MIDI FITS file
	instrument=`dfits $i | grep INSTRUME | awk -F \' '{print $2}' | awk -F " " '{print $1}'`
	if [ ! $instrument = "SINFONI" ]; then
		echo "File is not a SINFONI FITS file. INSTRUME = $instrument"
	else
		##
		## extract part of DATE-OBS between ''
		dateobs=`dfits $i | grep DATE-OBS | awk -F \' '{print $2}'`
		night=`whichnight_date.sh $dateobs`
		fdir=$adir/$night
		##
		## test if this directory structure exists, create it if it does not exist
		if [ ! -d "$fdir" ]; then
			mkdir -p $fdir
		fi
		##
		## get file name (without directory) to test if file exists
		filename=`echo $i | awk -F / '{print $NF}'`
		##
		## move raw file into appropriate directory
		## if directory exists and file does not exist
		if [ -d "$fdir" ]; then
			if [ -e "$fdir/$filename" ]; then
				echo "File $fdir/$filename exists. File not moved."
			else
				mv $i $fdir #for testing just comment out this line
				echo "Moved $i into $fdir"
			fi
		else
			echo "Error creating directory $fdir"
		fi
	fi
done

##
## after sorting files, rescue.sh will remove detector biases and move modified files
##    to $SINFODATA.
sh $SINFOTOOLS/rescue.sh

cd $currentdir