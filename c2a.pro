@$SINFOTOOLS/cube2spec
@$SINFOTOOLS/get_atmo
;;
;; take all standard star cubes of a night, extract the spectrum in the central few pixels, divide through star's spectrum, to get atmospheric profile
;;
;; USAGES
;;    call c2a in the 'standard' sub-directory of the night directory
;;
pro c2a
	spawn, "ls | egrep '^cube_[0-9]{6}_crop_x\.fits$'", cubelist
	for i=0, n_elements(cubelist)-1 do begin
		outfile='spectrum_'+strmid(cubelist[i],5,6)+'.fits'
		atmooutfile='atmosphere_'+strmid(cubelist[i],5,6)+'.fits'
		spawn, 'sinfolog "Attempting to produce ' + atmooutfile +'"'
		if file_test(outfile) and file_test(atmooutfile) then continue
		
		;; extract spectrum in small aperture for maximum SNR
		spec = cube2spec(cubelist[i], outfile, 5, /smooth)
		get_atmo, outfile, atmooutfile
	endfor
end