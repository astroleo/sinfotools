# SINFOTOOLS
This set of scripts allows you to reduce large quantities of VLT/SINFONI data semi-automatically. It has been used by L. Burtscher for reducing a sample of about 50 local AGNs mostly from the ESO archive (Burtscher et al. 2015,2016) and not been tested or used by anyone else yet.

# Dependencies
The scripts require access to a couple of external routines, i.e.
* the OBSDB database of observations (see http://github.com/astroleo/esodb)
* the MPE (Garching) data reduction package `spred` (this is only available by request)
* lac3d for cosmic ray suppression, originally by Pieter G. van Dokkum, adapted for 3D data cubes by Ric Davies, MPE 
* skysub for skyline suppression, by Ric Davies, MPE 
* optionally: starfit, e.g. for determining stellar kinematics and disentangling the stellar and non-stellar flux in AGNs. This is also by Ric Davies, MPE 

# Installation
Prior to usage, a couple of environment variables need to be set, i.e.
* SINFODATAINCOMING -- the directory to which new SINFONI data will be downloaded
* SINFODATARAW -- after download, the raw data will be sorted according to observing data in this directory
* SINFODATA -- and after sorting, the raw data will be "rescued" (see this script for details), i.e. detector artefacts removed from the raw data
* SINFOREDDIR -- directory where the reduced data is kept
* SINFOTOOLS -- the directory where these scripts are
* SINFOLOCAL -- a directory where reduced and calibrated cubes and large calibration files are kept locally
* SINFOLOG -- a file into which log messages are dumped

Finally, you may want to add $SINFOTOOLS to your $PATH and make the shell scripts executable.

For further instructions, see the inline comments in the main script `sinfo_reduce.sh`.

# Feedback
Please direct your comments, questions and other feedback to Leonard Burtscher burtscher@strw.leidenuniv.nl.
