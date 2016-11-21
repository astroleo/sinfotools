##
## copy of this lives in parameters.txt in same directory

def get_NIR_parameters():
	NIR = {
		"H0": 1.15e-9,
		"K0": 4.14e-10,
		"H": [1.509,1.799],
		"K": [1.974,2.384],
		"twomass_k_lam": 2.159,
		"twomass_k_dlam": 0.262,
		"twomass_k0": 4.283e-10,
		"twomass_h_lam": 1.662,
		"twomass_h_dlam": 0.251,
		"twomass_h0": 1.133e-9,
		}
	return(NIR)