# Prune batch TMs in OmegaT projects

Scripts to prune batch TMs in OmegaT projects. Here "pruning" means removing entries which do not correspond to a specific batch. A "batch" is a subfolder under the source folder of the project.

## Getting started

1. Clone this repo in your local machine
2. Change directory to the root folder of this repo.
3. Create virtual environment
4. Install dependencies:
    - python's requirements (`pip install -r requirements.txt`)
    - openjdk version "11.0.19" (e.g. Temurin-11.0.19+7), rsync, etc. (check the bash scripts)
5. Run `bash code/setup.sh` to get the common repo, install omegat and user config files.
6. Put the names of the omegat projects in file `data/repos.txt`.
7. Run `bash code/prune_tmx.sh`. This script above will clone the repo of each omegat project, make an offline copy, run the `prune_tmx_content_per_batch.groovy` script on the project and then commit changes and clean up the mess.

