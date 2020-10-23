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
  echo "`basename $0`: Tool for linearly registering X and Y domain images to MNI space"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "                --x=<X domain image>"
  echo "                --xBrain=<brain extracted X domain image>"
  echo "                --ref=<reference image>"
  echo "                --refBrain=<reference brain image>"
  echo "                --refMask=<reference brain mask>"
  echo "                --outWarp=<output warp>"
  echo "                --outInvWarp=<output inverse warp>"
  echo "                --outX=<output X domain image in MNI space>"
  echo "                --outXBrain=<output, brain extracted X domain image in MNI space>"
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
ReferenceMask=`opts_GetOpt1 "--refMask" $@`  # "$6
OutputTransform=`opts_GetOpt1 "--outWarp" $@`  # "$9"
OutputInvTransform=`opts_GetOpt1 "--outInvWarp" $@`  # "$10"
OutputXImage=`opts_GetOpt1 "--outX" $@`  # "$11"
OutputXImageBrain=`opts_GetOpt1 "--outXBrain" $@`  # "$12"
OutputXImageBrainMask=`opts_GetOpt1 "--outXBrainMask" $@`  # "$12"
OutputYImage=`opts_GetOpt1 "--outY" $@`  # "$11"
OutputYImageBrain=`opts_GetOpt1 "--outYBrain" $@`  # "$12"
OutputYImageBrainMask=`opts_GetOpt1 "--outYBrainMask" $@`  # "$12"

# default parameters
WD=`opts_DefaultOpt $WD .`

log_Msg "START: Linear Atlas Registration to MNI152"

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
${FSLDIR}/bin/flirt -interp spline -dof 12 -in ${xBrain} -ref ${ReferenceBrain} -omat ${OutputTransform} -out ${OutputXImageBrain}
${FSLDIR}/bin/fslmaths "$OutputXImageBrain" -abs "$OutputXImageBrain" -odt float

# Invert affine transform
${FSLDIR}/bin/convert_xfm -omat ${OutputInvTransform} -inverse ${OutputTransform}

# X domain set of transformed outputs (brain/whole-head + orig)
${FSLDIR}/bin/flirt -in ${x} -ref ${Reference} -out ${OutputXImage} -init ${OutputTransform} -applyxfm
${FSLDIR}/bin/fslmaths "$OutputXImage" -abs "$OutputXImage" -odt float

${FSLDIR}/bin/flirt -in ${xBrainMask} -ref ${Reference} -out ${OutputXImageBrainMask} -init ${OutputTransform} -applyxfm
${FSLDIR}/bin/fslmaths "$OutputXImageBrainMask" -abs "$OutputXImageBrainMask" -odt float

# Y domain set of warped outputs(brain/whole-head + orig)
if [ -n "${Y}" ] ; then
    ${FSLDIR}/bin/flirt -in ${y} -ref ${Reference} -out ${OutputYImage} -init ${OutputTransform} -applyxfm
    ${FSLDIR}/bin/fslmaths "$OutputYImage" -abs "$OutputYImage" -odt float

    ${FSLDIR}/bin/flirt -in ${yBrain} -ref ${Reference} -out ${OutputYImageBrain} -init ${OutputTransform} -applyxfm
    ${FSLDIR}/bin/fslmaths "$OutputYImageBrain" -abs "$OutputYImageBrain" -odt float
    ${FSLDIR}/bin/flirt -in ${yBrainMask} -ref ${Reference} -out ${OutputYImageBrainMask} -init ${OutputTransform} -applyxfm
    ${FSLDIR}/bin/fslmaths "$OutputYImageBrainMask" -abs "$OutputYImageBrainMask" -odt float
fi

log_Msg "END: Linear AtlasRegistration to MNI152"
echo " END: `date`" >> $WD/xfms/log.txt

# ------------------------------------------------------------------------------
# QA STUFF
# ------------------------------------------------------------------------------

if [ -e $WD/xfms/qa.txt ] ; then rm -f $WD/xfms/qa.txt ; fi
echo "cd `pwd`" >> $WD/xfms/qa.txt
echo "# Check quality of alignment with MNI image" >> $WD/xfms/qa.txt
echo "fsleyes ${Reference} ${OutputXImage}" >> $WD/xfms/qa.txt
echo "fsleyes ${Reference} ${OutputYImage}" >> $WD/xfms/qa.txt
