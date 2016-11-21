##
## to be executed in each directory where one would like to create spectrum_HHMMSS_a_total.fits files
## STD cube must have been reduced and corresponding atmosphere file must exist
## if STD cube has not been divided by atmosphere this script will do it,
##    then extract the spectrum in standard aperture and save spectrum

source $HOME/spred/use_spred

stdcubes=`ls cube_??????_crop_x.fits`

for cube_std_in in $stdcubes; do
	HHMMSS=`echo $cube_std_in | awk -F "_" '{print $2}'`
	spectrum_std_atmo="spectrum_${HHMMSS}_a_total.fits"
	cube_std_out="cube_${HHMMSS}_crop_x_a.fits"
	atmofile="atmosphere_${HHMMSS}.fits"

	if [ ! -f $spectrum_std_atmo ]; then
		if [ ! -f $atmofile ]; then
			echo "atmosphere file $atmofile is missing. Continuing..."
			continue
		fi

		if [ ! -f $cube_std_out ]; then
			echo "$cube_std_out is missing; trying to produce it..."
			spredDivCubeBySpec.py $cube_std_in $atmofile $cube_std_out
			if [ -f $cube_std_out ]; then
				echo "seems to have worked..."
			fi
		fi

		echo "$spectrum_std_atmo is missing; trying to produce it..."
		idl -e cube2spec_std -args "$cube_std_out" "$spectrum_std_atmo"
		if [ -f $spectrum_std_atmo ]; then
			echo "seems to have worked..."
		fi
	fi
done