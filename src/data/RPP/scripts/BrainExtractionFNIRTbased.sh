#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR, MNI_Templates, DBN_Libraries, and RPP_Config


# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${FSLDIR}" ]; then
	echo "$(basename ${0}): ABORTING: FSLDIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): FSLDIR: ${FSLDIR}"
fi

if [ -z "${MNI_Templates}" ]; then
	echo "$(basename ${0}): ABORTING: MNI_Templates environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): MNI_Templates: ${MNI_Templates}"
fi

if [ -z "${RPP_Config}" ]; then
	echo "$(basename ${0}): ABORTING: RPP_Config environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): RPP_Config: ${RPP_Config}"
fi

if [ -z "${DBN_Libraries}" ]; then
	echo "$(basename ${0}): ABORTING: DBN_Libraries environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): DBN_Libraries: ${MNI_Templates}"
fi

################################################ SUPPORT FUNCTIONS ##################################################

. ${DBN_Libraries}/log.shlib # Logging related functions

Usage() {
  echo "$(basename $0): Tool for performing brain extraction using non-linear (FNIRT) results"
  echo " "
  echo "Usage: $(basename $0) [--workingDir=<working dir>] --in=<input image> [--ref=<reference highres image>] [--refMask=<reference brain mask>] [--ref2mm=<reference image 2mm>] [--ref2mmMask=<reference brain mask 2mm>] --outBrain=<output brain extracted image> --outBrainMask=<output brain mask> [--FNIRTConfig=<fnirt config file>]"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# All except variables starting with $Output are saved in the Working Directory:
#     roughlin.mat "$BaseName"_to_MNI_roughlin.nii.gz   (flirt outputs)
#     NonlinearRegJacobians.nii.gz IntensityModulatedT1.nii.gz NonlinearReg.txt NonlinearIntensities.nii.gz
#     NonlinearReg.nii.gz (the coefficient version of the warpfield)
#     str2standard.nii.gz standard2str.nii.gz   (both warpfields in field format)
#     "$BaseName"_to_MNI_nonlin.nii.gz   (spline interpolated output)
#    "$OutputBrainMask" "$OutputBrainExtractedImage"

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 4 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingDir" $@`  # "$1"
Input=`getopt1 "--in" $@`  # "$2"
Reference=`getopt1 "--ref" $@` # "$3"
ReferenceMask=`getopt1 "--refMask" $@` # "$4"
Reference2mm=`getopt1 "--ref2mm" $@` # "$5"
Reference2mmMask=`getopt1 "--ref2mmMask" $@` # "$6"
OutputBrainExtractedImage=`getopt1 "--outBrain" $@` # "$7"
OutputBrainMask=`getopt1 "--outBrainMask" $@` # "$8"
FNIRTConfig=`getopt1 "--FNIRTConfig" $@` # "$9"

# default parameters
WD=`defaultopt $WD .`
Reference=`defaultopt $Reference ${MNI_Templates}/MNI152_T1_0.7mm.nii.gz`
ReferenceMask=`defaultopt $ReferenceMask ${MNI_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz`  # dilate to be conservative with final brain mask
Reference2mm=`defaultopt $Reference2mm ${MNI_Templates}/MNI152_T1_2mm.nii.gz`
Reference2mmMask=`defaultopt $Reference2mmMask ${MNI_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`  # dilate to be conservative with final brain mask
FNIRTConfig=`defaultopt $FNIRTConfig ${RPP_Config}/T1_2_MNI152_2mm.cnf`

BaseName=`${FSLDIR}/bin/remove_ext $Input`;
BaseName=`basename $BaseName`;

log_Msg "START: BrainExtraction_FNIRT"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################


# Register to 2mm reference image (linear then non-linear)
${FSLDIR}/bin/flirt -interp spline -dof 12 -in "$Input" -ref "$Reference2mm" -omat "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -nosearch
${FSLDIR}/bin/fnirt --in="$Input" --ref="$Reference2mm" --aff="$WD"/roughlin.mat --refmask="$Reference2mmMask" --fout="$WD"/str2standard.nii.gz --jout="$WD"/NonlinearRegJacobians.nii.gz --refout="$WD"/IntensityModulatedT1.nii.gz --iout="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz --logout="$WD"/NonlinearReg.txt --intout="$WD"/NonlinearIntensities.nii.gz --cout="$WD"/NonlinearReg.nii.gz --config="$FNIRTConfig"

# Overwrite the image output from FNIRT with a spline interpolated highres version
${FSLDIR}/bin/applywarp --rel --interp=spline --in="$Input" --ref="$Reference" -w "$WD"/str2standard.nii.gz --out="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz

# Invert warp and transform dilated brain mask back into native space, and use it to mask input image
# Input and reference spaces are the same, using 2mm reference to save time
${FSLDIR}/bin/invwarp --ref="$Reference2mm" -w "$WD"/str2standard.nii.gz -o "$WD"/standard2str.nii.gz
${FSLDIR}/bin/applywarp --rel --interp=nn --in="$ReferenceMask" --ref="$Input" -w "$WD"/standard2str.nii.gz -o "$OutputBrainMask"
${FSLDIR}/bin/fslmaths "$Input" -mas "$OutputBrainMask" "$OutputBrainExtractedImage"

log_Msg "END: BrainExtraction_FNIRT"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following brain mask does not exclude any brain tissue (and is reasonably good at not including non-brain tissue outside of the immediately surrounding CSF)" >> $WD/qa.txt
echo "fsleyes $Input $OutputBrainMask --cmap red --alpha 50" >> $WD/qa.txt
echo "# Optional debugging: linear and non-linear registration result" >> $WD/qa.txt
echo "fsleyes $Reference2mm $WD/${BaseName}_to_MNI_roughlin.nii.gz" >> $WD/qa.txt
echo "fsleyes $Reference $WD/${BaseName}_to_MNI_nonlin.nii.gz" >> $WD/qa.txt

##############################################################################################
