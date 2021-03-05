#!/bin/bash

. /ihome/crc/install/python/miniconda3-3.7/etc/profile.d/conda.sh
conda activate MPP

module purge # Make sure the modules environment is sane
module load gcc/5.4.0
module load fsl/5.0.11-centos
module load matlab/R2019b

list_number=$1

 ./runMPP_CRC.sh --studyFolder=/bgfs/tibrahim/edd32/data/RFLab --subjects=/bgfs/tibrahim/edd32/data/RFLab/MPR_Preprocess_IDs_${list_number}.txt --partition=smp --brainExtractionMethod=SPP --MNIRegistrationMethod=linear --class=7T --domainX=T1w_MPR --domainY=T2w_SPC
