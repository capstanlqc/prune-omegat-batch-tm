#!/usr/bin/env bash

# requires java 11

# cd to root folder of the repo
# ROOT is then expected to be /path/to/omegat-project-tm-pruning-service
# run as:
# bash code/prune_tmx.sh

ROOT="$(pwd)"
mkdir -p $ROOT/repos
mkdir -p $ROOT/offline
common="${common_repo_path:-$ROOT/repos/pisa_2025ft_translation_common}"
omegat_bin_path="${omegat_bin_path:-$ROOT/omegat/build/install/OmegaT}"
config_dir_path="${omegat_config_dir_path:-$ROOT/config}"


# @todo (maybe): change this value to "workflow" to overwrite the old file
output_dir="tasks"

# permanent params
domain="codecommit:/"

# repo names to process should be added in data/repos.txt

repo_name=pisa_2025${space}_translation_${locale}_${step}
repo_url=$domain/$repo_name.git

prune_tmx () {
    local project_root=$1
	local origin_folder=$2
	local destination_folder=$3
	local batch_name=$4
	
	if ! [ -f $project_root/$destination_folder/$batch_name.tmx.before-prune ]; then
		# add batch
		cp -r $common/source/$batch_name $project_root/source
		
		# Use the batch tm as the working TM of the project.
		mv $project_root/omegat/project_save.tmx $project_root/omegat/project_save.tmp
		cp $project_root/$origin_folder/$batch_name.tmx $project_root/omegat/project_save.tmx

		# create batch master TM
		java -jar $omegat_bin_path/OmegaT.jar $project_root --mode=console-translate --config-dir=$config_dir_path
		
		# Restore working TM
		mv -f $project_root/omegat/project_save.tmp $project_root/omegat/project_save.tmx

		# Make sure destination folder exists
		mkdir -p $destination_folder

		# rename destination file if it's the same as source (also a nice way to know what was already pruned)
		if [ "$origin_folder" = "$destination_folder" ] && [ -f $project_root/$destination_folder/$batch_name.tmx ]; then
			mv $project_root/$destination_folder/$batch_name.tmx $project_root/$destination_folder/$batch_name.tmx.before-prune
		fi

		# Copy batch master TM to repo
		local filename=(*-omegat.tmx)
		cp $project_root/$filename $project_root/$destination_folder/$batch_name.tmx
		# @todo (probably): replicate the path where the original batch TM is found under workflow, e.g. 
		# ${repo_name}/${output_dir}/tm/auto/prev/$batch.tmx

		# delete batch folder  before adding the next one
		yes | rm -r $project_root/source/$batch
	else
		echo "Batch $batch_name was already pruned earlier, skipping."
	fi
}

for repo_name in $(cat $ROOT/data/repos.txt)
do
    echo ""
	echo "=================================================================================================================================="
    cd $ROOT
    echo ">>> HANDLING $repo_name "

    # get locale
    locale=$(echo $repo_name | cut -d"_" -f4)
    echo "LOCALE: $locale"

    # repo_name=pisa_2025${space}_translation_${locale}_${step}
    repo_url=$domain/$repo_name.git

    # clone project repo
    echo "git clone --depth 1 $repo_url 1 repos/$repo_name"
    [ -d $ROOT/repos/$repo_name ] || git clone --depth 1 $repo_url $ROOT/repos/$repo_name

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

    ## from previous version, just ignore (kept for historic/future reasons)
    ## batches=()
    ## while IFS= read -r line; do
    ##     batches+=( "$line" )
    ## done < <( xmlstarlet select -t -c "//mapping[contains(@local, 'source')]" $ROOT/repos/$repo_name/omegat.project | grep -Poh '(?<=local="source/)[^"]+' )

    # Prune /tm/auto/
	batch_tms="$(find $ROOT/offline/${repo_name}_OMT/tm/auto/ -type f -regextype egrep -regex '.*/(prev|next)/([0-9]{2}_[-_a-zA-Z]+_[NT]).tmx')"
    for tmx_filepath in $batch_tms; 
    do
		src_dir=$(dirname $tmx_filepath)
		tm_dir=$(realpath --relative-to="${ROOT}/offline/${repo_name}_OMT" $src_dir)
		batch_name=$(basename $tmx_filepath | cut -d'.' -f1)
		echo ""
		echo "----------------------------------------------------------------------------------------------------------------------------------"
		echo "Processing $batch_name in $tm_dir..."
		
		# We are pruning the TM's received from the previous or next workflow steps. Batch TMs (found in /tm/auto/prev|next/) in the current locale
		# should only have segments from the batch they were produced in.
		prune_tmx "${ROOT}/offline/${repo_name}_OMT" $tm_dir $tm_dir $batch_name
		
		# The result file is $tmx_filepath (because we are overwriting the offline copy above), now we can copy that into the real repo.
		# We're also copying ${batch_name}.tmx.before-prune if present
		cp $tmx_filepath $ROOT/repos/$repo_name/$tm_dir
		cp "${tmx_filepath}.before-prune" $ROOT/repos/$repo_name/$tm_dir
    done
	# Commit
    cd $ROOT/repos/$repo_name
    ## git add tm/auto
    ## git commit -m "Pruned TMs in tm/auto"

    # Prune /workflow/tm/auto/
    workflow_tms="$(find $ROOT/offline/${repo_name}_OMT/workflow/tm/auto/ -type f -regextype egrep -regex '.*/(prev|next)/([0-9]{2}_[-_a-zA-Z]+_[NT]).tmx')"
    for tmx_filepath in $workflow_tms; 
    do
		src_dir=$(dirname $tmx_filepath)
		tm_dir=$(realpath --relative-to="${ROOT}/offline/${repo_name}_OMT" $src_dir)
		batch_name=$(basename $tmx_filepath | cut -d'.' -f1)
		echo ""
		echo "----------------------------------------------------------------------------------------------------------------------------------"
		echo "Processing $batch_name in $tm_dir..."
		
		# We are pruning the Workflow TMs - to be on the safe side?
		prune_tmx "${ROOT}/offline/${repo_name}_OMT" $tm_dir $tm_dir $batch_name
		
		# The result file is $tmx_filepath (because we are overwriting the offline copy above), now we can copy that into the real repo.
		# We're also copying ${batch_name}.tmx.before-prune if present
		cp $tmx_filepath $ROOT/repos/$repo_name/$tm_dir
		cp "${tmx_filepath}.before-prune" $ROOT/repos/$repo_name/$tm_dir
    done
	# Commit
    cd $ROOT/repos/$repo_name
    ## git add workflow/tm/auto
    ## git commit -m "Pruned TMs in workflow/tm/auto"
    
    # Push changes (new files)
    ## git push
    
    # clean up the mess
    ## yes | rm -r $ROOT/offline/${repo_name}_OMT/
    ## yes | rm -r $ROOT/repos/${repo_name}/

done
# after that, the PISA workflow service can fetch those batch TMs and add them to the next step