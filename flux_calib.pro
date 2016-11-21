@$SINFOTOOLS/get_atmo
;;
;; given a certain H and K band magnitude, return conversion factors
;;
;; INPUT values
;;
;; Hmag, Kmag -- magnitudes of star
;; cube_std_atmo -- cube of standard star with atmospheric transmission spectrum removed
;; spectrum_std_atmo -- spectrum extracted from cube of standard star with atmospheric transmission removed
;; scifile -- optional: apply the average conversion factor to science file, taking exposure time into account
;;
;; USAGE (from bash command line)
;;    idl -e flux_calib -args "
;;
;pro flux_calib, Hmag, Kmag, cube_std_atmo, spectrum_std_atmo, scifile=scifile
pro flux_calib
	args=command_line_args()
	Hmag=float(args[0])
	Kmag=float(args[1])
	cube_std_atmo=args[2]
	spectrum_std_atmo=args[3]
	scifile=args[4]
	outfile=args[5]
	
	;;
	;; extract spectrum from cube_std_atmo in large aperture to include all flux
	spec = cube2spec(cube_std_atmo, spectrum_std_atmo, 10, wave=wave)
	stdspec = read_fits_wave(spectrum_std_atmo,naxis=1,hdr=hdr)
	
	dateobs=sxpar(hdr,"DATE-OBS")
	cmd='sqlite3 $OBSDB "select grat1 from sinfo where dateobs=\"'+dateobs+'\";"'
	spawn, cmd, grat1

	spawn, 'dfits ' + cube_std_atmo + " | grep EXPTIME | awk -F ' ' '{ print $3 }'", exptime_cal
	exptime_cal = double(exptime_cal[0])

	params=get_sinfo_drs_parameters()
	H0=params[where(params.name eq 'H0')].value ; H band zero point in W/(m^2 um)
	K0=params[where(params.name eq 'K0')].value ; K band zero point in W/(m^2 um)
	H=[params[where(params.name eq 'H_lower')].value,params[where(params.name eq 'H_upper')].value]
	K=[params[where(params.name eq 'K_lower')].value,params[where(params.name eq 'K_upper')].value]

	twomass_k_lam=float(params[where(params.name eq 'twomass_k_lam')].value)
	twomass_k_dlam=float(params[where(params.name eq 'twomass_k_dlam')].value)
	twomass_k0=double(params[where(params.name eq 'twomass_k0')].value)

	twomass_h_lam=float(params[where(params.name eq 'twomass_h_lam')].value)
	twomass_h_dlam=float(params[where(params.name eq 'twomass_h_dlam')].value)
	twomass_h0=double(params[where(params.name eq 'twomass_h0')].value)

; should be using 2MASS wavelength, bandwidth and zeropoint, but it makes almost no difference, so I will stick to the standard K band for the time being.
;	H0=twomass_h0
;	K0=twomass_k0
;	H=[twomass_h_lam-twomass_h_dlam/2,twomass_h_lam+twomass_h_dlam/2]
;	K=[twomass_k_lam-twomass_k_dlam/2,twomass_k_lam+twomass_k_dlam/2]

	; H/K flux in 1e-17 W/(m^2 um)
	Hflux = 1.e17 * H0 * 10^(-Hmag/2.5)
	Kflux = 1.e17 * K0 * 10^(-Kmag/2.5)
	

	if grat1 eq 'H+K' then begin
		inband_H=where(stdspec.w ge H[0] and stdspec.w le H[1])
		inband_K=where(stdspec.w ge K[0] and stdspec.w le K[1])
		cts_H = median(stdspec.f[inband_H])
		cts_K = median(stdspec.f[inband_K])
;		print, "standard cts_K:"
;		print, cts_K
	
		; conversion factor from counts/s to W/(m^2 um)
		CF_H = Hflux * exptime_cal / cts_H
		CF_K = Kflux * exptime_cal / cts_K
		CF_avg = (CF_H+CF_K)/2.
		spawn, 'sinfolog "Conversion factors in H/K/avg: ' + string(CF_H, CF_K, CF_avg) + '"'
	endif else if grat1 eq 'K' then begin
		inband_K=where(stdspec.w ge K[0] and stdspec.w le K[1])
		cts_K = median(stdspec.f[inband_K])

		; conversion factor from counts/s to W/(m^2 um)
		CF_K = Kflux * exptime_cal / cts_K
		CF_avg = CF_K
		spawn, 'sinfolog "Conversion factor in K: ' + string(CF_K) + '"'
	endif else stop
	
	
	if keyword_set(scifile) then begin
		spawn, 'dfits ' + scifile + " | grep EXPTIME | awk -F ' ' '{ print $3 }'", exptime_sci
		exptime_sci = double(exptime_sci[0])
;		print, exptime_sci, format='("Exposure time SCIENCE is: ", f8.3, " s")'
		cube = readfits(scifile,hdr)
		CF_sci = CF_avg / exptime_sci
		spawn, 'sinfolog "' + string(CF_sci, format='("Multiplying cube by ", e10.4)') + '"'

		cube_cal = cube * CF_sci
		writefits, outfile, cube_cal, hdr
		spawn, 'sinfolog "Wrote ' + outfile + '"'
		
		;;
		;; extract flux from science cube and determine magnitude of nucleus
		spectrum_obj_cal='/tmp/spectrum_obj_cal.fits'
		spec = cube2spec(outfile, spectrum_obj_cal, 10, wave=wave)
		spec_obj_cal = read_fits_wave(spectrum_obj_cal,naxis=1,hdr=hdr)
		
		if grat1 eq 'H+K' then begin
			inband_H=where(spec_obj_cal.w ge H[0] and spec_obj_cal.w le H[1])
			inband_K=where(spec_obj_cal.w ge K[0] and spec_obj_cal.w le K[1])
			cts_H = median(spec_obj_cal.f[inband_H])
			cts_K = median(spec_obj_cal.f[inband_K])
			Hmag_obj=2.5*alog10(H0/(1.d-17 * cts_H))
			Kmag_obj=2.5*alog10(K0/(1.d-17 * cts_K))
			spawn, 'sinfolog "Nuclear magnitude of target in H/K: ' + string(Hmag_obj, Kmag_obj) + '"'
		endif else if grat1 eq 'K' then begin
			inband_K=where(spec_obj_cal.w ge K[0] and spec_obj_cal.w le K[1])
			cts_K = median(spec_obj_cal.f[inband_K])
			Kmag_obj=2.5*alog10(K0/(1.d-17 * cts_K))
			spawn, 'sinfolog "Nuclear magnitude of target in K: ' + string(Kmag_obj) + '"'
		endif else stop
	endif
end