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
    cat <<EOF

    (C) C.Vriend - 5/16/2020
    code written for ENIGMA OCD for subsegmentation of the thalamus using FreeSurfer 7.1.0
    and other open-source software
    script assumes that images are organized according to BIDS format

    Usage: -bidsdir <BIDSdir> -outdir <SUBJECTS_DIR> -sample <sample name> (-group) [options] ...
    Obligatory:
    -bidsdir /path/to/inputfiles
    -outdir /path/to/output directory
    -sample name of the sample (self chosen)

    Optional:
    -group: extract and plot volumes for entire group for QA and stats. this needs to be run to create csv + html files

    other options:
    -subjs: text file with list of subjecs that need to be run (default = run all subjects in bidsdir)
             this file needs to be stored in BIDSdir
    -ext: extension of T1w image (default = nii.gz)
    -omp-nthreads: number of cores to use for each subject (default = 1)
    -nthreads: number of subjects to process simultaneously (default = 1)


EOF
    exit 1
}

[ _$1 = _ ] && Usage

#parse default option arguments
ext=nii.gz
#mode=full
NCORES=1
NSUBJ=1
# different versions of Thalamic subnuclei exists: v10 and v12.
vers=v12

while [ _$1 != _ ] ; do
	case "$1" in
    -bidsdir)
      BIDSdir=$2
      shift
      ;;
    -outdir)
      outputdir=$2
      shift
      ;;
    -sample)
        sample=$2
        shift
        ;;
    -subjs)
        subjs=$2
        shift
        ;;
    -group)
        group=1
        ;;
    -ext)
			ext=$2
			shift
			;;
    -omp-nthreads)
			NCORES=$2
			shift
			;;
		-nthreads)
			NSUBJ=$2
			shift
			;;
		*)
    echo "Unknown argument: $1";;
	esac
	shift
done

# input variable check 1
if [ -z $BIDSdir ] || [ -z $outputdir ] || [ -z $sample ]; then
echo "you have to specify (at least) an input directory (-bidsdir /path/to/files)"
echo ", output directory (-outdir /path/to/output)"
echo "and a name for your sample (-sample name (self chosen))"

exit 1
fi



# input variable summary
echo "input BIDS directory =" ${BIDSdir}
echo "output directory / SUBJECT_DIR = $outputdir"
echo "sample = $sample"
echo " "
if [[ ${group} -eq 1 ]]; then
echo "... running pipeline with extraction of group stats/plots "
else
echo "... running pipeline without extracting group stats/plots "
fi
echo "options = "
echo "extension of T1w file = $ext"
if [ ! -z ${subjs} ]; then
echo "-subj flag set; running script on subset of subjects in BIDS directory"
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
# find subject directories
ls -d sub-*/ > temp.txt
subjects=$(sed 's:/.*::' temp.txt)
rm temp.txt


numsubj=$(echo "${subjects}" | wc -l)
echo ".............................. "
echo " "
echo "there is/are ${numsubj} subject(s) in ${BIDSdir}"
echo "running script on all subjects "

fi

# counter
j=0
# set trap

# set trap
trap ctrl_c INT

function ctrl_c() {
      echo
      echo "Ctrl-C by user"
      echo "killing all child processes and exit"
      echo
      sleep 1
      kill 0
      exit
}
#trap "kill 0" EXIT

# start loop
num_jobs="\j"  # The prompt escape for number of jobs currently running
for subj in ${subjects}; do

# check existence of files in output folder
if [ -d ${outputdir}/${subj} ] \
&& [ -f ${outputdir}/${subj}/stats/thalamic-nuclei.lh.${vers}.T1.stats ] \
&& [ -f ${outputdir}/${subj}/stats/thalamic-nuclei.rh.${vers}.T1.stats ] \
&& [ -f ${outputdir}/${subj}/scripts/recon-all.done ] \
&& [ -f ${outputdir}/${subj}/mri/wmparc.mgz ] \
&& [ -f ${outputdir}/${subj}/mri/thalwm.nii.gz ] \
&& [ -f ${outputdir}/${subj}/mri/thalcsf.nii.gz ] \
&& [ $(cat ${outputdir}/${subj}/QC/${subj}_CSF_overlap.txt | wc -l) -ge 1 ] \
&& [ $(cat ${outputdir}/${subj}/QC/${subj}_WM_overlap.txt | wc -l) -ge 1 ]; then

echo "processing steps already finished for ${subj}"
echo "continue with the next subject"
################################################################################

else

  while (( ${num_jobs@P} >= NSUBJ )); do
  wait -n
  done

  # allow only to execute $N jobs in parallel
  # if [[ $(jobs -r -p | wc -l) -gt $N ]]; then
       # wait only for first job
#       wait -n
#   fi


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
slicer ${T1w} ${base}_noneck -a ${outputdir}/vol+QA/${base}_noneck_QA.png
#convert ${outputdir}/${base}_noneck_overlay.ppm ${outputdir}/${base}_noneck_overlay.png
fi

T1w_noneck=${base}_noneck.nii.gz

if [ ! -f ${outputdir}/${subj}/mri/wmparc.mgz ] \
|| [ ! -f ${outputdir}/${subj}/mri/norm.mgz ] \
|| [ ! -f ${outputdir}/${subj}/mri/transforms/talairach.xfm ]; then

  if [ -f ${outputdir}/${subj}/scripts/IsRunning.lh+rh ]; then
    echo "something may have gone wrong during a previous run of this script"
    echo "${outputdir}/${subj}/scripts/IsRunning.lh+rh exists"
    while true; do
        read -t 30 -p "Do you wish to delete this file now and continue (Y/N)? " yn
        case $yn in
            [Yy]* ) echo "removed file and continuing ..." ; \
            rm ${outputdir}/${subj}/scripts/IsRunning.lh+rh; break;;
            [Nn]* ) flag=1; break;;
            * ) echo "time out reached; removed file and continuing ..." ; \
            rm ${outputdir}/${subj}/scripts/IsRunning.lh+rh; break;;
        esac
    done

  fi
      # abort this iteration
      if [[ ${flag} -eq 1 ]]; then
      echo "aborting script for ${subj}"
      echo "but this subject will need follow-up!"
      sleep 2
      unset flag
      continue
      fi

      if [ -d ${outputdir}/${subj} ] \
      && [ -f ${outputdir}/${subj}/mri/orig/001.mgz ] ; then
        echo "----------------------- "
        echo "continue previous recon-all -all"
        echo "if the script exits with errors (within minutes) delete the output directory "
        echo "of subject = ${subj}"
        echo "and try again"
        echo "----------------------- "
        sleep 4
        (recon-all -subjid ${subj} -all -openmp ${NCORES} -subfields ; \
        /neurodocker/combine_subnuclei.sh ${outputdir} ${subj}) | tee ${outputdir}/${subj}_recon.log &

		# to keep jobs slightly out of sync
		if [[ ${NSUBJ} -gt 1 ]]; then
			sleep $[ $RANDOM % 90 ]
		fi


      else
        if [ -d ${outputdir}/${subj} ]; then
        echo "deleting previous run and restarting"
        rm -rf ${outputdir}/${subj}
        fi
        echo "starting recon-all -all"
        (recon-all -subjid ${subj} -i ${T1w_noneck} -all -openmp ${NCORES} -subfields ; \
        /neurodocker/combine_subnuclei.sh ${outputdir} ${subj}) | tee ${outputdir}/${subj}_recon.log &

		# to keep jobs slightly out of sync
		if [[ ${NSUBJ} -gt 1 ]]; then
			sleep $[ $RANDOM % 90 ]
		fi

      fi


elif [ ! -f ${outputdir}/${subj}/stats/thalamic-nuclei.lh.${vers}.T1.stats ] \
|| [ ! -f ${outputdir}/${subj}/stats/thalamic-nuclei.rh.${vers}.T1.stats ]; then
echo "recon-all already completed"
echo "continue to thalamus subsegmentation"

		(recon-all -subjid ${subj} -subfields -openmp ${NCORES} ; \
		/neurodocker/combine_subnuclei.sh ${outputdir} ${subj}) | tee ${outputdir}/${subj}_thalseg.log &

		# to keep jobs slightly out of sync
		if [[ ${NSUBJ} -gt 1 ]]; then
			sleep $[ $RANDOM % 90 ]
		fi

elif [ ! -f ${outputdir}/${subj}/mri/thalwm.nii.gz ] \
|| [ ! -f ${outputdir}/${subj}/mri/thalcsf.nii.gz ] \
|| [ $(cat ${outputdir}/${subj}/QC/${subj}_CSF_overlap.txt | wc -l) -lt 1 ] \
|| [ $(cat ${outputdir}/${subj}/QC/${subj}_WM_overlap.txt | wc -l) -lt 1 ]; then

		echo "recon-all already completed"
		echo " thalamus subsegmentation already completed"
		echo "continue with QA steps"

		/neurodocker/combine_subnuclei.sh ${outputdir} ${subj} | tee ${outputdir}/${subj}_QAsteps.log &

		# to keep jobs slightly out of sync
		if [[ ${NSUBJ} -gt 1 ]]; then
			sleep $[ $RANDOM % 90 ]
		fi

else
		echo "recon-all already completed"
		echo " thalamus subsegmentation already completed"
		echo "single subject QA steps already completed"
		echo " continue with the next subject"

fi


fi
# files exist


done

child_count=$(($(pgrep --parent $$ | wc -l) - 1))

if [[ ${child_count} -gt 0 ]]; then
echo "there are still ${child_count} active processes. waiting ..."
fi
# wait untill all processes have finished
wait
################### END SUBJECT SPECIFIC PART ###################

################### START GROUP-SPECIFIC PART ###################

if [[ ${group} -eq 1 ]]; then
  echo "creating group stats and figures"

cd ${outputdir}

ls -d sub-*/ > temp.txt
subjects=$(sed 's:/.*::' temp.txt)
rm temp.txt

rm -f ${outputdir}/vol+QA/brainmgzs.txt
rm -f ${outputdir}/vol+QA/thalsegmgzs.txt

# extract segmentation values
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

# create list of brain mgz / ThalamicNuclei.v12.T1.mgz for concatenation
if [ ! -f ${subj}/mri/brain.mgz ]; then
  echo "brain.mgz does not exist for ${subj} in the FreeSurfer mri folder"
  echo "this file is necessary for quality inspection"
  echo " "
  echo "rerun the script for this subject or remove the folder from the output directory ="
  echo "${outputdir}"
  echo " "
  echo "exiting the program"
  sleep 1
  exit
fi

if [ ! -f ${subj}/mri/ThalamicNuclei.${vers}.T1.mgz ]; then
 echo "ThalamicNuclei.${vers}.T1.mgz does not exist for ${subj} in the FreeSurfer mri folder"
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

echo "extracting ICV and Freesurfer native thalamus volume "
asegstats2table --subjects ${subjects} --tablefile ${outputdir}/vol+QA/${sample}_asegstats.txt

echo "extracting WM and CSF overlap with Iglesias thalamus segmentation "

rm -f ${outputdir}/vol+QA/${sample}_WM_overlap.txt
rm -f ${outputdir}/vol+QA/${sample}_CSF_overlap.txt

for subj in ${subjects}; do

cat ${subj}/QC/${subj}_CSF_overlap.txt >> ${outputdir}/vol+QA/${sample}_CSF_overlap.txt
cat ${subj}/QC/${subj}_WM_overlap.txt >> ${outputdir}/vol+QA/${sample}_WM_overlap.txt

done

# make webpage of thalamus subsegmentations
echo "creating webpage of thalamic subsegmentations for visual QC"
/neurodocker/create_webpage_thalsubs.sh ${outputdir}
# copy reference segmentations to vol+qa
cp /neurodocker/REFERENCE_1subj_thalQC.html /neurodocker/REFERENCE_avg_thalQC.html ${outputdir}/vol+QA/

echo "extracting and plotting volume of thalamic subnuclei"
sleep 2
# run python script to extract volumes and make plots for QA
/neurodocker/extract_vols_plot.py --workdir ${outputdir} --outdir ${outputdir}/vol+QA --outbase ${sample} --plotbase plot_${sample} --thalv ${vers}

else

  echo "done processing all ${numsubj} subjects"
  echo "output has been saved to ${outputdir}"
  echo
  echo "-group flag was not set"
  echo "rerun script with -group to create group stats and figures"
fi
