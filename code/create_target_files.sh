#!/usr/bin/env bash

# requires java 11

echo "Tool to create target files using enforced TM files from a PISA project and only one TM file at a time (from a given directory)."
echo ""
echo "Usage:"
echo "${0} <path-to-pisa-project> <path-to-tm-files>"
echo ""
echo "Will load some parameters (language, enforced TM files) from the PISA project found in ${1:-<path-to-pisa-project>},"
echo "then enumerates all tmx files within the ${2:-<path-to-tm-files>} folder and using only one TM at a time, creates the target files and saves it into output."
echo ""

ROOT="$(dirname ${0})"
common="${common_repo_path:-$ROOT/repos/pisa_2025ft_translation_common}"
omegat_bin_path="${omegat_bin_path:-$ROOT/omegat/build/install/OmegaT}"
config_dir_path="${omegat_config_dir_path:-$ROOT/config}"

if [ -z "${1}" ] ; then
	echo "ERROR: First parameter needs to be a path to a valid PISA repository"
	echo ""
	exit
fi
if ! [ -d "${1}" ] ; then
	echo "ERROR: ${1} is not a directory. Please point it to a valid PISA repository folder."
	echo ""
	exit
fi
if ! [ -f "${1}/omegat.project" ] ; then
	echo "ERROR: ${1} is not an OmegaT project!"
	echo ""
	exit
fi
if [ -z "${2}" ] ; then
	echo "ERROR: Second parameter needs to be a relative path to a set of TM files in the project"
	echo ""
	exit
fi
if ! [ -d "${1}/${2}" ] ; then
	echo "ERROR: ${1}/${2} is not a directory. Please point it to a valid PISA repository folder."
	echo ""
	exit
fi

# Create required folders
mkdir -p temp
mkdir -p output
# Clean output folder
find output -mindepth 1 -depth -delete

# Determine project language
language1=$(grep -Po '(?<=\<!ENTITY\sTARGET_LANG\s")([-_a-zA-Z0-9]+)(?="\>)' "${1}/omegat.project")
language2=$(grep -Po '(?<=\<target_lang\>)([-_a-zA-Z0-9]+)(?=\</target_lang\>)' "${1}/omegat.project")
if [ -n "${language1}" ] ; then
	language="${language1}"
elif [ -n "${language2}" ] ; then
	language="${language2}"
else
	echo ""
	echo "ERROR: Failed to determine language from ${1}/omegat.project"
	echo ""
	exit
fi

# Setup temp project
cp -r $ROOT/../omt-template/* temp
cp $common/config/* temp/omegat
sed -i -e "s/OMT-LANG-PLACEHOLDER/${language}/g" temp/omegat.project

# Enumerate TMX files
for tmx_filepath in $(find ${1}/${2} -name '*.tmx' -print); 
do
	tmx_filename=$(basename "${tmx_filepath}")
	batch_name=$(basename "${tmx_filename}" .tmx)
	echo "tmx_filepath = $tmx_filepath"
	echo "tmx_filename = $tmx_filename"
	echo "batch_name = $batch_name"
	
	# Clean project first
	find temp/source -mindepth 1 -depth -delete
	find temp/tm -mindepth 1 -depth -delete
	
	# Check we're not doing something unexpected
	if [ -d "${common}/source/${batch_name}" ] ; then
		# Add source from common repo
		cp -r "${common}/source/${batch_name}" "temp/source/${batch_name}"
		
		# Copy enforced TMs - we might not want this - always?
		if [ -d "${1}/tm/enforce" ] ; then
			cp -r "${1}/tm/enforce" temp/tm/enforce
		fi

		# Add DNT TM from common repo
		mkdir -p temp/tm/enforce/dnt
		find "${common}/assets/dnt/markup" -name "*_${language}.tmx*" -exec cp {} temp/tm/enforce/dnt \;

		# Use the TMX file as the working TM for the project
		cp "${tmx_filepath}" temp/omegat/project_save.tmx

		# Create target files
		java -jar "${omegat_bin_path}/OmegaT.jar" temp --mode=console-translate --config-dir=$config_dir_path

		# Save results
		cp -r "temp/target/${batch_name}" "output/${batch_name}"

	else
		echo ""
		echo "ERROR: ${common}/source/${batch_name} is not found, is ${batch_name} a valid batch name (derived from ${tmx_filename})?"
		echo ""
	fi
	
done

# Delete temp project
rm -rf temp
