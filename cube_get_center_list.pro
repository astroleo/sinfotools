;;
;; PROCEDURE CUBE_GET_CENTER_LIST
;;
;; PURPOSE
;;    given a list of SINFONI cubes, determine their center position and write it to a file
;;    to be used for combining multiple cubes (using spredCombineCubesbySlice)
;;
;; USAGE
;;    e.g.: `idl -e cube_get_center_list -args "cubelist.txt"`
;;
pro cube_get_center_list
	arg=command_line_args()
	cubelist=arg[0]
	outfile=arg[1]
	
	a=read_text(cubelist)

	for i=0, n_elements(a)-1 do begin
		ctr=cube_get_center(a[i])
		outstring=string(a[i], ctr[0], ctr[1], format='(A46, "   ", f6.3, "   ", f6.3)')
		print, outstring
		spawn, 'echo "' + outstring + '" >> ' + outfile
	endfor
end