#!/bin/bash

set -eu

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR, DBN_Libraries


# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${FSLDIR}" ]; then
	echo "$(basename ${0}): ABORTING: FSLDIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): FSLDIR: ${FSLDIR}"
fi

if [ -z "${DBN_Libraries}" ]; then
	echo "$(basename ${0}): ABORTING: DBN_Libraries environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): DBN_Libraries: ${DBN_Libraries}"
fi

################################################ SUPPORT FUNCTIONS ##################################################

. "${DBN_Libraries}/newopts.shlib" "$@"
. "${DBN_Libraries}/log.shlib" # Logging related functions

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: Predict brain age given a brain extracted, MNI registered T1w Image

Usage: $log_ToolName --data=<path to the data folder>
                     --subjects=<path to file with subject IDs>
                     --output=<path to outuput txt file>
                     [--b0=<scanner magnetic field intensity] default=3T
                     [--model=<path to the .h5 neural network model] default="${DBNDIR}/models/DBN_model.h5"

PARAMETERs are [ ] = optional; < > = user supplied value

Values default to running the example with sample data
"
    #automatic argument descriptions
    opts_ShowArguments
}

function main()
{
    opts_AddOptional '--workingDir' 'WD' 'Working Directory' "a required value; input T1w ACPC aligned image" "."
    opts_AddMandatory '--t1' 'T1w' 'Input T1w' "a required value; input T1w image"
    opts_AddMandatory '--t1ACPC' 'T1wACPC' 'Input T1w ACPC image' "a required value; input T1w ACPC aligned image"
    opts_AddMandatory '--t1ACPCBrain' 'T1wACPCBrain' 'Input T1w ACPC Brain' "a required value; input T1w ACPC aligned, brain extracted image"
    opts_AddMandatory '--t1w2ACPC' 'T1w2ACPC' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T1w orign space with the ACPC line"
    opts_AddMandatory '--t1w2T1w' 'T1w2T1w' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T1w orign space with the ACPC line"
    opts_AddOptional '--fullT1w2roi' 'fullT1w2roi' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T2w orign space with the ACPC line" ""
    opts_AddOptional '--t2' 'T2w' 'Input T2w' "a required value; input T2w image" ""
    opts_AddOptional '--t2ACPC' 'T2wACPC' 'Input T2w ACPC image' "a required value; input T2w ACPC aligned image" ""
    opts_AddOptional '--t2ACPCBrain' 'T2wACPCBrain' 'Input T2w ACPC Brain' "a required value; input T2w ACPC aligned, brain extracted image" ""
    opts_AddOptional '--t2w2ACPC' 'T2w2ACPC' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T2w orign space with the ACPC line" ""
    opts_AddOptional '--t2w2T1w' 'T2w2T1w' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T2w orign space with the ACPC line" ""
    opts_AddOptional '--fullT2w2roi' 'fullT2w2roi' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T2w orign space with the ACPC line" ""
    opts_AddMandatory '--ref' 'Reference' 'MNI T1w Template' "a required value; MNI T1w Template"
    opts_AddMandatory '--oWarpT1' 'origT1w2T1w' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T1w orign space with the ACPC line"
    opts_AddOptional '--oWarpT2' 'origT2w2T1w' 'Affine transform' "a required value; specifies the affine transform that should be applied to the data prior to the non-linear warping. Aligns the T2w orign space with the ACPC line" ""
    opts_AddMandatory '--oT1' 'OutputT1wImage' 'Resampled T1w ACPC aligned image' "a required value; T1w ACPC aligned image warped into the MNI space"
    opts_AddMandatory '--oT1Brain' 'OutputT1wImageBrain' 'Brain extracted resampled T1w ACPC aligned image' "a required value; brain extracted T1w ACPC aligned image warped into the MNI space"
    opts_AddOptional '--oT2' 'OutputT2wImage' 'Resampled T2w ACPC aligned image' "a required value; T2w ACPC aligned image warped into the MNI space" ""
    opts_AddOptional '--oT2Brain' 'OutputT2wImageBrain' 'Brain extracted resampled T2w ACPC aligned image' "a required value; brain extracted T2w ACPC aligned image warped into the MNI space" ""
    opts_ParseArguments "$@"

    #display the parsed/default values
    opts_ShowValues

    mkdir -p $WD

    # Record the input options in a log file
    echo "$0 $@" >> $WD/log.txt
    echo "PWD = `pwd`" >> $WD/log.txt
    echo "date: `date`" >> $WD/log.txt
    echo " " >> $WD/log.txt

    # ------------------------------------------------------------------------------
    # Create a One-Step Resampled Version of the T1w_acpc output
    # ------------------------------------------------------------------------------

    log_Msg "START: One-set resampled version of T1w_acpc output"

    #convertwarp --relout --rel --ref=${Reference} --premat=${PreMatT1} --warp1=${T1w2T1w} --out=${origT1w2T1w}
    convertwarp --relout --rel --ref=${Reference} --premat=${fullT1w2roi} --warp1=${T1w2T1w} --postmat=${T1w2ACPC} --out=${origT1w2T1w}
    applywarp --rel --interp=spline --in=${T1w} --ref=${Reference} --warp=${origT1w2T1w} --out=${OutputT1wImage}

    # Use -abs (rather than '-thr 0') to avoid introducing zeros
    fslmaths ${OutputT1wImage} -abs ${OutputT1wImage} -odt float
    # Apply mask to image
    fslmaths ${OutputT1wImage} -mas ${T1wACPCBrain} ${OutputT1wImageBrain}

    log_Msg "END: One-set resampled version of T1w_acpc output"

    # ------------------------------------------------------------------------------
    # Create a One-Step Resampled Version of the T2w_acpc output
    # ------------------------------------------------------------------------------

    if [ -n "${T2w}" ] ; then
        log_Msg "START: One-set resampled version of T2w_acpc output"

        #convertwarp --relout --rel --ref=${Reference} --premat=${PreMatT2} --warp1=${T2w2T1w} --out=${origT2w2T1w}
        convertwarp --relout --rel --ref=${Reference} --premat=${fullT2w2roi} --warp1=${T2w2T1w} --postmat=${T2w2ACPC} --out=${origT2w2T1w}
        #convertwarp --relout --rel --ref=${Reference} --postmat=${PreMatT1} --warp1=${T2w2T1w} --out=${origT2w2T1w}
        applywarp --rel --interp=spline --in=${T2w} --ref=${Reference} --warp=${origT2w2T1w} --out=${OutputT2wImage}

        # Use -abs (rather than '-thr 0') to avoid introducing zeros
        fslmaths ${OutputT2wImage} -abs ${OutputT2wImage} -odt float
        # Apply mask to image
        fslmaths ${OutputT2wImage} -mas ${T1wACPCBrain} ${OutputT2wImageBrain}

        log_Msg "END: One-set resampled version of T2w_acpc output"
    fi

    # ------------------------------------------------------------------------------
    # QA STUFF
    # ------------------------------------------------------------------------------
    echo " END: `date`" >> $WD/log.txt

    if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
    echo "cd `pwd`" >> $WD/qa.txt
    echo "# Check quality of alignment with MNI image" >> $WD/qa.txt
    echo "fsleyes ${Reference} ${OutputT1wImage}" >> $WD/qa.txt
    echo "fsleyes ${Reference} ${OutputT2wImage}" >> $WD/qa.txt
}

main "$@"
