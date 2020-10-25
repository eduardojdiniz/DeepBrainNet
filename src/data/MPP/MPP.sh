#!/bin/bash
#
# # MPP.sh
#
# ## Description
#
# This script implements the Minimal Processng Pipeline (MPP) referred to in the
# README.md file
#
# The primary purposes of the MPP are:

# 1. To average any image repeats (i.e. multiple X domain or Y domain images available)
# 2. To perform bias correction
# 2. To provide an initial robust brain extraction
# 4. To register the subject's structural images to the MNI space
#
# ## Prerequisites:
#
# ### Installed Software
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
# * MATLAB
# * SPM12
#
# ### Environment Variables
#
# * MPPDIR
#
# * MPP_Scripts
#
#   Location of MPP sub-scripts that are used to carry out some of steps of the MPP.
#
# * FSLDIR
#
#   Home directory for [FSL][FSL] the FMRIB Software Library from Oxford
#   University
#
# * MATLABDIR
#
#   Home directory for MATLAB from
#
# * SPM12DIR
#
#   Home directory for SPM12 from
#
# ### Image Files
#
# At least one domain X image is required for this script to work.
#
# ### Output Directories
#
# Command line arguments are used to specify the studyName (--studyName) and
# the subject (--subject).  All outputs are generated within the tree rooted
# at ./tmp/${studyName}/${subject}.  The main output directories are:
#
# * The domainXFolder: ./tmp/${studyName}/${subject}/${class}/${domainX}
# * The domainYFolder: ./tmp/${studyName}/${subject}/${class}/${domainY}
# * The MNIFolder:     ./tmp/${studyName}/${subject}/${class}/MNI
#
# All outputs are generated in directories at or below these two main
# output directories.  The full list of output directories is:
#
# * ${domainX}/AverageDomainXImages
# * ${domainX}/BrainExtractionRegistration(Segmentation)Based
# * ${domainX}/xfms - transformation matrices and warp fields
#
# * ${domainY}/AverageDomainXImages
# * ${domainY}/BrainExtractionRegistration(Segmentation)Based
# * ${domainY}/xfms - transformation matrices and warp fields
#
# * ${MNIFolder}
# * ${MNIFolder}/xfms
#
# Note that no assumptions are made about the input paths with respect to the
# output directories. All specification of input files is done via command
# line arguments specified when this script is invoked.
#
# Also note that the following output directory is created:
#
# * xFolder, which is created by concatenating the following four option
#   values: --studyName / --subject / --class / --x
#
# * yFolder, which is created by concatenating the following four option
#   values: --studyName / --subject / --class / --y
#
# ### Output Files
#
# * domainXFolder Contents: TODO
# * domainYFolder Contents: TODO
# * MNIFolder Contents: TODO
#
# <!-- References -->
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# Setup this script such that if any command exits with a non-zero value, the
# script itself exits and does not attempt any further processing. Also, treat
# unset variables as an error when substituting.
set -eu

# ------------------------------------------------------------------------------
#  Load Function Libraries
# ------------------------------------------------------------------------------

. ${DBN_Libraries}/log.shlib  # Logging related functions
. ${DBN_Libraries}/opts.shlib # Command line option functions
. ${DBN_Libraries}/newopts.shlib # new Command line option functions

# ------------------------------------------------------------------------------
#  Show and Verify required environment variables are set
# ------------------------------------------------------------------------------

echo -e "\nEnvironment Variables"

log_Check_Env_Var DBNDIR
log_Check_Env_Var DBN_Libraries
log_Check_Env_Var MPPDIR
log_Check_Env_Var MPP_Scripts
log_Check_Env_Var FSLDIR
log_Check_Env_Var MATLABDIR
log_Check_Env_Var SPM12DIR

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------
function usage()
{
    echo "
    $log_ToolName: Perform Minimal Processing Pipeline (MPP)

Usage: $log_ToolName
                    --studyName=<studyName>           Name of study
                                                      Used with --subject input to create path to
                                                      directory for all outputs generated as
                                                      ./tmp/studyName/subject
                    --subject=<subject>               Subject ID
                                                      Used with --studyName input to create path to
                                                      directory for all outputs generated as
                                                      ./tmp/studyName/subject
                    [--b0=<b0>=<3T|7T>]               Magniture of the B0 field
                    [--class=<3T|7T|T1w_MPR|T2w_SPC>]   Name of the class
                    [--domainX=<3T|7T|T1w_MPR|T2w_SPC>] Name of the domain X
                    [--domainY=<3T|7T|T1w_MPR|T2w_SPC>] Name of the domain Y
                    --x=<T1w images>                  An @ symbol separated list of full paths to
                                                      domain X structural images for
                                                      the subject
                    [--y=<T2w images>]                An @ symbol separated list of full paths to
                                                      domain X structural images for
                                                      the subject
                    --xTemplate=<file path>           MNI X domain image template
                    --xTemplateBrain=<file path>      Brain extracted MNI X domain template
                    --xTemplate2mm=<file path>        X domain MNI 2mm template
                    [--yTemplate=<file path>]         MNI Y domain template
                    [--yTemplateBrain=<file path>]    Brain extracted MNI Y domain template
                    [--yTemplate2mm=<file path>]      Y domain MNI 2mm Template
                    --templateMask=<file path>        Brain mask MNI Template
                    --template2mmMask=<file path>     Brain mask MNI 2mm Template
                    [--custombrain=<NONE|MASK|CUSTOM>] If you have created a custom brain mask saved as
                                                       '<subject>/<domainX>/custom_bc_brain_mask.nii.gz', specify 'MASK'.
                                                       If you have created custom structural images, e.g.:
                                                       - '<subject>/<domainX>/<domainX>_bc.nii.gz'
                                                       - '<subject>/<domainX>/<domainX>_bc_brain.nii.gz'
                                                       - '<subject>/<domainX>/<domainY>_bc.nii.gz'
                                                       - '<subject>/<domainX>/<domainY>_bc_brain.nii.gz'
                                                       to be used when peforming MNI152 Atlas registration, specify
                                                       'CUSTOM'. When 'MASK' or 'CUSTOM' is specified, only the
                                                        AtlasRegistration step is run.
                                                        If the parameter is omitted or set to NONE (the default),
                                                        standard image processing will take place.
                                                        NOTE: This option allows manual correction of brain images
                                                        in cases when they were not successfully processed and/or
                                                        masked by the regular use of the pipelines.
                                                        Before using this option, first ensure that the pipeline
                                                        arguments used were correct and that templates are a good
                                                        match to the data.
                    [--brainSize=<int>]                Brain size estimate in mm, default 150 for humans
                    [--windowSize=<int>]               window size for bias correction, default 30.
                    [--brainExtractionMethod=<RPP|SPP>] Registration (Segmentation) based brain extraction
                    [--MNIRegistrationMethod=<nonlinear|linear>] Do (not) use FNIRT for image registration to MNI
                    [--printcom=command]              if 'echo' specified, will only perform a dry run.
                    [--FNIRTConfig=<file path>]       FNIRT 2mm T1w Configuration file

                    PARAMETERs are [ ] = optional; < > = user supplied value

                    Values default to running the example with sample data
"
    opts_ShowArguments
}

input_parser() {
    opts_AddMandatory '--studyName' 'studyName' 'Study Name' "a required value; the study name"
    opts_AddMandatory '--subject' 'subject' 'Subject ID' "a required value; the subject ID"
    opts_AddOptional  '--class' 'class' 'Class Name' "an optional value; is the name of the class. Default: 3T. Supported: 3T | 7T | T1w_MPR | T2w_SPC" "3T"
    opts_AddOptional  '--domainX' 'domainX' 'Domain X' "an optional value; is the name of the domain X. Default: T1w_MPR. Supported: 3T | 7T | T1w_MPR | T2w_SPC" "T1w_MPR"
    opts_AddOptional  '--domainY' 'domainY' 'Domain Y' "an optional value; is the name of the domain Y. Default: T2w_SPC. Supported: 3T | 7T | T1w_MPR | T2w_SPC" "T2w_SPC"
    opts_AddOptional '--b0' 'b0' 'Magnetic Field Strength' "an optinal value; the magnetic field strength. Default: 3T. Supported: 3T|7T." "3T"
    opts_AddMandatory '--x' 'xInputImages' 'Domain X Input Images' "a required value; a string with the paths to the subjects X domain images delimited by the symbol @"
    opts_AddOptional '--y' 'yInputImages' 'Domain Y Input Images' "an optional value; a string with the paths to the subjects Y domain images delimited by the symbol @. Default: NONE" "NONE"
    opts_AddMandatory '--xTemplate' 'xTemplate' 'MNI X Domain Template' "a required value; the MNI X domain image reference template"
    opts_AddMandatory '--xTemplateBrain' 'xTemplateBrain' 'MNI X Domain Brain Template' "a required value; the MNI X domain image brain extracted reference template"
    opts_AddMandatory '--xTemplate2mm' 'xTemplate2mm' 'MNI X Domain 2mm Template' "a required value; the low-resolution 2mm MNI X Domain image reference template"
#TODO: change yTemplate to be truly optional
    opts_AddMandatory '--yTemplate' 'yTemplate' 'MNI Y Domain Template' "an optional value; the MNI Y domain image reference template"
#TODO: change yTemplateBrain to be truly optional
    opts_AddMandatory '--yTemplateBrain' 'yTemplateBrain' 'MNI Y Domain Brain Template' "an optional value; the MNI Y domain image brain extracted reference template"
#TODO: change yTemplate2mm to be truly optional
    opts_AddMandatory '--yTemplate2mm' 'yTemplate2mm' 'MNI Y Domain 2mm Template' "an optional value; the low-resolution 2mm MNI Y domain image reference template"
    opts_AddMandatory '--templateMask' 'TemplateMask' 'Template Mask' "a required value; the MNI Template Brain Mask"
    opts_AddMandatory '--template2mmMask' 'Template2mmMask' 'Template 2mm Mask' "a required value; the MNI 2mm Template Brain Mask"
    opts_AddOptional '--customBrain'  'customBrain' 'If custom mask or structural images provided' "an optional value; If you have created a custom brain mask saved as <subject>/<domainX>/custom_brain_mask.nii.gz, specify MASK. If you have created custom structural images, e.g.: '<subject>/<domainX>/<domainX>_bc.nii.gz - '<subject>/<domainX>/<domainX>_bc_brain.nii.gz - '<subject>/<domainY>/<domainY>_bc.nii.gz - '<subject>/<domainY>/<domainY>_bc_brain.nii.gz' to be used when peforming MNI152 Atlas registration, specify CUSTOM. When MASK or CUSTOM is specified, only the AtlasRegistration step is run. If the parameter is omitted or set to NONE (the default), standard image processing will take place. NOTE: This option allows manual correction of brain images in cases when they were not successfully processed and/or masked by the regular use of the pipelines. Before using this option, first ensure that the pipeline arguments used were correct and that templates are a good match to the data. Default: NONE. Supported: NONE | MASK| CUSTOM." "NONE"
    opts_AddOptional '--brainSize' 'brainSize' 'Brain Size' "an optional value; the average brain size in mm. Default: 150." "150"
    opts_AddOptional '--windowSize' 'windowSize' 'Window Size for Bias Correction' "an optional value; the window size for bias correction. Default: 30" "30"
    opts_AddOptional '--brainExtractionMethod' 'brainExtractionMethod' 'Brain Registration Method' "an optional value; the method used to perform brain extraction. Default: RPP. Supported: RPP|SPP" "RPP"
    opts_AddOptional '--MNIRegistrationMethod' 'MNIRegistrationMethod' 'MNI Registration Method' "an optional value; the method used to perform registration to MNI space. Default: linear. Supported: linear|nonlinear" "linear"
#TODO: change FNIRTConfig to be truly optional
    opts_AddOptional '--printcom' 'RUN' 'Run command' "an optional value; if the scripts invoked by this script will run or be just printed. Default: ''. Supported: ''|echo" ""
    opts_AddMandatory '--FNIRTConfig' 'FNIRTConfig' 'FNIRT Configuration' "an optional value, only required if MNI Registration method is nonlinear; the FNIRT FSL configuration file"

    opts_ParseArguments "$@"

}

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Platform Information Follows: "
uname -a

echo -e "\nParsing Command Line Opts"
input_parser "$@"

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------
opts_ShowValues

# Naming Conventions for directories
xImage="${domainX}"
xFolder="${domainX}" #Location of domain X images
yImage="${domainY}"
yFolder="${domainY}" #Location of domain Y images
MNIFolder="MNI"

# ------------------------------------------------------------------------------
#  Build Paths and Unpack List of Images
# ------------------------------------------------------------------------------
xFolder=./${studyName}/preprocessed/${brainExtractionMethod}/${MNIRegistrationMethod}/${subject}/${class}/${xFolder}
yFolder=./${studyName}/preprocessed/${brainExtractionMethod}/${MNIRegistrationMethod}/${subject}/${class}/${yFolder}
MNIFolder=./${studyName}/preprocessed/${brainExtractionMethod}/${MNIRegistrationMethod}/${subject}/${class}/${MNIFolder}

log_Msg "xFolder: $xFolder"
log_Msg "yFolder: $yFolder"

# Unpack List of Images
xInputImages=`echo ${xInputImages} | sed 's/@/ /g'`
yInputImages=`echo ${yInputImages} | sed 's/@/ /g'`

if [ ! -e ${xFolder}/xfms ] ; then
	log_Msg "mkdir -p ${xFolder}/xfms/"
	mkdir -p ${xFolder}/xfms/
fi

if [[ ! -e ${yFolder}/xfms ]] && [[ -n ${yInputImages} ]] ; then
    log_Msg "mkdir -p ${yFolder}/xfms/"
    mkdir -p ${yFolder}/xfms/
fi

# ------------------------------------------------------------------------------
# We skip all the way to AtlasRegistration (last step) if using a custom brain
# mask or custom structural images ($customImage={MASK|CUSTOM})
# ------------------------------------------------------------------------------

if [ "$customBrain" = "NONE" ] ; then

# ------------------------------------------------------------------------------
#  Do primary work
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Loop over the processing for X domain and Y domain images (just with different names)
#  For each domain, perform
#  - Average same modality images (if more than one is available)
#  - Perform Brain Extraction (FNIRT-based or Segmentation-based Masking)
# ------------------------------------------------------------------------------

    Domains="${xImage} ${yImage}"

    for domain in ${Domains} ; do
        # Set up appropriate input variables
        if [ $domain = $xImage ] ; then
            domainInputImages="${xInputImages}"
            domainFolder="${xFolder}"
            domainImages="${xImage}"
            domainTemplate="${xTemplate}"
            domainTemplateBrain="${xTemplateBrain}"
            domainTemplate2mm="${xTemplate2mm}"
        else
            domainInputImages="${yInputImages}"
            domainFolder="${yFolder}"
            domainImages="${yImage}"
            domainTemplate="${yTemplate}"
            domainTemplateBrain="${yTemplateBrain}"
            domainTemplate2mm="${yTemplate2mm}"
        fi
        outputDomainImagesString=""

        # Skip modality if no image
        if [ -z "${domainInputImages}" ] ; then
            echo ''
            log_Msg "Skipping Modality: $domain - image not specified"
            echo ''
            continue
        else
            echo ''
            log_Msg "Processing Modality: $domain"
        fi

        i=1
        for image in $domainInputImages ; do
            # reorient image to match the orientation of MNI152
            ${RUN} ${FSLDIR}/bin/fslreorient2std $image ${domainFolder}/${domainImages}${i}

            # ------------------------------------------------------------------------------
            # Bias Correction
            # ------------------------------------------------------------------------------
            # bc stands for bias corrected

            echo -e "\n...Performing Bias Correction"
            log_Msg "mkdir -p ${domainFolder}/BiasCorrection"
            mkdir -p ${domainFolder}/BiasCorrection
            ${RUN} ${MPP_Scripts}/BiasCorrection.sh \
                --workingDir=${domainFolder}/BiasCorrection \
                --inputImage=${domainFolder}/${domainImages}${i} \
                --windowSize=${windowSize} \
                --outputImage=${domainFolder}/${domainImages}_bc${i}

            # always add the message/parameters specified
            outputDomainImagesString="${outputDomainImagesString}${domainFolder}/${domainImages}_bc${i}@"
            i=$(($i+1))
        done

        # ------------------------------------------------------------------------------
        # Average Like (Same Modality) Scans
        # ------------------------------------------------------------------------------

        echo -e "\n...Averaging ${domain} Scans"
        if [ `echo $domainInputImages | wc -w` -gt 1 ] ; then
            log_Msg "Averaging ${domain} Images, performing simple averaging"
            log_Msg "mkdir -p ${domainFolder}/Average${domain}Images"
            mkdir -p ${domainFolder}/Average${domain}Images
            ${RUN} ${MPP_Scripts}/AnatomicalAverage.sh \
                --workingDir=${domainFolder}/Average${domain}Images \
                --imageList=${outputDomainImagesString} \
                --ref=${domainTemplate} \
                --refMask=${TemplateMask} \
                --brainSize=${brainSize} \
                --out=${domainFolder}/${domainImages}_bc \
                --crop=no \
                --clean=no \
                --verbose=yes
        else
            log_Msg "Only one image found, not averaging ${domainX} images, just copying"
            ${RUN} ${FSLDIR}/bin/imcp ${domainFolder}/${domainImages}_bc1 ${domainFolder}/${domainImages}_bc
        fi

        if [ "$brainExtractionMethod" = "RPP" ] ; then

            # ------------------------------------------------------------------------------
            # Brain Extraction (FNIRT-based Masking)
            # ------------------------------------------------------------------------------

            echo -e "\n...Performing Brain Extraction using FNIRT-based Masking"
            log_Msg "mkdir -p ${domainFolder}/BrainExtractionRegistrationBased"
            mkdir -p ${domainFolder}/BrainExtractionRegistrationBased
            ${RUN} ${MPP_Scripts}/BrainExtractionRegistrationBased.sh \
                --workingDir=${domainFolder}/BrainExtractionRegistrationBased \
                --in=${domainFolder}/${domainImages}_bc \
                --ref=${domainTemplate} \
                --refMask=${TemplateMask} \
                --ref2mm=${domainTemplate2mm} \
                --ref2mmMask=${Template2mmMask} \
                --outImage=${domainFolder}/${domainImages}_bc \
                --outBrain=${domainFolder}/${domainImages}_bc_brain \
                --outBrainMask=${domainFolder}/${domainImages}_bc_brain_mask \
                --FNIRTConfig=${FNIRTConfig}

        else

            # ------------------------------------------------------------------------------
            # Brain Extraction (Segmentation-based Masking)
            # ------------------------------------------------------------------------------

            echo -e "\n...Performing Brain Extraction using Segmentation-based Masking"
            log_Msg "mkdir -p ${domainFolder}/BrainExtractionSegmentationBased"
            mkdir -p ${domainFolder}/BrainExtractionSegmentationBased
            ${RUN} ${MPP_Scripts}/BrainExtractionSegmentationBased.sh \
                --workingDir=${domainFolder}/BrainExtractionSegmentationBased \
                --segmentationDir=${yFolder}/BiasCorrection \
                --in=${domainFolder}/${domainImages}_bc \
                --outImage=${domainFolder}/${domainImages}_bc \
                --outBrain=${domainFolder}/${domainImages}_bc_brain \
                --outBrainMask=${domainFolder}/${domainImages}_bc_brain_mask
        fi

    done
    # End of looping over domains (X and Y domains)

    # ------------------------------------------------------------------------------
    # Y to X Registration
    # ------------------------------------------------------------------------------

    echo -e "\n...Performing ${domainY} to ${domainX} Registration"
    if [ -z "${yInputImages}" ] ; then
        log_Msg "Skipping ${domainY} to ${domainX} registration --- no ${domainY} image."

    else

        workingDir=${yFolder}/${domainY}To${domainX}Reg
        if [ -e ${workingDir} ] ; then
            rm -r ${yFolder}/${domainY}To${domainX}Reg
        fi

        log_Msg "mdir -p ${workingDir}"
        mkdir -p ${workingDir}

        ${RUN} ${MPP_Scripts}/YToXReg.sh \
            ${workingDir} \
            ${xFolder}/${xImage}_bc \
            ${xFolder}/${xImage}_bc_brain \
            ${yFolder}/${yImage}_bc \
            ${yFolder}/${yImage}_bc_brain \
            ${yFolder}/${yImage}_bc_brain_mask \
            ${xFolder}/${xImage}_bc \
            ${xFolder}/${xImage}_bc_brain \
            ${xFolder}/xfms/${xImage} \
            ${xFolder}/${yImage}_bc \
            ${xFolder}/${yImage}_bc_brain \
            ${xFolder}/${yImage}_bc_brain_mask \
            ${xFolder}/xfms/${yImage}_bc_reg
    fi

# ------------------------------------------------------------------------------
# Using custom mask
# ------------------------------------------------------------------------------

elif [ "$customBrain" = "MASK" ] ; then

    echo -e "\n...Custom Mask provided, skipping all the steps to Atlas registration, applying custom mask."
    OutputxImage=${xFolder}/${xImage}_bc
    ${FSLDIR}/bin/fslmaths ${OutputxImage} -mas ${xFolder}/${xImage}_bc_brain_mask ${OutputxImage}_brain

    if [ -n "${yInputImages}" ] ; then

        OutputyImage=${xFolder}/${yImage}_bc
        ${FSLDIR}/bin/fslmaths ${OutputyImage} -mas ${xFolder}/${yImage}_bc_brain_mask ${OutputyImage}_brain
    fi


# Using custom structural images
# ------------------------------------------------------------------------------

else

    echo -e "\n...Custom structural images provided, skipping all the steps to Atlas registration, using existing images instead."

fi

# ------------------------------------------------------------------------------
#  Registration to MNI152
#  Performs either FLIRT or FLIRT + FNIRT depending on the value of MNIRegistrationMethod
# ------------------------------------------------------------------------------

log_Msg "MNIFolder: $MNIFolder"
if [ ! -e ${MNIFolder}/xfms ] ; then
    log_Msg "mkdir -p ${MNIFolder}/xfms/"
    mkdir -p ${MNIFolder}/xfms/
fi

if [ $MNIRegistrationMethod = linear ] ; then

    # ------------------------------------------------------------------------------
    #  Linear Registration to MNI152: FLIRT
    # ------------------------------------------------------------------------------

    echo -e "\n...Performing Linear Atlas Registration to MNI152 (FLIRT)"
    registrationScript=AtlasRegistrationToMNI152FLIRT.sh

else

    # ------------------------------------------------------------------------------
    #  Nonlinear Registration to MNI152: FLIRT + FNIRT
    # ------------------------------------------------------------------------------

    echo -e "\n...Performing Nonlinear Registration to MNI152 (FLIRT and FNIRT)"
    registrationScript=AtlasRegistrationToMNI152FLIRTandFNIRT.sh
fi


if [ -z "${yInputImages}" ] ; then

    ${RUN} ${MPP_Scripts}/${registrationScript} \
        --workingDir=${MNIFolder} \
        --x=${xFolder}/${xImage}_bc \
        --xBrain=${xFolder}/${xImage}_bc_brain \
        --xBrainMask=${xFolder}/${xImage}_bc_brain_mask \
        --ref=${xTemplate} \
        --refBrain=${xTemplateBrain} \
        --refMask=${TemplateMask} \
        --outWarp=${MNIFolder}/xfms/acpc2standard.nii.gz \
        --outInvWarp=${MNIFolder}/xfms/standard2acpc.nii.gz \
        --outX=${MNIFolder}/${xImage} \
        --outXBrain=${MNIFolder}/${xImage}_brain \
        --outXBrainMask=${MNIFolder}/${xImage}_brain_mask

else

    ${RUN} ${MPP_Scripts}/${registrationScript} \
        --workingDir=${MNIFolder} \
        --x=${xFolder}/${xImage}_bc \
        --xBrain=${xFolder}/${xImage}_bc_brain \
        --xBrainMask=${xFolder}/${xImage}_bc_brain_mask \
        --y=${xFolder}/${yImage}_bc \
        --yBrain=${xFolder}/${yImage}_bc_brain \
        --yBrainMask=${xFolder}/${yImage}_bc_brain_mask \
        --ref=${xTemplate} \
        --refBrain=${xTemplateBrain} \
        --refMask=${TemplateMask} \
        --outWarp=${MNIFolder}/xfms/acpc2standard.nii.gz \
        --outInvWarp=${MNIFolder}/xfms/standard2acpc.nii.gz \
        --outX=${MNIFolder}/${xImage} \
        --outXBrain=${MNIFolder}/${xImage}_brain \
        --outXBrainMask=${MNIFolder}/${xImage}_brain_mask \
        --outY=${MNIFolder}/${yImage} \
        --outYBrain=${MNIFolder}/${yImage}_brain \
        --outYBrainMask=${MNIFolder}/${yImage}_brain_mask
fi

# ------------------------------------------------------------------------------
#  Processing Pipeline Completed!
# ------------------------------------------------------------------------------
echo -e "\n${brainExtractionMethod} ${MNIRegistrationMethod} completed!"
