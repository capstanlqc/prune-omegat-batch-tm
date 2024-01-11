#!/usr/bin/env bash

# this is a mockup of the service
# production version to be writen in python or similar

# set root path
# this will be /path/to/omegat-project-tm-pruning-service if called as above
ROOT="$(pwd)"
mkdir -p $ROOT/repos
mkdir -p $ROOT/offline
common=$ROOT/repos/pisa_2025ft_translation_common
omegat_bin_path=$ROOT/omegat
config_dir_path=$ROOT/config

# parameters in the call should refer to the project where a batch has been 
# test parameters (real params to be provided in in the call)
space="stg" # should be "ft" in production
locale="he-IL"
step="translation1"

# permanent params
domain="https://git-codecommit.eu-central-1.amazonaws.com/v1/repos"

repo_name=pisa_2025${space}_translation_${locale}_${step}
repo_url=$domain/$repo_name.git

# clone project repo
git clone $repo_url --depth 1 repos/$repo_name

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
# get batches from source batch folder mappings in the project settings
batches=()
while IFS= read -r line; do
    batches+=( "$line" )
done < <( xmlstarlet select -t -c "//mapping[contains(@local, 'source')]" $ROOT/repos/$repo_name/omegat.project | grep -Poh '(?<=local="source/)[^"]+' )

for batch in $batches
do
    echo $batch
    # add source files
    cp -r $common/source/$batch $ROOT/offline/${repo_name}_OMT/source

    # create batch master TM
    java -jar $omegat_bin_path/build/install/OmegaT/OmegaT.jar $ROOT/offline/${repo_name}_OMT --mode=console-translate --config-dir=$config_dir_path

    # copy batch master TM to repo
    mkdir -p $ROOT/repos/${repo_name}/tasks
    cp $ROOT/offline/${repo_name}_OMT/${repo_name}_OMT-omegat.tmx $ROOT/repos/${repo_name}/tasks/$batch.tmx

    # delete batch folder  before adding the next one
    yes | rm -r $ROOT/offline/${repo_name}_OMT/source/$batch
done

# commit changes (new files)
cd $ROOT/repos/$repo_name
git add tasks/*.tmx
git commit -m "Added batch TMs for finalized batches/tasks"
git push

# clean up the mess
yes | rm -r $ROOT/offline/${repo_name}_OMT/
yes | rm -r $ROOT/repos/${repo_name}/

# after that, the PISA workflow service can fetch those batch TMs and add them to the next step
