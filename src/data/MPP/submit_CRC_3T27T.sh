#!/bin/bash

. /ihome/crc/install/python/miniconda3-3.7/etc/profile.d/conda.sh
conda activate MPP

module purge # Make sure the modules environment is sane
module load gcc/5.4.0
module load fsl/5.0.11-centos
module load matlab/R2019b

field=$1

./runMPP_CRC.sh --studyFolder=/bgfs/tibrahim/edd32/data/3T27T --subjects=/bgfs/tibrahim/edd32/data/3T27T/raw/subject_list_${field}T.txt --partition=smp --brainExtractionMethod=SPP --MNIRegistrationMethod=linear --class="${field}T" --domainX=T1w_MPR --domainY=T2w_SPC
