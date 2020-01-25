#!/bin/bash

# (C) C.Vriend - 1/1/2020
# code written as part of ENIGMA OCD for subsegmentation of the thalamus
# script to run FreeSurfer on T1 and subsequently perform thalamic subsegmentation
# script assumes that images are organized according to BIDS format

# source directories
export USER="${USER:=`whoami`}"
source "/opt/freesurfer-6.0.1/SetUpFreeSurfer.sh"
export FSLDIR=/opt/fsl-5.0.10
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${FSLDIR}/bin:${PATH}


# usage instructions
Usage() {
    echo "(C) C.Vriend - 1/1/2020"
    echo "code written as part of ENIGMA OCD for subsegmentation of the thalamus"
    echo "script assumes that images are organized according to BIDS format"
    echo ""
    echo "Usage: --bidsdir <BIDSdir> --outdir <SUBJECTS_DIR> [options] ..."
    echo "--bidsdir /path/to/inputfiles"
    echo "--outdir /path/to/output directory"
    echo "other options:"
    echo "--ext: extension of T1w image (default = nii.gz)"
    echo "--omp_nthreads: number of cores to use for each subject (default = 1)"
    echo "--nthreads: number of subjects to process simultaneously (default = 1)"
    echo ""
    exit 1
}

[ "$1" = "" ] && Usage

#parse default option arguments
ext=nii.gz
mode=full
NCORES=1
NSUBJ=1



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
    --ext)
			ext=$2
			shift
			;;
    --omp_nthreads)
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
if [ -z $BIDSdir ] || [ -z $outputdir ]; then
echo "you have to specify (at least) an input directory (--bidsdir /path/to/files)"
echo "and output directory (--outdir /path/to/output)"
exit 1
fi

# input variable summary
echo "input BIDS directory =" $BIDSdir
echo "output directory / SUBJECT_DIR = $outputdir"
echo " "
echo "options = "
echo "extension of T1w file = $ext"
echo "number of cores to use per subject = $NCORES"
echo "number of subjects to process simultaneously = $NSUBJ"
sleep 2

# output subject diroectory
export SUBJECTS_DIR=${outputdir}
# number of cores to use for thalamic sub segmentation
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${NCORES}


cd ${BIDSdir}

subjects=$(ls -d sub-*)
numsubj=$(echo ${subjects} | wc -l)
echo "there are ${numsubj} subjects in ${BIDSdir}"
echo " "

j=0
for subj in ${subjects}; do

echo ${subj}

if [[ ${NSUBJ} -gt 1 ]]; then
sleep $[ $RANDOM % 120 ]
fi

# find T1w image
T1w=$(ls ${subj}/anat/*T1w.${ext})

# counter
j=$[$j+1]

if [ ! -f ${outputdir}/${subj}/scripts/recon-all.done ] && [ ! -f ${outputdir}/${subj}/mri/wmparc.mgz ]; then

  if [ -f ${outputdir}/${subj}/scripts/IsRunning.lh+rh ]; then
    echo "something may have gone wrong during a previous run of this script"
    echo "${outputdir}/${subj}/scripts/IsRunning.lh+rh exists"
    echo "please delete this file and try again"
    exit
  fi


      if [ -d ${outputdir}/${subj} ]; then
        echo "continue previous recon-all -all"
        (recon-all -subjid ${subj} -all -openmp ${NCORES} ; segmentThalamicNuclei.sh ${subj}) &
      else
        echo "starting recon-all -all"
        (recon-all -subjid ${subj} -i ${T1w} -all -openmp ${NCORES} ; segmentThalamicNuclei.sh ${subj}) &
      fi

  #  elif [ ${mode}=="subc"; then
  #      echo "starting op recon-all subcortical segmentation only"
  #      (recon-all -subjid ${subj} -i ${T1w} -autorecon1 -autorecon2 -openmp ${NCORES} ;\
  #      cp -n ${outputdir}/${subj}/mri/aseg.auto.mgz ${outputdir}/${subj}/mri/aseg.mgz;\
  #      mri_segstats --seg mri/aseg.mgz --sum stats/aseg.stats --pv mri/norm.mgz \
  #      --empty --excludeid 0 --excl-ctxgmwm --supratent --subcortgray --totalgray \
  #      --in mri/norm.mgz --in-intensity-name norm --in-intensity-units MR --etiv \
  #      --surf-wm-vol --surf-ctx-vol --ctab $FREESURFER_HOME/ASegStatsLUT.txt \
  #      --subject ${subj} ;\
  #      segmentThalamicNuclei.sh ${subj}) &

else
echo "recon-all already completed"
echo "continue to thalamus subsegmentation"
segmentThalamicNuclei.sh ${subj} &
fi

# combine different subsegmentations together
if [ -f ${outputdir}/${subj}/mri/ThalamicNuclei.v10.T1.mgz ]; then



fi

# trick to keep script from exeeding number of simultaneous processes
if [[ ${j} == ${NSUBJ} ]]; then
  wait
  j=0
fi



done
