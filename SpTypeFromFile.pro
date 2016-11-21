pro SpTypeFromFile, specfile, sptype, T_eff=T_eff, name=name
	; get co-ordinates of star from FITS header
	spawn, 'sh $SINFOTOOLS/extract_RA_DEC.sh ' + specfile, RADEC
	RADEC1=strsplit(RADEC,' ',/extract)
	RA=float(RADEC1[0])
	DEC=float(RADEC1[1])
	;
	; search for star close to these co-ordinates in database
	rr = 10./3600 ;; search diameter in degrees
	sqlstring=string(RA-rr, RA+rr, DEC-rr, DEC+rr, format='("select SpType, name from std where ra between ", f12.6, " and ", f12.6, " and dec between ", f12.6, " and ", f12.6)')
	spawn, 'sqlite3 $OBSDB ' + '"' + sqlstring + '"', sqlresult
	
	name=''
	sptype='0'

	if n_elements(sqlresult) ne 1 then begin
		spawn, 'sinfolog "SpTypeFromFile: More than one result. Refine your search."'
	endif else if sqlresult eq '' then begin
		spawn, 'sinfolog "SpTypeFromFile: No star found near given co-ordinates."'
	endif else begin
		sqlresult=strsplit(sqlresult,'|',/extract)
		sptype=sqlresult[0]
		name=sqlresult[1]
		spawn, 'sinfolog "SpTypeFromFile: Found a star of spectral type ' + sptype + ' at given co-ordinates"'
	endelse
	
	spawn, "TeffFromSpType_simple.sh " + sptype, T_eff
	T_eff=fix(T_eff)
end