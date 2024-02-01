#!/usr/bin/env bash

# requires java 11

# cd to root folder of the repo
# ROOT is then expected to be /path/to/omegat-project-tm-pruning-service
# run as:
# bash code/prune_tmx.sh

# @todo: enhancement: make the $ROOT be the parent dir of the script regardless of where the script is run from 
ROOT="$(pwd)"
mkdir -p $ROOT/repos
mkdir -p $ROOT/offline
mkdir -p $ROOT/exports
common=$ROOT/repos/pisa_2025ft_translation_common
omegat_bin_path=$ROOT/omegat
config_dir_path=$ROOT/config
# permanent params
domain="https://git-codecommit.eu-central-1.amazonaws.com/v1/repos"


for repo_name in $(cat $ROOT/data/repos.txt)
do
    cd $ROOT
    echo ">>> HANDLING $repo_name "

    # get locale
    locale=$(echo $repo_name | cut -d"_" -f4)
    echo "LOCALE: $locale"

    # repo_name=pisa_2025${space}_translation_${locale}_${step}
    repo_url=$domain/$repo_name.git

    # clone project repo
    echo "git clone $repo_url --depth 1 $ROOT/repos/$repo_name"
    [ -d $ROOT/repos/$repo_name ] || git clone $repo_url --depth 1 $ROOT/repos/$repo_name

    # skip if it's not an omegat project
    [ -f repos/$repo_name/omegat.project ] || continue

    # if no repo exists (e.g. returned error 403, skip)
    [ -d repos/$repo_name ] || continue

    # make $ROOT/offline copy of the repo
    [ -d $ROOT/offline/${repo_name}_OMT ] || cp -r $ROOT/repos/$repo_name $ROOT/offline/${repo_name}_OMT

    # restore missing folders
    mkdir -p $ROOT/offline/${repo_name}_OMT/source/
    mkdir -p $ROOT/offline/${repo_name}_OMT/target/
    mkdir -p $ROOT/offline/${repo_name}_OMT/tm/
    mkdir -p $ROOT/offline/${repo_name}_OMT/dictionary/
    mkdir -p $ROOT/offline/${repo_name}_OMT/glossary/

    # remove repositories node from the $ROOT/offline copy (make project $ROOT/offline)
    xmlstarlet ed --inplace -d //repositories $ROOT/offline/${repo_name}_OMT/omegat.project

    # add config files
    cp $common/config/filters.xml        $ROOT/offline/${repo_name}_OMT/omegat
    cp $common/config/okf_html@cg.fprm   $ROOT/offline/${repo_name}_OMT/omegat
    cp $common/config/okf_xml@oat.fprm   $ROOT/offline/${repo_name}_OMT/omegat
    cp $common/config/okf_xml@qti.fprm   $ROOT/offline/${repo_name}_OMT/omegat
    cp $common/config/segmentation.conf  $ROOT/offline/${repo_name}_OMT/omegat

    # now get source files
    # @todo: point source folder in the project to common/source  ???? so that coping files isn't necessary?
    batches="$(find $ROOT/offline/${repo_name}_OMT/tm/ -type f -regextype egrep -regex '.*/(prev|next)/(01_COS_SCI-A_N|02_COS_SCI-B_N|03_COS_SCI-C_N|04_QQS_N|05_QQA_N|06_COS_LDW_N|07_COS_XYZ_N|07_COS_XYZ_N_linted|07_COS_XYZ_N_tolint|08_CGA_SCI_N|11_COS_MAT-A_T|12_COS_MAT-B_T|13_COS_REA-A_T|14_COS_REA-B_T|15_COS_SCI-A_T|16_COS_SCI-B_T|17_CGA_SCI_T|18_CGA_MAT_T|19_CGA_REA_T|21_COSP_REA-A_T|22_COSP_REA-B_T|23_COSP_MAT-A_T|24_COSP_MAT-B_T|25_COSP_SCI-A_N|26_COSP_SCI-A_T).tmx' -exec basename {} \; | cut -d'.' -f1)"
    for batch in $batches; 
    do
        # add batch
        cp -r $common/source/$batch $ROOT/offline/${repo_name}_OMT/source

        # create batch master TM
        echo "java -jar $omegat_bin_path/build/install/OmegaT/OmegaT.jar $ROOT/offline/${repo_name}_OMT --mode=console-translate --config-dir=$config_dir_path --script=$config_dir_path/scripts/prune_tmx_content_per_batch.groovy 2>/dev/null" 
        java -jar $omegat_bin_path/build/install/OmegaT/OmegaT.jar $ROOT/offline/${repo_name}_OMT --mode=console-translate --config-dir=$config_dir_path --script=$config_dir_path/scripts/prune_tmx_content_per_batch.groovy # 2>/dev/null

        # remove batch
        yes| rm -r $ROOT/offline/${repo_name}_OMT/source/$batch

        # now transfer the pruned TM from the offline copy of the repo to the online repo and push it
        cd $ROOT/repos/${repo_name} && git pull && cd $ROOT
        rsync -Pcauv  $ROOT/offline/${repo_name}_OMT/tm/ $ROOT/repos/${repo_name}/tm/

        # commit changes
        cd $ROOT/repos/${repo_name}
        git add . && git commit -m "Pruned batch TMs" && git push

    done

    # clean up the mess
    yes | rm -r $ROOT/offline/${repo_name}_OMT/
    yes | rm -r $ROOT/repos/${repo_name}/

done

# after that, the PISA workflow service can fetch those batch TMs and add them to the next step
