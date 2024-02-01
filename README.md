# Prune batch TMs in OmegaT projects

Utility to prune batch TMs in OmegaT projects. 

Here "pruning" means removing entries which do not correspond to a specific batch. A "batch" is a subfolder under the source folder of the project.

## Getting started

1. Clone this repo in your local machine
2. Change directory to the root folder of this repo.
3. Install dependencies if needed, e.g. openjdk version "11.0.19" (e.g. Temurin-11.0.19+7), rsync, etc. (check the bash scripts)
4. Run `bash code/setup.sh` to get the common repo, install omegat and user config files.

It is recommended to run the setup script frequently (e.g. every day), in case there have been updates in source files or omegat configuration.

## First approach: prune existing TMs

5. Put the names of the omegat projects in file `data/repos.txt`.
6. Run `bash code/prune_tmx.sh`. This script above will clone the repo of each omegat project, make an offline copy, run the `prune_tmx_content_per_batch.groovy` script on the project and then commit changes and clean up the mess.

The pruning consists in checking, for each entry in the batch TM, whether the source text exists in the related batch. In that comparison, omegat tags are stripped and space is normalized.

## Second approach: create batch TMs from scratch again

The approach above (pruning existing TMs is time-consuming). A better approach can be to create the (alreayd pruned) batch TMs from scratch, using the (unpruned) batch TMs creatd when the batch was finalized at the step. 

5. Put the names of the omegat projects in file `data/repos.txt`.
6. Run `bash code/create_batch_tm.sh`. This script will clone the repo of each omegat project, make an offlin copy, for each batch (found under `workflow/tm/auto/{prev,next}/`) run omegat on the project to produce the master/batch TM for that batch, then commit new files and clean the mess.

In a nutshell, the steps are:

- clone the project
- make an offline copy
- in the offline copy, replace the working TM with the batch TM
    > e.g. replace `omegat/project_save.tmx` with `workflow/tm/auto/prev/{batch}.tmx`
- run OmegaT on the project to produce the three master TMs
- replace the original unpruned TM in the repo with the pruned one created now
    > e.g. replace `{repo}/workflow/tm/auto/prev/{batch}.tmx` with `{offline_copy}/{offline_copy}-omegat.tmx`

The first approach above can be used in testing to confirm that the results of the second appraoch are the same.

## Notes

The script `create_batch_tm.sh` was originally conceived as a service, but it is now superseded by script `writeTMX4batch.groovy` which runs in OmegaT upon saving and creates the batch TM in `target/tasks/{batch}.tmx`.

## Credentials

It's possible to configure AWS to avoid having to type credentials in each git action. Info [here](https://github.com/capstanlqc/mk-omegat-team-projs/blob/master/docs/notes.txt).