#!/bin/bash


# usage instructions
Usage() {
    cat <<EOF

    (C) C.Vriend - 6/16/2020
    script to automatically create ENIGMA thalamic subsegmentation compatible input folder according to BIDS format
    run ./makeBIDS.sh file.txt
    where file.txt is a text file with two columns:
    column 1 contains the subject IDs according to sub-[ID], e.g. sub-426001
    column 2 contains the name of the T1w image file of that particular subject, e.g. T1_426001.nii.gz
    each row represents a subject

EOF
    exit 1
}

[ _$1 = _ ] && Usage




file=${1}

while read subj T1 ; do
echo ${subj}

if [[ ${subj:0:4} != "sub-" ]]; then
echo "subject IDs need to start with 'sub-' "
echo "please change the text file accordingly"
exit
fi

# make subject directory
mkdir -p ${subj}
mkdir -p ${subj}/anat

if [[ ${T1} == *.nii ]]; then
ext=nii
elif [[ ${T1} == *.nii.gz ]]; then
ext=nii.gz

elif [[ ${T1} == *.img ]]; then
ext=img
elif [[ ${T1} == *.img.gz ]]; then
ext=img.gz

else
echo "cannot recogize extension of files"
echo "valid options are .nii, .nii.gz, .img, .img.gz"
echo "with a preference for nii.gz"
echo "reformat your scans and try again"
echo " exiting script ..."
exit
fi

cp ${T1} ${subj}/anat/${subj}_T1w.${ext}

done < ${file}
echo "DONE"


# determine base of scan
#base=$(echo "${T1}" | sed 's/\.hdr\.gz$//' | sed 's/\.img\.gz$//' | sed 's/\.hdr$//' | sed 's/\.img$//' | sed 's/\.nii.gz$//' | sed 's/\.nii$//' | sed 's/\.mnc.gz$//' | sed 's/\.mnc$//' | sed 's/\.$//')
