#!/usr/bin/env bash

# requires java 11

# cd to root folder of the repo
# ROOT is then expected to be /path/to/omegat-project-tm-pruning-service
# run as:
# bash code/prune_tmx.sh

ROOT="$(pwd)"
common="${common_repo_path:-$ROOT/repos/pisa_2025ft_translation_common}"
omegat_bin_path="${omegat_bin_path:-$ROOT/omegat/build/install/OmegaT}"
config_dir_path="${omegat_config_dir_path:-$ROOT/config}"
tmx_backup_folder=$ROOT/tmx_backup

mkdir -p $ROOT/repos
mkdir -p $ROOT/offline
mkdir -p $tmx_backup_folder

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
	batch_tmx_filepath=($project_root/$origin_folder/$batch_name.tmx*) # to match both .tmx and .tmx.idle
	batch_tmx_filename="$(basename $batch_tmx_filepath)"
	
	if ! [ -f $project_root/$destination_folder/$batch_tmx_filename.before-prune ]; then
		# add batch
		find $project_root/source -mindepth 1 -depth -delete
		cp -r $common/source/$batch_name $project_root/source/$batch_name
		
		# Use the batch tm as the working TM of the project.
		mv $project_root/omegat/project_save.tmx $project_root/omegat/project_save.tmp
		cp $batch_tmx_filepath $project_root/omegat/project_save.tmx

		# create batch master TM
		java -jar $omegat_bin_path/OmegaT.jar $project_root --mode=console-translate --config-dir=$config_dir_path

		# Make sure destination folder exists
		mkdir -p $destination_folder

		# rename destination file if it's the same as source (also a nice way to know what was already pruned)
		# @MS: how could it be that "$origin_folder" = "$destination_folder" are not the same??
		# @gergoe: If you'd call this function with a different parameters. In our use case it's the same indeed.
		if [ "$origin_folder" = "$destination_folder" ] && [ -f $project_root/$destination_folder/$batch_tmx_filename ]; then
			mv $project_root/$destination_folder/$batch_tmx_filename $project_root/$destination_folder/$batch_tmx_filename.before-prune
		fi

		# Copy batch master TM to repo
		local master_tmx_filename=(*-omegat.tmx)
		cp $project_root/$master_tmx_filename $project_root/$destination_folder/$batch_tmx_filename
		# @todo (probably): replicate the path where the original batch TM is found under workflow, e.g. 
		# ${repo_name}/${output_dir}/tm/auto/prev/$batch.tmx

		# Restore working TM
		mv -f $project_root/omegat/project_save.tmp $project_root/omegat/project_save.tmx
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
	find $ROOT/repos/$repo_name -depth -delete
    git clone --depth 1 $repo_url $ROOT/repos/$repo_name

    # if no repo exists (e.g. returned error 403, skip)
    [ -d repos/$repo_name ] || continue

    # skip if it's not an omegat project
    [ -f repos/$repo_name/omegat.project ] || continue

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
	
	# We do cheat here; As we don't keep a copy of the .before-prune files in the repositories
	# but I intend to keep them as indicators whether pruning was ran on a certain tmx file or not,
	# I'm going to see if we made a backup earlier (in the "offline" backup folder) and copy it back to the
	# offline project here, so the prune_tmx function can pick it up.
	if [ -d $tmx_backup_folder/$repo_name ]; then
		cp -r -u $tmx_backup_folder/$repo_name $ROOT/offline/${repo_name}_OMT
	fi

    # now get source files

    ## from previous version, just ignore (kept for historic/future reasons)
    ## batches=()
    ## while IFS= read -r line; do
    ##     batches+=( "$line" )
    ## done < <( xmlstarlet select -t -c "//mapping[contains(@local, 'source')]" $ROOT/repos/$repo_name/omegat.project | grep -Poh '(?<=local="source/)[^"]+' )

    # Prune /tm/auto/
    mkdir -p $ROOT/offline/${repo_name}_OMT/tm/auto/ # it will be empty if it didn't exist
	batch_tms="$(find $ROOT/offline/${repo_name}_OMT/tm/auto/ -type f -regextype egrep -regex '.*/(prev|next)/[0-9]{2}_[-_a-zA-Z]+_[NT]\.tmx(\.idle)?')"
    echo "batch_tms: $batch_tms"
    for tmx_filepath in $batch_tms; 
    do
		echo "tmx_filepath: $tmx_filepath"
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
		cp $tmx_filepath $ROOT/repos/$repo_name/$tm_dir

		# We're also copying ${batch_name}.tmx.before-prune if present into the external backup folder
		if [ -f "${tmx_filepath}.before-prune" ]; then
			mkdir -p $tmx_backup_folder/$repo_name/$tm_dir
			cp "${tmx_filepath}.before-prune" $tmx_backup_folder/$repo_name/$tm_dir
		fi

		# Earlier we did copy the backup to the repo itself, we don't do that anymore.
		#cp "${tmx_filepath}.before-prune" $ROOT/repos/$repo_name/$tm_dir
    done
	# Commit
    cd $ROOT/repos/$repo_name
    git add tm/auto
    git commit -m "Pruned TMs in tm/auto"

    # Prune /workflow/tm/auto/
    mkdir -p $ROOT/offline/${repo_name}_OMT/workflow/tm/auto/ # it will be empty if it didn't exist
    workflow_tms="$(find $ROOT/offline/${repo_name}_OMT/workflow/tm/auto/ -type f -regextype egrep -regex '.*/(prev|next)/[0-9]{2}_[-_a-zA-Z]+_[NT]\.tmx(\.idle)?')"
    for tmx_filepath in $workflow_tms; 
    do
		src_dir=$(dirname $tmx_filepath)
		tm_dir=$(realpath --relative-to="${ROOT}/offline/${repo_name}_OMT" $src_dir)
		batch_name=$(basename $tmx_filepath | cut -d'.' -f1)
		echo ""
		echo "----------------------------------------------------------------------------------------------------------------------------------"
		echo "Processing $batch_name in $tm_dir..."
		
		# We are pruning the Workflow TMs - to be on the safe side?
		# @MS: because if these TMs under workflow aren't pruned too, they will undo what you did above when they are added to the next (or prev) step
		# @gergoe: No idea when they overwrite copies in workflow (I hope always), so it's really just a safety measure. Perhaps when skipping step then they use this file?
		prune_tmx "${ROOT}/offline/${repo_name}_OMT" $tm_dir $tm_dir $batch_name
		
		
		# The result file is $tmx_filepath (because we are overwriting the offline copy above), now we can copy that into the real repo.
		# We're also copying ${batch_name}.tmx.before-prune if present
		cp $tmx_filepath $ROOT/repos/$repo_name/$tm_dir

		# We're also copying ${batch_name}.tmx.before-prune if present into the external backup folder
		if [ -f "${tmx_filepath}.before-prune" ]; then
			mkdir -p $tmx_backup_folder/$repo_name/$tm_dir
			cp "${tmx_filepath}.before-prune" $tmx_backup_folder/$repo_name/$tm_dir
		fi
		
		# Earlier we did copy the backup to the repo itself, we don't do that anymore.
		#cp "${tmx_filepath}.before-prune" $ROOT/repos/$repo_name/$tm_dir
    done
	# Commit
    cd $ROOT/repos/$repo_name
    git add workflow/tm/auto
    git commit -m "Pruned TMs in workflow/tm/auto"
    
    # Push changes (new files)
    git push
    
    # clean up the mess
    yes | rm -r $ROOT/offline/${repo_name}_OMT/
    yes | rm -r $ROOT/repos/${repo_name}/

done
# after that, the PISA workflow service can fetch those batch TMs and add them to the next step