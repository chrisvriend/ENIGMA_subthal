#!/bin/bash

#####
# change the path to FSL here:

FSLDIR="/opt/fsl-5.0.10"

#####


# usage instructions
Usage() {
    cat <<EOF

    (C) C.Vriend - 6/16/2020
    QA script using FSL (needs to be installed on your system) to check quality of the thalamic subsegmentation
    run as ./QA_thalseg.sh file.txt
    file.txt contains a one column list of the subject IDs in the output directory that need to be inspected
    run this script from within the output directory (= SUBJECTS_DIR)

    want to take a break?
    press ctrl+c in the terminal to terminate the script
    (don't forget to delete the lines of the subjects you already check in the text file)
EOF
    exit 1
}

[ _$1 = _ ] && Usage

file=$1

# source FSL
export ${FSLDIR}
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${FSLDIR}/bin:${PATH}
export FSLOUTPUTTYPE=NIFTI_GZ

# not all systems can run the newer fsleyes so we are using fslview here
# use fslview/fslview_deprecated
if [ -f ${FSLDIR}/bin/fslview_deprecated ]; then
fslview=${FSLDIR}/bin/fslview_deprecated
else
fslview=${FSLDIR}/bin/fslview
fi


for subj in `cat ${file}`; do

echo " preparing QA ..."
# split native thalamic segmentation from aseg.nii.gz
fslmaths ${subj}/mri/aseg.nii.gz -thr 2 -uthr 2 -bin ${subj}/mri/GML.nii.gz
fslmaths ${subj}/mri/aseg.nii.gz -thr 3 -uthr 3 -bin ${subj}/mri/WML.nii.gz
fslmaths ${subj}/mri/aseg.nii.gz -thr 41 -uthr 41 -bin ${subj}/mri/GMR.nii.gz
fslmaths ${subj}/mri/aseg.nii.gz -thr 42 -uthr 42 -bin ${subj}/mri/WMR.nii.gz
fslmaths ${subj}/mri/aseg.nii.gz -thr 10 -uthr 10 -bin ${subj}/mri/thalL.nii.gz
fslmaths ${subj}/mri/aseg.nii.gz -thr 49 -uthr 49 -bin ${subj}/mri/thalR.nii.gz
fslmaths ${subj}/mri/GML.nii.gz -add ${subj}/mri/GMR.nii.gz -mul 2 ${subj}/mri/GM.nii.gz
fslmaths ${subj}/mri/WML.nii.gz -add ${subj}/mri/WMR.nii.gz -mul 3 ${subj}/mri/WM.nii.gz
fslmaths ${subj}/mri/thalL.nii.gz -add ${subj}/mri/thalR.nii.gz -mul 10 ${subj}/mri/thal.nii.gz

fslmaths ${subj}/mri/GM.nii.gz \
-add ${subj}/mri/WM.nii.gz \
-add ${subj}/mri/thal.nii.gz \
${subj}/mri/asegthal
# clean up
rm ${subj}/mri/WM?.nii.gz \
${subj}/mri/GM?.nii.gz \
${subj}/mri/thal?.nii.gz \

# show in fslview
echo "opening fslview"
echo "when finished with the QA of this subject, close fslview to open the next "
echo
echo "want to take a break?"
echo "press ctrl+c in the terminal to terminate"
echo "(don't forget to delete the lines of the subjects you already check in the text file)"


${fslview} ${subj}/mri/brain.nii.gz \
${subj}/mri/asegthal.nii.gz -t 0.2 -l "MGH-Subcortical" \
${subj}/mri/ThalamicNuclei.v12.T1.FSvoxelSpace_noLMGN.nii.gz \
-l "MGH-Cortical"


done
