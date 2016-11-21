##
## rescue_sort.sh
##
##    run rescue.dpuser for each new SINFONI file in $SINFODATAIN, then 
##    move original file to $SINFODATA_RAW, modified file to $SINFODATA
##
## what happens?
## (1) if the script has not been run before, there are only "*.fits" files in the dir. dpuser script will modify these files and rename original files to "*.fits_". This script will move the modified files that are now named "*.fits" to $SINFODATA.
## (2) If this script has been run before, there should be some "*.fits_" files in the directory so that the dpuser script will not be run again
## (3) If only the dpuser script has been run, but not this script, both "*.fits" files and "*.fits_" files are in the $SINFODATA-RAW/$night directory. Then the modified files need to be moved to $SINFODATA manually
##
##
##
## CHANGELOG
##
##    2015-04-27   Now removing unnecessary .xml files after download process
##    2015-03-10   changed gunzip *.Z to for loop to avoid sending too large file list to gunzip (which it can't handle)
##    2014-02-17   added check for number of files (gzip only works up to ca 200)
##    2013-07-22   now applied only on data in $SINFODATAIN
##    2013-01-16   created
##

set -e

## confirm, execute and remove ESO download scripts
downloaddir="$HOME/Downloads"
cd $downloaddir

esodlfile=`find * | egrep "^downloadRequest[0-9]{6}script.sh$"`
nfiles=`echo $esodlfile | wc -w`
if [ ! $nfiles == 1 ]; then
	echo "Found $nfiles ESO download files in $downloaddir."
	exit
fi

nfiles=$(cat $esodlfile | wc -l)

##if [[ $nfiles -gt 150 ]]; then
##	echo "More than 150 files to download. Better split this into several files."
##	exit
##fi

echo $esodlfile
cat $esodlfile

read -p "Execute (and then delete) this download file [y/n]?" -n 1
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit; fi

cd $SINFODATAIN

sh $downloaddir/$esodlfile
nfiles=$(find . -name "SINFO.*.txt" | wc -l)
if [[ ! $nfiles -eq 0 ]]; then
	rm $SINFODATAIN/SINFO.*.txt
fi

nfiles=$(find . -name "M.SINFONI.*.fits" | wc -l)
if [[ ! $nfiles -eq 0 ]]; then
	rm $SINFODATAIN/M.SINFONI.*.fits
fi

echo "Now unzipping files..."
for zipfile in `ls *.Z`; do gunzip $zipfile; done

echo "Now correcting files for detector biases..."
dpuser < $SINFOTOOLS/rescue.dpuser > /tmp/dpuser.log

echo "Now moving/copying files to correct places..."
for f in `ls *.fits`
do
	dateobs=`echo $f | awk -F "." '{print $2}'`
	night=`whichnight_date.sh $dateobs`
	f_orig="${f}_"
	f_mod=$f
	dir_orig=$SINFODATARAW/$night
	dir_mod=$SINFODATA/$night
	if [[ ! -d $dir_orig ]]; then mkdir $dir_orig; fi
	if [[ ! -d $dir_mod ]]; then mkdir $dir_mod; fi
	mv $f_orig $dir_orig
	mv $f_mod $dir_mod

	dpuserhistory="dpuser.history"
	if [ -e $dpuserhistory ]; then rm $dpuserhistory; fi
done

nfiles=$(find . -name "*.xml" | wc -l)
if [[ ! $nfiles -eq 0 ]]; then
	rm $SINFODATAIN/*.xml
fi

cd $downloaddir
if [[ -e $esodlfile ]]; then
	rm $esodlfile
	echo "removed ESO download file $downloaddir/$esodlfile"
else
	echo "could not remove esodlfile: $esodlfile."
fi