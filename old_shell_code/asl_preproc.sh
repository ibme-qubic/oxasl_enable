#!/bin/bash

# ASL_PREPROC: Preprocessing of ASL images tog et data into correct form for Oxford_ASL and BASIL
#
# Michael Chappell & Brad MacIntosh, FMRIB Image Analysis & Physics Groups
#
# Copyright (c) 2008 University of Oxford
#
#   Part of FSL - FMRIB's Software Library
#   http://www.fmrib.ox.ac.uk/fsl
#   fsl@fmrib.ox.ac.uk
#   
#   Developed at FMRIB (Oxford Centre for Functional Magnetic Resonance
#   Imaging of the Brain), Department of Clinical Neurology, Oxford
#   University, Oxford, UK
#   
#   
#   LICENCE
#   
#   FMRIB Software Library, Release 4.0 (c) 2007, The University of
#   Oxford (the "Software")
#   
#   The Software remains the property of the University of Oxford ("the
#   University").
#   
#   The Software is distributed "AS IS" under this Licence solely for
#   non-commercial use in the hope that it will be useful, but in order
#   that the University as a charitable foundation protects its assets for
#   the benefit of its educational and research purposes, the University
#   makes clear that no condition is made or to be implied, nor is any
#   warranty given or to be implied, as to the accuracy of the Software,
#   or that it will be suitable for any particular purpose or for use
#   under any specific conditions. Furthermore, the University disclaims
#   all responsibility for the use which is made of the Software. It
#   further disclaims any liability for the outcomes arising from using
#   the Software.
#   
#   The Licensee agrees to indemnify the University and hold the
#   University harmless from and against any and all claims, damages and
#   liabilities asserted by third parties (including claims for
#   negligence) which arise directly or indirectly from the use of the
#   Software or the sale of any products based on the Software.
#   
#   No part of the Software may be reproduced, modified, transmitted or
#   transferred in any form or by any means, electronic or mechanical,
#   without the express permission of the University. The permission of
#   the University is not required if the said reproduction, modification,
#   transmission or transference is done without financial return, the
#   conditions of this Licence are imposed upon the receiver of the
#   product, and all original and amended source code is included in any
#   transmitted product. You may be held legally responsible for any
#   copyright infringement that is caused or encouraged by your failure to
#   abide by these terms and conditions.
#   
#   You are not permitted under this Licence to use this Software
#   commercially. Use for which any financial return is received shall be
#   defined as commercial use, and includes (1) integration of all or part
#   of the source code or the Software into a product for sale or license
#   by or on behalf of Licensee to third parties or (2) use of the
#   Software or any derivative of it for research with the final aim of
#   developing software products for sale or license to a third party or
#   (3) use of the Software or any derivative of it for research with the
#   final aim of developing non-software products for sale or license to a
#   third party, or (4) use of the Software to provide any service to an
#   external organisation for which payment is received. If you are
#   interested in using the Software commercially, please contact Isis
#   Innovation Limited ("Isis"), the technology transfer company of the
#   University, to negotiate a licence. Contact details are:
#   innovation@isis.ox.ac.uk quoting reference DE/1112.

Usage() {
    echo "ASL_PREPROC"
    echo "Version: 0.9 (beta - oxford)"
    echo "Assembles Multi-TI ASL images into correct form for Oxford_ASL and BASIL"
    echo ""
    echo "Usage (optional parameters in {}):"
    echo " -i         : name of (stacked) ASL data file"
    echo " --nrp      : number of repeats in data"
    echo " --nti      : number of TIs in data"
    echo " {-o}       : specify output name - {default: ./asldata}"
    echo " Extended options (all optional):"
    echo " -s         : spatailly smooth data"
    echo "  --fwhm    : FWHM for spatial filter kernel - {default: 6mm}"
    echo " -m         : motion correct data"
    echo ""
}

# Usage for --old option
# -i         : root name of ASL data files, e.g. images_%_echo_GRASE_ASL.nii.gz
#                                             % indicates the location of the file index number
# -f         : index for first ASL file
# calibration:
# --ci        : root name of M0 calibration images, e.g. images_%_echo_GRASE_calib.nii.gz"
#                                                    % indicates the location of the file index number
# --cf        : index of first calibration file

#    echo " Pre-proc calibration usage (optional, can be run independently):"
#    echo " --ci       : name of (stacked) ASL calibration file"
#    echo " --cn       : number of calibration files"
#    echo " --{co}     : calibration output name - {default: ./aslcalib}"
#    echo ""

# deal with options

if [ -z $1 ]; then
    Usage
    exit 1
fi

perfusion_subtract=${FSLDIR}/bin/perfusion_subtract

until [ -z $1 ]; do
    case $1 in
     -o) outflag=1 outname=$2
         shift;;
     -i) inflag=1 infile=$2 #input/data file
         shift;;
         -f) asl1=$2
         shift;;
     --nrp) nrpts=$2
         shift;;
     --nti) ntis=$2
         shift;;
     -s) ssflag=1
         ;;
     -m) mcflag=1
         ;;
     --fwhm) fwhmflag=1 fwhm=$2
         shift;;
     --debug) debug=1
         ;;
     --ci) calibflag=1 calfile=$2
         shift;;
         --cf) cal1=$2
         shift;;
     --cn) caln=$2
         shift;;
     --co) outcalib=1 calibname=$2
         shift;;
     --old) old=1 # old behaviour for dicom2nifti output
         ;;
     *)  Usage
         echo "Error! Unrecognised option on command line: $1"
         echo ""
         exit 1;;
    esac
    shift
done

echo "ASL_PREPROC"

oldpwd=`pwd`


tmpbase=`$FSLDIR/bin/tmpnam`
if [ -z $debug ]; then
    tempdir=${tmpbase}_asl_pre
else
    tempdir=./tmp_asl_preproc #make local temp directory and do not delete at end
fi
mkdir $tempdir

if [ ! -z $inflag ]; then
echo "Dealing with multi-TI ASL data"

if [ -z $outflag ]; then
    outname=asldata
fi

npairs=`echo "$ntis * $nrpts"|bc` #the number of TC pairs total

echo "Working on data $infile"
echo "Number of TIs             : $ntis"
echo "Number of repeats         : $nrpts"
echo "Total number of TC pairs  : $npairs"


if [ -z $fwhmflag ]; then
    #use default FWHM
    fwhm=6
fi


if [ -z $old ]; then
#copy input fiel into temp dir
    imcp $infile $tempdir/stacked_asaq
else
# we need to revert to 'old' bahviour - data is from dicom2nifti
    echo ""
    echo "Collecting files"

nfiles=`echo "$ntis * $nrpts * 2"|bc`
echo "Total number of files     : $nfiles"

#ASL files
    aslend=`expr $asl1 + $nfiles - 1` #the last asl file index
    echo "`echo $infile | sed 's:%:'$asl1':'` ... `echo $infile | sed 's:%:'$aslend':'`"
#assemble list of ASL files
    aslf=$asl1
# check that first file exists
    file=`echo $infile | sed 's:%:'$aslf':'`
    fileext=`imglob -extension $file`
    if [ -z $fileext ]; then
     echo "Error: cannot find first file: $file"
     exit
    fi

    skipfile=0
    while [ $aslf -le $aslend ]; do
    #echo $aslf
     file=`echo $infile | sed 's:%:'$aslf':'`
     fileext=`imglob -extension $file`
     if [ -z $fileext ]; then
         echo "Warning: File $file does not exist - skipping this file"
         aslend=`expr $aslend + 1` #if there is a missing index then we probably need to count on further to get all the files
         skipfile=`expr $skipfile + 1`
     else
         filelist=`echo "$filelist $file"`
     fi
     aslf=`expr $aslf + 1`
     
     if [ $skipfile -gt 5 ]; then
     # get out if skipping files would take us into an infinite loop
         echo "ERROR! Unable to find enough files - giving up"
         exit
     fi
    done

#echo $filelist
# now mrege the files into one
    fslmerge -t $tempdir/stacked_asaq `echo $filelist`
fi

if [ ! -z $mcflag ]; then
    echo "Warning: Motion correction is untested - check your results carefuly!"
    mcflirt -in $tempdir/stacked_asaq -out $tempdir/stacked_asaq -cost mutualinfo
fi 

#split file
fslsplit $tempdir/stacked_asaq $tempdir/asl_

echo ""
echo "Assembling data for each TI and differencing"

tistart=0
#assemble files for each TI
for (( ti=1; ti <= ntis ; ti++ )); do
    filelist=""
    #assemble list
    n=1
    m=$tistart
    while [ $n -le $nrpts ]; do
     newfile=`ls $tempdir/asl_000$m.nii.gz $tempdir/asl_00$m.nii.gz $tempdir/asl_0$m.nii.gz 2>/dev/null`
     m=`expr $ntis + $m`
     n=`expr $n + 1`
     filelist=`echo "$filelist $newfile"`
    done
    tistart=`expr $tistart + 1` #advance tistart to the file where  the next TI begins (not TC)
    #merge this TI
    echo $filelist
    fslmerge -t $tempdir/stacked_$ti `echo $filelist`
    # do TC differencing on this TI
    #$perfusion_subtract $tempdir/stacked_$ti $tempdir/stacked_$ti -m

    # take the mean across the repeats
    fslmaths $tempdir/stacked_$ti -Tmean $tempdir/mean_$ti
    
    tistacklist=`echo "$tistacklist $tempdir/stacked_$ti"` #list of the TI block files
    timeanlist=`echo "$timeanlist $tempdir/mean_$ti"` #list of the mean TI files
done

echo ""
echo "Assembling stacked data file"
#merge the TI blocks into a single stacked file
fslmerge -t $outname $tistacklist
#echo $tistacklist
fslmerge -t ${outname}_mean $timeanlist

if [ ! -z $ssflag ]; then
# do spatial smoothing
    echo "Performing spatial smoothing with FWHM: $fwhm"
    sigma=`echo "scale=2; $fwhm/2.355"|bc`
    echo $sigma
    fslmaths $outname -kernel gauss $sigma -fmean ${outname}_smooth
    fslmaths ${outname}_mean -kernel gauss $sigma -fmean ${outname}_smooth_mean
fi

echo "ASL data file is: $outname"
echo "ASL mean data file is: ${outname}_mean"
if [ ! -z $ssflag ]; then
    echo "Smoothed ASL data file is: $outname_smooth"
    echo "Smoothed ASL mean data file is: ${outname}_smooth_mean"
fi
echo ""

fi # end of multi-TI ASL data

#Option to assemble calibration image - this is old and only retained for compatibility with dicom2nifti.m
if [ ! -z $calibflag ]; then
#deal with calibration images
if [ -z $outcalib ]; then
    calibname=aslcalib
fi

    echo "Assembling calibration image"
    calend=`expr $cal1 + $caln - 1` #the last asl file index
    echo "`echo $calfile | sed 's:%:'$cal1':'` ... `echo $calfile | sed 's:%:'$calend':'`"
    filelist=""
#assemble list of ASL files
    calf=$cal1
    while [ $calf -le $calend ]; do
    #echo $aslf
     file=`echo $calfile | sed 's:%:'$calf':'`
     filelist=`echo "$filelist $file"`
     calf=`expr $calf + 1`
    done

# now merge the files into one
    fslmerge -t $calibname `echo $filelist`

echo "ASL calibration file is: $calibname"
echo ""
fi


if [ -z $debug ]; then
    rm -r $tempdir
fi

echo "DONE."
