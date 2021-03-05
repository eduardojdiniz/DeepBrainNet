#!/bin/bash

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

Usage() {
	cat <<EOF

${script_name}: Script for registering Y domain images to X domain images

Usage: ${script_name}

Usage information To Be Written

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    Usage
    exit 1
fi


#################################### SUPPORT FUNCTIONS #####################################
if [ -z "${DBN_Libraries}" ]; then
	echo "$(basename ${0}): ABORTING: DBN_Libraries environment variable must be set"
	exit 1
fi

. ${DBN_Libraries}/log.shlib # Logging related functions
. ${DBN_Libraries}/opts.shlib # command line option functions

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var FSLDIR

########################################## DO WORK ##########################################


log_Msg "START: YToXReg"

WD="$1"
xImage="$2"
xImageBrain="$3"
xImageBrainMask="$4"
yImage="$5"
yImageBrain="$6"
yImageBrainMask="$7"
outputXImage="$8"
outputXImageBrain="$9"
outputXTransform="${10}"
outputYImage="${11}"
outputYImageBrain="${12}"
outputYImageBrainMask="${13}"
outputYTransform="${14}"
outputInvYTransform="${15}"

#xImageBrainFile=`basename "$xImageBrain"`
#
#${FSLDIR}/bin/imcp "$xImageBrain" "$WD"/"$xImageBrainFile"
#
#${FSLDIR}/bin/epi_reg --epi="$yImageBrain" --t1="$xImage" --t1brain="$WD"/"$xImageBrainFile" --out="$WD"/YToX
#${FSLDIR}/bin/applywarp --rel --interp=spline --in="$yImage" --ref="$xImage" --premat="$WD"/YToX.mat --out="$WD"/YToX
#${FSLDIR}/bin/fslmaths "$WD"/YToX -add 1 "$WD"/YToX -odt float
#
#${FSLDIR}/bin/applywarp --rel --interp=spline --in="$yImageBrain" --ref="$xImage" --premat="$WD"/YToX.mat --out="$WD"/YToXBrain
##${FSLDIR}/bin/fslmaths "$WD"/YToXBrain -add 1 "$WD"/YToXBrain -odt float
#
#${FSLDIR}/bin/applywarp --rel --interp=nn -i "$yImageBrainMask" -r "$xImage" --premat="$WD"/YToX.mat -o "$outputYImageBrainMask"
#
#${FSLDIR}/bin/imcp "$xImage" "$outputXImage"
#${FSLDIR}/bin/imcp "$xImageBrain" "$outputXImageBrain"
#
#${FSLDIR}/bin/fslmerge -t $outputXTransform "$xImage".nii.gz "$xImage".nii.gz "$xImage".nii.gz
#${FSLDIR}/bin/fslmaths $outputXTransform -mul 0 $outputXTransform
#
#${FSLDIR}/bin/imcp "$WD"/YToX "$outputYImage"
#${FSLDIR}/bin/fslmaths "$outputYImage" -abs "$outputYImage" -odt float
#${FSLDIR}/bin/imcp "$WD"/YToXBrain "$outputYImageBrain"
#${FSLDIR}/bin/fslmaths "$outputYImageBrain" -abs "$outputYImageBrain" -odt float
#
## outputYImage is actually in X space (is the co-registered X domain image); This warp does nothing to the input, it's an identity warp. So the final transformation is equivalent to postmat.
#${FSLDIR}/bin/convertwarp --relout --rel -r "$outputYImage".nii.gz -w $outputXTransform --postmat="$WD"/YToX.mat --out="$outputYTransform"

# Linear then non-linear registration to MNI
#${FSLDIR}/bin/flirt -interp spline -dof 12 -in ${yImage} -ref ${xImage} -omat ${outputYTransform} -out ${outputYImage}
# Scaling (3), translation (3) and linear scaling = 7
${FSLDIR}/bin/flirt -interp spline -dof 7 -in ${yImage} -ref ${xImage} -omat ${outputYTransform} -out ${outputYImage}
${FSLDIR}/bin/fslmaths "$outputYImage" -abs "$outputYImage" -odt float

# Invert affine transform
${FSLDIR}/bin/convert_xfm -omat ${outputInvYTransform} -inverse ${outputYTransform}

${FSLDIR}/bin/imcp "$xImage" "$outputXImage"
${FSLDIR}/bin/imcp "$xImageBrain" "$outputXImageBrain"

${FSLDIR}/bin/fslmerge -t $outputXTransform "$xImage".nii.gz "$xImage".nii.gz "$xImage".nii.gz
${FSLDIR}/bin/fslmaths $outputXTransform -mul 0 $outputXTransform

${FSLDIR}/bin/fslmaths ${outputYImage} -mas ${xImageBrain} ${outputYImageBrain}
${FSLDIR}/bin/imcp ${xImageBrainMask} ${outputYImageBrainMask}

log_Msg "END: YToXReg"
