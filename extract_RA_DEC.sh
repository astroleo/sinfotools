#!/bin/bash
##
## micro script to extract RA/DEC from an ESO header
## takes as first and only argument the filename
##
if [ ! $# -eq 1 ]; then exit; fi
RA=`dfits $1 | grep "^RA  " | awk -F " " '{print $3}'`
DEC=`dfits $1 | grep "^DEC  " | awk -F " " '{print $3}'`
echo $RA $DEC