#!/bin/bash
list_number=$1

 ./runMPP_CRC.sh --studyFolder=/bgfs/tibrahim/edd32/data/RFLab --subjects=/bgfs/tibrahim/edd32/data/RFLab/MPR_Preprocess_IDs_${list_number}.txt --partition=smp --brainExtractionMethod=SPP --MNIRegistrationMethod=linear --class=7T --domainX=T1w_MPR --domainY=T2w_SPC
