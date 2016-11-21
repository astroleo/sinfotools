;;
;; NOTE: assumes calibration of cube is in units 1d-17 [counts/(W/(m^2 um))]
;;
pro aperture_phot
	args=command_line_args()
	scicube_calib=args[0]
	outlist=args[1]
	if n_elements(args) eq 4 then begin
		usectr=[float(args[2]),float(args[3])]
	endif
	print, scicube_calib
	
	params=get_sinfo_drs_parameters()
	H0=params[where(params.name eq 'H0')].value ; H band zero point in W/(m^2 um)
	K0=params[where(params.name eq 'K0')].value ; K band zero point in W/(m^2 um)
	H=[params[where(params.name eq 'H_lower')].value,params[where(params.name eq 'H_upper')].value]
	K=[params[where(params.name eq 'K_lower')].value,params[where(params.name eq 'K_upper')].value]
	
	spectrum_obj_cal='/tmp/spectrum_obj_cal.fits'
	if n_elements(args) eq 2 then $
		spec = cube2spec(scicube_calib, spectrum_obj_cal, 10, wave=wave) $
	else if n_elements(args) eq 4 then $
		spec = cube2spec(scicube_calib, spectrum_obj_cal, 10, wave=wave, usectr=usectr) $
	else $
		stop
	spec_obj_cal = read_fits_wave(spectrum_obj_cal,naxis=1,hdr=hdr)
	
	dateobs=sxpar(hdr,"DATE-OBS")
	cmd='sqlite3 $OBSDB "select grat1 from sinfo where dateobs=\"'+dateobs+'\";"'
	spawn, cmd, grat1
	cmd='sqlite3 $OBSDB "select opti1 from sinfo where dateobs=\"'+dateobs+'\";"'
	spawn, cmd, opti1

	; take photometry in 0.5 arcsecond radius for the smallest scale
	; otherwise choose 1 arcsecond radius
	if opti1 eq '0.025' then radius=20 $
		else if opti1 eq '0.1' then radius=10 $
		else if opti1 eq '0.25' then radius=4
		
	if grat1 eq 'H+K' then begin
		inband_H=where(spec_obj_cal.w ge H[0] and spec_obj_cal.w le H[1])
		inband_K=where(spec_obj_cal.w ge K[0] and spec_obj_cal.w le K[1])
		cts_H = median(spec_obj_cal.f[inband_H])
		cts_K = median(spec_obj_cal.f[inband_K])
		Hmag_obj=2.5*alog10(H0/(1.d-17 * cts_H))
		Kmag_obj=2.5*alog10(K0/(1.d-17 * cts_K))
		print, 'Nuclear magnitude of target in H/K: ' + string(Hmag_obj, Kmag_obj)
		
	endif else if grat1 eq 'K' then begin
		inband_K=where(spec_obj_cal.w ge K[0] and spec_obj_cal.w le K[1])
		cts_K = median(spec_obj_cal.f[inband_K])
		Kmag_obj=2.5*alog10(K0/(1.d-17 * cts_K))
		print, 'Nuclear magnitude of target in K: ' + string(Kmag_obj)
	endif else stop
	spawn, "echo " + scicube_calib + " " + string(Kmag_obj) + " >> " + outlist
end