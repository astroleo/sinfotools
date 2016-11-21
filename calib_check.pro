@$SINFOTOOLS/cube2spec
pro calib_check
	args=command_line_args()
	cube_raw=args[0]
	cube_cal=args[1]
	
	raw=cube2spec(cube_raw, '/tmp/spec_raw.fits', 5)
	cal=cube2spec(cube_cal, '/tmp/spec_cal.fits', 5)
	
	factor=median(cal/raw)
	print, "This is the factor"
	print, factor
	spawn, "echo " + strtrim(cube_raw,2) + ': ' + strtrim(factor,2) + " >> /tmp/factors.txt"
end