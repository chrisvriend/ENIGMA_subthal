#!/bin/bash

# (C) C.Vriend - 1/1/2020
# code written as part of ENIGMA OCD for subsegmentation of the thalamus
# script to run FreeSurfer on T1 and subsequently perform thalamic subsegmentation
# script assumes that images are organized according to BIDS format

# source directories
export USER="${USER:=`whoami`}"
export FREESURFER_HOME=/opt/freesurfer7
source ${FREESURFER_HOME}/SetUpFreeSurfer.sh
export FSLDIR="/opt/fsl-5.0.10"
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${FSLDIR}/bin:${PATH}
export FSLOUTPUTTYPE=NIFTI_GZ


# usage instructions
Usage() {
    echo "(C) C.Vriend - May 2020"
    echo "code written as part of ENIGMA OCD for subsegmentation of the thalamus"
    echo "script assumes that images are organized according to BIDS format"
    echo ""
    echo "Usage: --bidsdir <BIDSdir> --outdir <SUBJECTS_DIR> --site <site name> [options] ..."
    echo "--bidsdir /path/to/inputfiles"
    echo "--outdir /path/to/output directory"
    echo "--site name of site (self chosen)"

    echo "other options:"
    echo "--subjs: txt file with subjecs to run script on"
    echo "(default = run on all subjects in BIDSdir)"
    echo "--ext: extension of T1w image (default = nii.gz)"
    echo "--omp-nthreads: number of cores to use for each subject (default = 1)"
    echo "--nthreads: number of subjects to process simultaneously (default = 1)"
    echo ""
    exit 1
}

[ "$1" = "" ] && Usage

#parse default option arguments
ext=nii.gz
#mode=full
NCORES=1
NSUBJ=1

# different versions of Thalamic subnuclei exists: v10 and v12.
vers=v12

while [ "$1" != "" ]; do
	case "$1" in
    --bidsdir)
      BIDSdir=$2
      shift
      ;;
    --outdir)
      outputdir=$2
      shift
      ;;
    --site)
        site=$2
        shift
        ;;
    --subjs)
        subjs=$2
        shift
        ;;
    --ext)
			ext=$2
			shift
			;;
    --omp-nthreads)
			NCORES=$2
			shift
			;;
		--nthreads)
			NSUBJ=$2
			shift
			;;
		*)
    echo "Unknown argument: $1";;
	esac
	shift
done

# input variable check 1
if [ -z $BIDSdir ] || [ -z $outputdir ] || [ -z $site ]; then
echo "you have to specify (at least) an input directory (--bidsdir /path/to/files)"
echo ", output directory (--outdir /path/to/output)"
echo "and a name for your site (--site name (self chosen))"

exit 1
fi




# input variable summary
echo "input BIDS directory =" $BIDSdir
echo "output directory / SUBJECT_DIR = $outputdir"
echo "site = $site"
echo " "
echo "options = "
echo "extension of T1w file = $ext"
if [ ! -z $subjs ]; then
echo "--subj flag set; running script on subset of subjects in BIDS directory"
else
echo "running script on all subjects in BIDS directory"
fi
echo "extension of T1w file = $ext"
echo "number of cores to use per subject = $NCORES"
echo "number of subjects to process simultaneously = $NSUBJ"
sleep 2


mkdir -p ${outputdir}
mkdir -p ${outputdir}/vol+QA

# output subject diroectory
export SUBJECTS_DIR=${outputdir}
# number of cores to use for thalamic sub segmentation
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${NCORES}


cd ${BIDSdir}

if [ ! -z ${subjs} ]; then

subjects=$(cat ${subjs})

numsubj=$(echo "${subjects}" | wc -l)

ls -d sub-*/ > temp.txt
totsubj=$(sed 's:/.*::' temp.txt)
rm temp.txt
numsubjtot=$(echo "${totsubj}" | wc -l)


echo ".............................. "
echo " "
echo "script will run on ${numsubj} out of ${numsubjtot} subjects"
echo "in ${BIDSdir}"

else
# find subject diroectories
ls -d sub-*/ > temp.txt
subjects=$(sed 's:/.*::' temp.txt)
rm temp.txt


numsubj=$(echo "${subjects}" | wc -l)
echo ".............................. "
echo " "
echo "there is/are ${numsubj} subject(s) in ${BIDSdir}"
echo "running script on all "

fi


j=0
for subj in ${subjects}; do

echo ${subj}

cd ${BIDSdir}/${subj}/anat

# find T1w image
T1w=$(ls *T1w.${ext})

# reorient to standard and crop neck
base=$(${FSLDIR}/bin/remove_ext ${T1w})

# reorient to standard
fslreorient2std ${T1w} ${T1w}


if [ ! -f ${base}_noneck.nii.gz ]; then
echo "crop T1w image"
standard_space_roi ${T1w} ${base}_noneck -maskFOV -roiNONE
fi

if [ ! -f ${outputdir}/vol+QA/${base}_noneck_overlay.png ]; then
echo "check crop quality"
overlay 0 1 ${T1w} -A ${base}_noneck 0 1000 ${base}_overlay
slicer ${base}_overlay -a ${outputdir}/vol+QA/${base}_noneck_overlay.png
#convert ${outputdir}/${base}_noneck_overlay.ppm ${outputdir}/${base}_noneck_overlay.png
rm ${base}_overlay.nii.gz
fi

T1w_noneck=${base}_noneck.nii.gz


# counter
j=$[$j+1]


if [ ! -f ${outputdir}/${subj}/scripts/recon-all.done ] \
|| [ ! -f ${outputdir}/${subj}/mri/wmparc.mgz ] \
|| [ ! -f ${outputdir}/${subj}/mri/aseg.mgz ]; then

  if [ -f ${outputdir}/${subj}/scripts/IsRunning.lh+rh ]; then
    echo "something may have gone wrong during a previous run of this script"
    echo "${outputdir}/${subj}/scripts/IsRunning.lh+rh exists"
    while true; do
        read -p "Do you wish to delete this file now and continue (Y/N)? " yn
        case $yn in
            [Yy]* ) echo "removed file and continueing ..." ; \
            rm ${outputdir}/${subj}/scripts/IsRunning.lh+rh; break;;
            [Nn]* ) echo "aborting script" ; sleep 1; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

  fi


      if [ -d ${outputdir}/${subj} ]; then
        echo "continue previous recon-all -all"
        (recon-all -subjid ${subj} -all -openmp ${NCORES} -subfields ; \
        /neurodocker/combine_subnuclei.sh ${outputdir} ${subj}) &
      else
        echo "starting recon-all -all"
        (recon-all -subjid ${subj} -i ${T1w_noneck} -all -openmp ${NCORES} -subfields ; \
        /neurodocker/combine_subnuclei.sh ${outputdir} ${subj}) &
      fi


elif [ ! -f ${outputdir}/${subj}/stats/thalamic-nuclei.lh.${vers}.T1.stats ] \
|| [ ! -f ${outputdir}/${subj}/stats/thalamic-nuclei.rh.${vers}.T1.stats ]; then
echo "recon-all already completed"
echo "continue to thalamus subsegmentation"

(recon-all -subjid ${subj} -subfields -openmp ${NCORES} ; /neurodocker/combine_subnuclei.sh ${outputdir} ${subj}) &

elif [ ! -f ${outputdir}/${subj}/mri/thalwm.nii.gz ] \
|| [ ! -f ${outputdir}/${subj}/mri/thalcsf.nii.gz ] \
|| [ $(cat ${outputdir}/${subj}/QC/${subj}_CSF_overlap.txt | wc -l) -lt 1 ] \
|| [ $(cat ${outputdir}/${subj}/QC/${subj}_WM_overlap.txt | wc -l) -lt 1 ]; then

echo "recon-all already completed"
echo " thalamus subsegmentation already completed"
echo "continue with QA steps"

/neurodocker/combine_subnuclei.sh ${outputdir} ${subj} &

else
  echo "recon-all already completed"
  echo " thalamus subsegmentation already completed"
  echo "single subject QA steps already completed"
  echo " continue with the next subject"

fi

# to keep jobs slightly out of sync
if [[ ${NSUBJ} -gt 1 ]]; then
sleep $[ $RANDOM % 120 ]
fi


# trick to keep script from exceeding number of simultaneous processes
if [[ ${j} == ${NSUBJ} ]]; then
  wait
  j=0
fi



done

# extract segmentation values
cd ${outputdir}

ls -d sub-*/ > temp.txt
subjects=$(sed 's:/.*::' temp.txt)
rm temp.txt

for subj in ${subjects}; do

if [ ! -f ${subj}/stats/aseg.stats ]; then
echo "aseg.stats does not exist for ${subj}"
echo "this file is necessary to extract ICV"
echo "and the native thalamus segmentation"
echo " "
echo "rerun the script for this subject or remove the folder from the output directory ="
echo "${outputdir}"
echo " "
echo "exiting the program"
sleep 1
exit

fi

if [ ! -f ${subj}/QC/${subj}_CSF_overlap.txt ]; then
  echo "CSF_overlap.txt does not exist for ${subj} in the QC folder"
  echo "this file is necessary for quality inspection"
  echo " "
  echo "rerun the script for this subject or remove the folder from the output directory ="
  echo "${outputdir}"
  echo " "
  echo "exiting the program"
  sleep 1
  exit

fi

if [ ! -f ${subj}/QC/${subj}_CSF_overlap.txt ]; then
  echo "WM_overlap.txt does not exist for ${subj} in the QC folder"
  echo "this file is necessary for quality inspection"
  echo " "
  echo "rerun the script for this subject or remove the folder from the output directory ="
  echo "${outputdir}"
  echo " "
  echo "exiting the program"
  sleep 1
  exit


fi

done


echo "extracting ICV and Freesurfer native native thalamus volume "
asegstats2table --subjects ${subjects} --tablefile ${outputdir}/vol+QA/allppn_asegstats.txt

echo "extracting WM and CSF overlap with Iglesias thalamus segmentation "

rm -f ${outputdir}/vol+QA/allppn_WM_overlap.txt
rm -f ${outputdir}/vol+QA/allppn_CSF_overlap.txt

for subj in ${subjects}; do

cat ${subj}/QC/${subj}_CSF_overlap.txt >> ${outputdir}/vol+QA/allppn_CSF_overlap.txt
cat ${subj}/QC/${subj}_WM_overlap.txt >> ${outputdir}/vol+QA/allppn_WM_overlap.txt

done

echo "extracting and plotting volume of thalamic subnuclei"
sleep 2

# run python script to extract volumes and make plots for QA
/neurodocker/extract_vols_plot.py --workdir ${outputdir} --outdir ${outputdir}/vol+QA --outbase ENIGMA_thal_${site} --plotbase ENIGMA_thal_${site} --thalv v12
