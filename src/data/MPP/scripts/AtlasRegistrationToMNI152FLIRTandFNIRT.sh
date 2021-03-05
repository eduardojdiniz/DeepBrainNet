#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR, DBN_Libraries, MPP_Config, MNI_Templates

# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${DBN_Libraries}" ]; then
	echo "$(basename ${0}): ABORTING: DBN_Libraries environment variable must be set"
	exit 1
#else
#	echo "$(basename ${0}): DBN_Libraries: ${DBN_Libraries}"
fi

if [ -z "${MNI_Templates}" ]; then
	echo "$(basename ${0}): ABORTING: MNI_Templates environment variable must be set"
	exit 1
#else
#	echo "$(basename ${0}): MNI_Templates: ${MNI_Templates}"
fi

if [ -z "${MPP_Config}" ]; then
	echo "$(basename ${0}): ABORTING: MPP_Config environment variable must be set"
	exit 1
#else
#	echo "$(basename ${0}): MPP_Config: ${MPP_Config}"
fi

if [ -z "${FSLDIR}" ]; then
	echo "$(basename ${0}): ABORTING: FSLDIR environment variable must be set"
	exit 1
#else
#	echo "$(basename ${0}): FSLDIR: ${FSLDIR}"
fi

################################################ SUPPORT FUNCTIONS ##################################################

. ${DBN_Libraries}/log.shlib # Logging related functions
. ${DBN_Libraries}/opts.shlib # command line option functions

Usage() {
  echo "`basename $0`: Tool for non-linearly registering X and Y domain images to MNI space"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "                --x=<X domain image>"
  echo "                --xBrain=<brain extracted X domain image>"
  echo "                --ref=<reference image>"
  echo "                --refBrain=<reference brain image>"
  echo "                --refMask=<reference brain mask>"
  echo "                [--ref2mm=<reference 2mm image>]"
  echo "                [--ref2mmMask=<reference 2mm brain mask>]"
  echo "                --outWarp=<output warp>"
  echo "                --outInvWarp=<output inverse warp>"
  echo "                --outX=<output X domain image in MNI space>"
  echo "                --outXBrain=<output, brain extracted X domain image in MNI space>"
  echo "                [--FNIRTConfig=<FNIRT configuration file>]"
}


# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 9 ] ; then Usage; exit 1; fi

# parse arguments
WD=`opts_GetOpt1 "--workingDir" $@`  # "$1"
x=`opts_GetOpt1 "--x" $@`  # "$2"
xBrain=`opts_GetOpt1 "--xBrain" $@`  # "$3"
xBrainMask=`opts_GetOpt1 "--xBrainMask" $@`  # "$3"
y=`opts_GetOpt1 "--y" $@`  # "$2"
yBrain=`opts_GetOpt1 "--yBrain" $@`  # "$3"
yBrainMask=`opts_GetOpt1 "--yBrainMask" $@`  # "$3"
Reference=`opts_GetOpt1 "--ref" $@`  # "$4"
ReferenceBrain=`opts_GetOpt1 "--refBrain" $@`  # "$5"
ReferenceMask=`opts_GetOpt1 "--refMask" $@`  # "$6"
Reference2mm=`opts_GetOpt1 "--ref2mm" $@`  # "$7"
Reference2mmMask=`opts_GetOpt1 "--ref2mmMask" $@`  # "$8"
OutputTransform=`opts_GetOpt1 "--outWarp" $@`  # "$9"
OutputInvTransform=`opts_GetOpt1 "--outInvWarp" $@`  # "$10"
OutputXImage=`opts_GetOpt1 "--outX" $@`  # "$11"
OutputXImageBrain=`opts_GetOpt1 "--outXBrain" $@`  # "$12"
OutputXImageBrainMask=`opts_GetOpt1 "--outXBrainMask" $@`  # "$12"
OutputYImage=`opts_GetOpt1 "--outY" $@`  # "$11"
OutputYImageBrain=`opts_GetOpt1 "--outYBrain" $@`  # "$12"
OutputYImageBrainMask=`opts_GetOpt1 "--outYBrainMask" $@`  # "$12"
FNIRTConfig=`opts_GetOpt1 "--FNIRTConfig" $@`  # "$13"

# default parameters
WD=`opts_DefaultOpt $WD .`
Reference2mm=`opts_DefaultOpt $Reference2mm ${MNI_Templates}/MNI152_T1_2mm.nii.gz`
Reference2mmMask=`opts_DefaultOpt $Reference2mmMask ${MNI_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`
FNIRTConfig=`opts_DefaultOpt $FNIRTConfig ${MPP_Config}/T1_2_MNI152_2mm.cnf`

xBasename=`${FSLDIR}/bin/remove_ext $x`;
xBasename=`basename $xBasename`;
xBrainBasename=`${FSLDIR}/bin/remove_ext $xBrain`;
xBrainBasename=`basename $xBrainBasename`;

log_Msg "START: Nonlinear Atlas Registration to MNI152"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/xfms/log.txt
echo "PWD = `pwd`" >> $WD/xfms/log.txt
echo "date: `date`" >> $WD/xfms/log.txt
echo " " >> $WD/xfms/log.txt

# ------------------------------------------------------------------------------
# DO WORK
# ------------------------------------------------------------------------------

# Linear then non-linear registration to MNI
${FSLDIR}/bin/flirt -interp spline -dof 7 -in ${xBrain} -ref ${ReferenceBrain} -omat ${WD}/xfms/acpc2MNILinear.mat -out ${WD}/xfms/${xBrainBasename}_to_MNILinear
#${FSLDIR}/bin/flirt -interp spline -dof 12 -in ${xBrain} -ref ${ReferenceBrain} -omat ${WD}/xfms/acpc2MNILinear.mat -out ${WD}/xfms/${xBrainBasename}_to_MNILinear

${FSLDIR}/bin/fnirt --in=${x} --ref=${Reference2mm} --aff=${WD}/xfms/acpc2MNILinear.mat --refmask=${Reference2mmMask} --fout=${OutputTransform} --jout=${WD}/xfms/NonlinearRegJacobians.nii.gz --refout=${WD}/xfms/IntensityModulatedXImage.nii.gz --iout=${WD}/xfms/2mmReg.nii.gz --logout=${WD}/xfms/NonlinearReg.txt --intout=${WD}/xfms/NonlinearIntensities.nii.gz --cout=${WD}/xfms/NonlinearReg.nii.gz --config=${FNIRTConfig}

# Input and reference spaces are the same, using 2mm reference to save time
${FSLDIR}/bin/invwarp -w ${OutputTransform} -o ${OutputInvTransform} -r ${Reference2mm}

# X domain set of transformed outputs (brain/whole-head + orig)
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${x} -r ${Reference} -w ${OutputTransform} -o ${OutputXImage}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${xBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputXImageBrain}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${xBrainMask} -r ${Reference} -w ${OutputTransform} -o ${OutputXImageBrainMask}

${FSLDIR}/bin/fslmaths ${OutputXImageBrain} -abs ${OutputXImageBrain} -odt float
${FSLDIR}/bin/fslmaths ${OutputXImageBrainMask} -abs ${OutputXImageBrainMask} -odt float

${FSLDIR}/bin/fslmaths ${OutputXImage} -mas ${OutputXImageBrain} ${OutputXImageBrain}

# Y domain set of warped outputs(brain/whole-head + orig)
if [ -n "${y}" ] ; then

    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${y} -r ${Reference} -w ${OutputTransform} -o ${OutputYImage}
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${yBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputYImageBrain}
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${yBrainMask} -r ${Reference} -w ${OutputTransform} -o ${OutputYImageBrainMask}

    ${FSLDIR}/bin/fslmaths ${OutputYImageBrain} -abs ${OutputYImageBrain} -odt float
    ${FSLDIR}/bin/fslmaths ${OutputYImageBrainMask} -abs ${OutputYImageBrainMask} -odt float

    ${FSLDIR}/bin/fslmaths ${OutputYImage} -mas ${OutputYImageBrain} ${OutputYImageBrain}

fi


log_Msg "END: Nonlinear AtlasRegistration to MNI152"
echo " END: `date`" >> $WD/xfms/log.txt

# ------------------------------------------------------------------------------
# QA STUFF
# ------------------------------------------------------------------------------

if [ -e $WD/xfms/qa.txt ] ; then rm -f $WD/xfms/qa.txt ; fi
echo "cd `pwd`" >> $WD/xfms/qa.txt
echo "# Check quality of alignment with MNI image" >> $WD/xfms/qa.txt
echo "fsleyes ${Reference} ${OutputXImage}" >> $WD/xfms/qa.txt
echo "fsleyes ${Reference} ${OutputYImage}" >> $WD/xfms/qa.txt
