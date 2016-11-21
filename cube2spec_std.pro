pro cube2spec_std
	args=command_line_args()
	cube_std_atmo=args[0]
	spectrum_std_atmo=args[1]

	spec = cube2spec(cube_std_atmo, spectrum_std_atmo, 10)
end