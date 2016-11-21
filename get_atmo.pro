@$SINFOTOOLS/SpTypeFromFile

function B_lambda, T, lambda=lambda
	h = 6.6260755e-34
	c = 299792458.
	k_B = 1.3805e-23
	
	lambda_HK = 1.e-6 * (1.45 + (2.45-1.45) * dindgen(1000)/1000.)
	
	lambda = lambda_HK
	B_lambda = dindgen(n_elements(lambda))
	
	for i=0, n_elements(B_lambda)-1 do $
		B_lambda[i] = 2*h*c^2/lambda[i]^5 * (exp(h*c/(lambda[i]*k_B*T))-1)^(-1)

	return, B_lambda
end

;;
;; function MEDCTS
;;
;; PURPOSE
;;    get median count rate in band
;;
;; PARAMETERS
;;    w       wavelength scale
;;    f       flux (same dimension as w)
;;    grat1   grating (K or H+K)
;;
function medcts, w, f, grat1
	if n_elements(w) ne n_elements(f) then stop

	params=get_sinfo_drs_parameters()
	H=[params[where(params.name eq 'H_lower')].value,params[where(params.name eq 'H_upper')].value]
	K=[params[where(params.name eq 'K_lower')].value,params[where(params.name eq 'K_upper')].value]
	
	if grat1 eq 'H+K' then begin
		inbandH=where(w ge H[0] and w le H[1])
		inbandK=where(w ge K[0] and w le K[1])
		inband=[inbandH,inbandK]
	endif else if grat1 eq 'K' then $
		inband=where(w ge K[0] and w le K[1]) $
	else stop
	return, median(f[inband])
end

;;
;; get atmospheric profile from observation of a standard star of type G2V or F or earlier
;;
;; take extracted spectrum from standard star (e.g. result of cube2spec.dpuser),
;;    remove blackbody and divide by solar spectrum, normalize spectrum to 1.
;;    write FITS file
;;
pro get_atmo, specfile, outfile
	; get grating setting of specfile

	a=readfits(specfile,header)
	dateobs=sxpar(header,"DATE-OBS")
	cmd='sqlite3 $OBSDB "select grat1 from sinfo where dateobs=\"'+dateobs+'\";"'
	spawn, cmd, grat1

	; get spectral type of this star from database
	SpTypeFromFile, specfile, sptype, T_eff=T_eff
	print, specfile
	print, sptype
	print, T_eff
	
	if T_eff eq 0 then begin
		spawn, 'sinfolog "Standard star is of spectral type ' + sptype + '. I do not know how to reduce these data. :-("'
	endif else if sptype eq 'G2V' then begin
		; the solK1778.fits seems to be the standard solar spectrum used for K band data; no idea what the solK1700.fits is for, but it's very similar.
		if grat1 eq 'H+K' then solfile='$SINFOLOCAL/calibration/standard/solHK833.fits' $
			else if grat1 eq 'K' then solfile='$SINFOLOCAL/calibration/standard/solK1778.fits' $
				else stop
	
		solHK = read_fits_wave(solfile) ; lambda-dependent resolution (constant delta lam); convolved to correct resolution
		B_lambda = B_lambda(5800, lambda=lambda) ; solar type (G2)
	;	stdspec = read_fits_wave(specfile,naxis=2,hdr=hdr) ; spred-extracted spectrum of standard star
		stdspec = read_fits_wave(specfile,naxis=1,hdr=hdr) ; dpuser-extracted (FITS conform) spectrum of standard star
	
		;; interpolate solHK to stdspec
		solHK_i = interpol(solHK.f, solHK.w, stdspec.w)
	
		;; interpolate BB to stdspec
		B_lambda_i = interpol(B_lambda, lambda, 1.e-6*stdspec.w)
	
		atmosphere = stdspec.f/(B_lambda_i * solHK_i)
	endif else if strmid(sptype,0,1) eq 'O' or strmid(sptype,0,1) eq 'B' or strmid(sptype,0,1) eq 'A' or strmid(sptype,0,1) eq 'F' or strmid(sptype,0,1) eq 'G' or strmid(sptype,0,1) eq 'K' then begin
		if strmid(sptype,0,1) eq 'K' then spawn, 'sinfolog "WARNING: Standard star is of spectral type ' + sptype + '. May require manual correction of spectrum for absorption features!"'
		;; for spectral types F and earlier, simply assume star is blackbody in relevant spectral range
		stdspec = read_fits_wave(specfile,naxis=1,hdr=hdr) ; dpuser-extracted (FITS conform) spectrum of standard star
		B_lambda = B_lambda(T_eff, lambda=lambda) ; solar type (G2)

		;; interpolate BB to stdspec
		B_lambda_i = interpol(B_lambda, lambda, 1.e-6*stdspec.w)

		atmosphere = stdspec.f/B_lambda_i
	endif else spawn, 'sinfolog "Standard star is of spectral type ' + sptype + '. I do not know how to reduce these data. :-("'
	normalisation=medcts(stdspec.w,atmosphere,grat1)
	atmosphere_norm = atmosphere/normalisation
	plot, stdspec.w, atmosphere_norm	
	writefits, outfile, atmosphere_norm, hdr
end