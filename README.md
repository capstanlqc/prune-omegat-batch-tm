# Prune batch TMs in OmegaT projects

Utility to prune batch TMs in OmegaT projects. 

Here "pruning" means removing entries which do not correspond to a specific batch. A "batch" is a subfolder under the source folder of the project.

## Getting started

1. Clone this repo in your local machine
2. Change directory to the root folder of this repo.
3. Install dependencies if needed, e.g. openjdk version "11.0.19" (e.g. Temurin-11.0.19+7), rsync, etc. (check the bash scripts)
4. Run `bash code/setup.sh` to get the common repo, install omegat and user config files.

It is recommended to run the setup script frequently (e.g. every day), in case there have been updates in source files or omegat configuration.

## Execution

5. Put the names of the omegat projects in file `data/repos.txt`.
6. Run `bash code/prune_tmx.sh`. This script above will clone the repo of each omegat project, make an offline copy, run the `prune_tmx_content_per_batch.groovy` script on the project and then commit changes and clean up the mess.

The pruning consists in checking, for each entry in the batch TM, whether the source text exists in the related batch. In that comparison, omegat tags are stripped and space is normalized.

## Notes

The script `create_batch_tm.sh` is now superseded by script `writeTMX4batch.groovy` which runs in OmegaT upon saving and creates the batch TM in `target/tasks/{batch}.tmx`.