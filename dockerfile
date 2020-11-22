# Generated by: Neurodocker version 0.7.0+0.gdc97516.dirty
# Latest release: Neurodocker version 0.7.0
# Timestamp: 2020/11/21 13:57:29 UTC
#
# Thank you for using Neurodocker. If you discover any issues
# or ways to improve this software, please submit an issue or
# pull request on our GitHub repository:
#
#     https://github.com/ReproNim/neurodocker

FROM debian:stretch

USER root

ARG DEBIAN_FRONTEND="noninteractive"

ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    ND_ENTRYPOINT="/neurodocker/mainscript.sh"
RUN export ND_ENTRYPOINT="/neurodocker/mainscript.sh" \
    && apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           apt-utils \
           bzip2 \
           ca-certificates \
           curl \
           locales \
           time \
           procps \
           unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG="en_US.UTF-8" \
    && chmod 777 /opt && chmod a+s /opt \
    && mkdir -p /neurodocker \
    && if [ ! -f "$ND_ENTRYPOINT" ]; then \
         echo '#!/usr/bin/env bash' >> "$ND_ENTRYPOINT" \
    &&   echo 'set -e' >> "$ND_ENTRYPOINT" \
    &&   echo 'export USER="${USER:=`whoami`}"' >> "$ND_ENTRYPOINT" \
    &&   echo 'if [ -n "$1" ]; then "$@"; else /usr/bin/env bash; fi' >> "$ND_ENTRYPOINT"; \
    fi \
    && chmod -R 777 /neurodocker && chmod a+s /neurodocker


COPY [ "license.txt",  "/opt/freesurfer7/"]
COPY [ "mainscript_v9.sh", "/neurodocker/mainscript.sh"]
COPY [ "combine_subnuclei_v3.sh" , "/neurodocker/combine_subnuclei.sh"]
COPY [ "extract_vols_plot.py" , "/neurodocker/extract_vols_plot.py"]
COPY [ "create_webpage_thalsubs.sh", "/neurodocker/create_webpage_thalsubs.sh"]
COPY [ "QA_thalseg_v2.sh", "/neurodocker/QA_thalseg.sh"]
COPY [ "thalseg2html.py", "/neurodocker/thalseg2html.py"]
COPY [ "REFERENCE_1subj_thalQC.html", "/neurodocker/"]
COPY [ "REFERENCE_avg_thalQC.html", "/neurodocker/"]

RUN [“chmod”, “+x”, "/neurodocker/mainscript.sh”]
ENTRYPOINT ["/neurodocker/mainscript.sh"]


ENV FREESURFER_HOME="/opt/freesurfer7" \
    PATH="/opt/freesurfer7/bin:$PATH"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
           libgomp1 \
           libxmu6 \
           libxt6 \
           perl \
           tcsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Downloading FreeSurfer ..." \
    && mkdir -p /opt/freesurfer7 \
    && curl -fsSL --retry 5 https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.1.1/freesurfer-linux-centos6_x86_64-7.1.1.tar.gz \
    | tar -xz -C /opt/freesurfer7 --strip-components 1 \
      --exclude='freesurfer/average/mult-comp-cor' \
      --exclude='freesurfer/average/BrainstemSS' \
      --exclude='freesurfer/average/Buckner_JNeurophysiol11_MNI152' \
      --exclude='freesurfer/average/Choi_JNeurophysiol12_MNI152' \
      --exclude='freesurfer/average/HippoSF' \
      --exclude='freesurfer/average/Yeo_Brainmap_MNI152' \
      --exclude='freesurfer/average/Yeo_JNeurophysiol11_MNI152' \
      --exclude='freesurfer/lib/cuda' \
      --exclude='freesurfer/lib/qt' \
      --exclude='freesurfer/subjects/V1_average' \
      --exclude='freesurfer/subjects/bert' \
      --exclude='freesurfer/subjects/cvs_avg35' \
      --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
      --exclude='freesurfer/subjects/fsaverage3' \
      --exclude='freesurfer/subjects/fsaverage4' \
      --exclude='freesurfer/subjects/fsaverage5' \
      --exclude='freesurfer/subjects/fsaverage6' \
      --exclude='freesurfer/subjects/fsaverage_sym' \
      --exclude='freesurfer/trctrain' \
      && sed -i 's/set scrlist = (segmentHA_T1.sh segmentThalamicNuclei.sh segmentBS.sh)/set scrlist =  (segmentThalamicNuclei.sh)/g' /opt/freesurfer7/bin/recon-all


ENV CONDA_DIR="/opt/miniconda-latest" \
    PATH="/opt/miniconda-latest/bin:$PATH"
RUN export PATH="/opt/miniconda-latest/bin:$PATH" \
    && echo "Downloading Miniconda installer ..." \
    && conda_installer="/tmp/miniconda.sh" \
    && curl -fsSL --retry 5 -o "$conda_installer" https://repo.anaconda.com/miniconda/Miniconda3-py37_4.8.3-Linux-x86_64.sh \
    && bash "$conda_installer" -b -p /opt/miniconda-latest \
    && rm -f "$conda_installer" \
    && conda update -yq -nbase conda \
    && conda config --system --prepend channels conda-forge \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && sync && conda clean -y --all && sync \
    && conda create -y -q --name neuro \
    && conda install -y -q --name neuro \
           "python=3.7" \
           "traits" \
           "numpy" \
           "pandas" \
           "seaborn=0.10.1" \
           "matplotlib" \
    && sync && conda clean -y --all && sync \
    && bash -c "source activate neuro \
    &&   pip install --no-cache-dir  \
             "nilearn" \
             "ptitprince" \
             "plotly"" \
    && rm -rf ~/.cache/pip/* \
    && sync



ENV FSLDIR="/opt/fsl-5.0.10" \
    PATH="/opt/fsl-5.0.10/bin:$PATH" \
    FSLOUTPUTTYPE="NIFTI_GZ" \
    FSLMULTIFILEQUIT="TRUE" \
    FSLTCLSH="/opt/fsl-5.0.10/bin/fsltclsh" \
    FSLWISH="/opt/fsl-5.0.10/bin/fslwish" \
    FSLLOCKDIR="" \
    FSLMACHINELIST="" \
    FSLREMOTECALL="" \
    FSLGECUDAQ="cuda.q"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
           dc \
           file \
           libfontconfig1 \
           libfreetype6 \
           libgl1-mesa-dev \
           libgl1-mesa-dri \
           libglu1-mesa-dev \
           libgomp1 \
           libice6 \
           libxcursor1 \
           libxft2 \
           libxinerama1 \
           libxrandr2 \
           libxrender1 \
           libxt6 \
           sudo \
           wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Downloading FSL ..." \
    && mkdir -p /opt/fsl-5.0.10 \
    && curl -fsSL --retry 5 https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.10-centos6_64.tar.gz \
    | tar -xz -C /opt/fsl-5.0.10 --strip-components 1 \
    && sed -i '$iecho Some packages in this Docker container are non-free' $ND_ENTRYPOINT \
    && sed -i '$iecho If you are considering commercial use of this container, please consult the relevant license:' $ND_ENTRYPOINT \
    && sed -i '$iecho https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence' $ND_ENTRYPOINT \
    && sed -i '$isource $FSLDIR/etc/fslconf/fsl.sh' $ND_ENTRYPOINT \
    && echo "Installing FSL conda environment ..." \
    && bash /opt/fsl-5.0.10/etc/fslconf/fslpython_install.sh -f /opt/fsl-5.0.10

RUN echo '{ \
    \n  "pkg_manager": "apt", \
    \n  "instructions": [ \
    \n    [ \
    \n      "base", \
    \n      "debian:stretch" \
    \n    ], \
    \n    [ \
    \n      "freesurfer", \
    \n      { \
    \n        "version": "7.1.1" \
    \n      } \
    \n    ], \
    \n    [ \
    \n      "miniconda", \
    \n      { \
    \n        "create_env": "neuro", \
    \n        "conda_install": [ \
    \n          "python=3.7", \
    \n          "traits", \
    \n          "numpy", \
    \n          "pandas", \
    \n          "seaborn", \
    \n          "matplotlib" \
    \n        ], \
    \n        "pip_install": [ \
    \n          "os", \
    \n          "ptitprince", \
    \n          "plotly" \
    \n        ] \
    \n      } \
    \n    ], \
    \n    [ \
    \n      "fsl", \
    \n      { \
    \n        "version": "5.0.10" \
    \n      } \
    \n    ] \
    \n  ] \
    \n}' > /neurodocker/neurodocker_specs.json
