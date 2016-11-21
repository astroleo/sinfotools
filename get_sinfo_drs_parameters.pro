function get_sinfo_drs_parameters
	a=read_text('$SINFOTOOLS/parameters.txt')
	for i=0, n_elements(a[0,*])-1 do begin
		one={name:a[0,i], value:a[1,i]}
		if n_elements(params) eq 0 then params=one else params=[params,one]
	endfor
	return, params
end