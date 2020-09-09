#!/bin/bash

# this script


# progress bar function
prog() {
    local w=20 p=$1;  shift
    # create a string of spaces, then change them to dots
    printf -v dots "%*s" "$(( $p*$w/46 ))" ""; dots=${dots// /.};
    # print those dots on a fixed-width space plus the percentage etc.
    printf "\r\e[K|%-*s| %3d %s" "$w" "$dots" "$p" "$*";
}


# source directories
export USER="${USER:=`whoami`}"
export FREESURFER_HOME="/opt/freesurfer7"
source ${FREESURFER_HOME}/SetUpFreeSurfer.sh
export FSLDIR="/opt/fsl-5.0.10"
. ${FSLDIR}/etc/fslconf/fsl.sh
export PATH="/opt/fsl-5.0.10/bin:$PATH"
export FSLOUTPUTTYPE=NIFTI_GZ

# input variables
workdir=$1
subj=$2



mkdir -p ${workdir}/${subj}/QC

cd ${workdir}/${subj}/mri

# different versions of Thalamic subnuclei exists: v10 and v12.
vers=v12


if [ -f ThalamicNuclei.${vers}.T1.FSvoxelSpace.mgz ]; then

if [ ! -f brain.nii.gz ]; then
mri_convert --in_type mgz --out_type nii --out_orientation RAS brain.mgz brain.nii.gz
fi

if [ ! -f ThalamicNuclei.${vers}.T1.FSvoxelSpace.nii.gz ]; then
mri_convert --in_type mgz --out_type nii --out_orientation RAS ThalamicNuclei.${vers}.T1.FSvoxelSpace.mgz ThalamicNuclei.${vers}.T1.FSvoxelSpace.nii.gz
fi

if [ ! -f aseg.nii.gz ]; then
mri_convert --in_type mgz --out_type nii --out_orientation RAS aseg.mgz aseg.nii.gz
fi


fslreorient2std ThalamicNuclei.${vers}.T1.FSvoxelSpace.nii.gz ThalamicNuclei.${vers}.T1.FSvoxelSpace.nii.gz
fslreorient2std aseg.nii.gz aseg.nii.gz
fslreorient2std brain.nii.gz brain.nii.gz


# change datatype



rm -f ${workdir}/${subj}/QC/${subj}_missing_subnuclei.txt

echo " splitting subnuclei from thalamus segmentation"

i=0
for r in 8103 8104 8105 8106 8108 8110 8111 8112 8113 8116 8117 8118 8119 8120 8121 8122 8123 8126 8127 8128 8129 8130 8133 8203 8204 8205 8206 8208 8210 8211 8212 8213 8216 8217 8218 8219 8220 8221 8222 8223 8226 8227 8228 8229 8230 8233 ; do
i=$[$i+1]

printf " thalamic subnucleus:  %1d\r" ${i}

#prog ${i} \# nuclei processed

# define thresholds
lthresh=$(echo " ${r} - 0.8" | bc -l)
uthresh=$(echo " ${r} + 0.8" | bc -l)

#namenucl=$(cat /opt/freesurfer-7beta/FreeSurferColorLUT.txt | grep ${r} | awk '{ print $2}')
namenucl=$(cat ${FREESURFER_HOME}/FreeSurferColorLUT.txt | grep ${r} | awk '{ print $2}')


fslmaths ThalamicNuclei.${vers}.T1.FSvoxelSpace.nii.gz -thr ${lthresh} -uthr ${uthresh} -bin temp_${r}

unset lthresh uthresh

nvox=$(fslstats temp_${r} -V | awk '{ print $1 }' | bc -l)

if test ${nvox} -ne 0; then

# left hemisphere
if test ${r} -eq 8103; then
fslmaths temp_${r} -mul 1 temp_${r}

elif test ${r} -eq 8108 || test ${r} -eq 8110; then
fslmaths temp_${r} -mul 3 temp_${r}

elif test ${r} -eq 8126 || test ${r} -eq 8127 || test ${r} -eq 8128 || test ${r} -eq 8129 || test ${r} -eq 8133 || test ${r} -eq 8130; then
fslmaths temp_${r} -mul 5 temp_${r}

elif test ${r} -eq 8104 || test ${r} -eq 8105 || test ${r} -eq 8117 || test ${r} -eq 8106 || test ${r} -eq 8118 || test ${r} -eq 8119 || test ${r} -eq 8116 || test ${r} -eq 8113 || test ${r} -eq 8112  ; then
fslmaths temp_${r} -mul 7 temp_${r}

elif test ${r} -eq 8120 || test ${r} -eq 8121 || test ${r} -eq 8122 || test ${r} -eq 8123 ; then
fslmaths temp_${r} -mul 9 temp_${r}

# L supra gen
elif test ${r} -eq 8111; then
fslmaths temp_${r} -mul 11 temp_${r}

# right hemisphere
elif test ${r} -eq 8203; then
fslmaths temp_${r} -mul 2 temp_${r}

elif test ${r} -eq 8208 || test ${r} -eq 8210; then
fslmaths temp_${r} -mul 4 temp_${r}

elif test ${r} -eq 8226 || test ${r} -eq 8227 || test ${r} -eq 8228 || test ${r} -eq 8229 || test ${r} -eq 8233 || test ${r} -eq 8230; then
fslmaths temp_${r} -mul 6 temp_${r}

elif test ${r} -eq 8204 || test ${r} -eq 8205 || test ${r} -eq 8217 || test ${r} -eq 8206 || test ${r} -eq 8218 || test ${r} -eq 8219 || test ${r} -eq 8216 || test ${r} -eq 8213 || test ${r} -eq 8212  ; then
fslmaths temp_${r} -mul 8 temp_${r}

elif test ${r} -eq 8220 || test ${r} -eq 8221 || test ${r} -eq 8222 || test ${r} -eq 8223 ; then
fslmaths temp_${r} -mul 10 temp_${r}

# R supra gen
elif test ${r} -eq 8211; then
fslmaths temp_${r} -mul 12 temp_${r}

else
echo "intensity ${r} value not found"
exit
fi

else
echo " "
echo "thalamic subnucleus ${namenucl} ( ${r} ) too small to process"
echo "${subj} ${r} ${namenucl}" >> ${workdir}/${subj}/QC/${subj}_missing_subnuclei.txt

fi

done


# recombine subnuclei

# create empty scan
fslmaths temp_8103.nii.gz -mul 0 template.nii.gz


unset i
i=0
echo " "
echo "recombining subnuclei"
for r in 8103 8104 8105 8106 8108 8110 8111 8112 8113 8116 8117 8118 8119 8120 8121 8122 8123 8126 8127 8128 8129 8130 8133 8203 8204 8205 8206 8208 8210 8211 8212 8213 8216 8217 8218 8219 8220 8221 8222 8223 8226 8227 8228 8229 8230 8233 ; do
i=$[$i+1]
printf " thalamic subnucleus:  %1d\r" ${i}

#prog ${i} \# nuclei processed



nvox=$(fslstats temp_${r} -V | awk '{ print $1 }' | bc -l)

if test ${nvox} -ne 0; then

fslmaths template.nii.gz -add temp_${r}.nii.gz template.nii.gz

fi

done

mv template.nii.gz ${workdir}/${subj}/mri/ThalamicNuclei.${vers}.T1.FSvoxelSpace_noLMGN.nii.gz
rm temp_*.nii.gz

echo " "
cd ${workdir}/${subj}/QC/

if [ ! -f brain_pve_0.nii.gz ]; then
echo "running fast on ${subj}"
cd ${workdir}/${subj}/mri/
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -g -o \
${workdir}/${subj}/QC/brain brain.nii.gz
fi

echo "computing CSF mask"
# multiply CSF segmentation (from fast) with thalamic segmentation
fslmaths ${workdir}/${subj}/mri/ThalamicNuclei.${vers}.T1.FSvoxelSpace_noLMGN.nii.gz \
-bin -mul ${workdir}/${subj}/QC/brain_seg_0.nii.gz ${workdir}/${subj}/mri/thalcsf

csfoverlap=$(fslstats ${workdir}/${subj}/mri/thalcsf.nii.gz -V  | awk '{ print $1 }')

if [ -z ${temp} ]; then
csfoverlap=0
fi

echo "${subj} ${csfoverlap}" > ${workdir}/${subj}/QC/${subj}_CSF_overlap.txt

echo "computing WM mask"

# extract L and R WM segmentations from FreeSurfer
fslmaths ${workdir}/${subj}/mri/aseg.nii.gz -thr 2 -uthr 2 aseg_L
fslmaths ${workdir}/${subj}/mri/aseg.nii.gz -thr 41 -uthr 41 aseg_R
fslmaths aseg_L -add aseg_R FS_WM_mask
rm aseg_L.nii.gz aseg_R.nii.gz

# multiply WM segmentation with thalamic segmentation
fslmaths ${workdir}/${subj}/mri/ThalamicNuclei.${vers}.T1.FSvoxelSpace_noLMGN.nii.gz \
-bin -mul FS_WM_mask.nii.gz -bin thalwm
wmoverlap=$(fslstats thalwm -V | awk '{ print $1 }' )
echo "${subj} ${wmoverlap}" > ${workdir}/${subj}/QC/${subj}_WM_overlap.txt


# create png of slices


cd ${workdir}/${subj}/mri/

echo "creating overlay and PNG file of thalamic slices for QC"
image_to_slice=thaloverlay
overlay 1 0 brain.nii.gz -A ThalamicNuclei.v12.T1.FSvoxelSpace_noLMGN.nii.gz 1 12 ${image_to_slice}

# find location of Center of Gravity

locCfloat=$(fslstats ThalamicNuclei.v12.T1.FSvoxelSpace_noLMGN.nii.gz  -C | awk '{ print $3}')
locC=${locCfloat%.*}
minslice=$(echo "${locC} - 10 " | bc -l)
maxslice=$(echo "${locC} + 13 " | bc -l)

number_of_slices=$(echo "${maxslice} - ${minslice}" | bc -l)
number_of_slices_brain=$(fslval ${image_to_slice} dim3)
#Calculate the max spacing necessary to allow 24 slices to be cut
let slice_increment=(${number_of_slices}+24-1)/24


#####################################################################

## Run loop to slice and stitch thalslices

#####################################################################

count=1
col_count=7
row=0

#Slice the image.
echo "processing..."
for (( N = ${minslice}; N <= ${maxslice}; N += ${slice_increment} )); do
  printf "slice: %1d\r" ${N}
  FRAC=$(echo "scale=2; ${N} / ${number_of_slices_brain}" | bc -l);
  slicer ${image_to_slice} -L -z ${FRAC} ${image_to_slice}_${count}.png;

  #Add current image to a row.
  #If you have the first image of a new row (i.e., column 7), create new row
  if [[ $col_count == 7 ]] ; then
    row=$(echo "${row} + 1" | bc -l);
    mv ${image_to_slice}_${count}.png thalslices_row${row}.png
    col_count=2;
    just_started_a_new_row=1;
  #Otherwise, append your image to the existing row.
  else
    pngappend thalslices_row${row}.png + ${image_to_slice}_${count}.png thalslices_row${row}.png
    col_count=$(echo " ${col_count} + 1 " | bc -l);
    just_started_a_new_row=0;
    rm ${image_to_slice}_${count}.png
  fi
  count=$(echo  "${count} +1 " | bc -l);
done

#####################################################################

## Stitch your rows into a single thalslices

#####################################################################

label=${subj}

mv thalslices_row1.png thalslices-$label.png
pngappend thalslices-$label.png - thalslices_row2.png thalslices-$label.png
pngappend thalslices-$label.png - thalslices_row3.png thalslices-$label.png
pngappend thalslices-$label.png - thalslices_row4.png thalslices-$label.png
#pngappend thalslices-$label.png - thalslices_row5.png thalslices-$label.png
#pngappend thalslices-$label.png - thalslices_row6.png thalslices-$label.png

rm thalslices_row*
mv ${workdir}/${subj}/mri/thalslices-$label.png ${workdir}/${subj}/QC/thalslices-$label.png

echo "done with ${subj}"


else

echo "Thalamic segmentation not availabe for ${subj}"
echo "something may have gone wrong during the FreeeSurfer segmentation"
echo "inspect:"
echo "${workdir}/${subj}/mri"
echo "and try to rerun"
echo "exiting script"
exit

fi
