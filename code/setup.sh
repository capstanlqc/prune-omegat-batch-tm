#!/usr/bin/env bash

# this script sets up omegat, ready to be run in console mode
# this script downloads/syncs common files

# run as 
# code code/setup.sh

# set root path
# this will be /path/to/omegat-project-tm-pruning-service if called as above
ROOT="$(pwd)"

# install and compile omegat
gh repo clone capstanlqc/omegat
cd omegat
git checkout releases/5.7.2-capstan
./gradlew installDist
cd $ROOT

# install omegat config files
gh repo clone capstanlqc/omegat-user-config-dev572 $ROOT/config
cp $ROOT/config/version_notes.txt $ROOT/config/local_version_notes.txt

# download/sync common files
mkdir -p $ROOT/repos
domain="https://git-codecommit.eu-central-1.amazonaws.com/v1/repos"
common_repo="pisa_2025ft_translation_common"
[ -d repos/$common_repo ] && cd $ROOT/repos/$common_repo && git pull
[ -d repos/$common_repo ] || git clone $domain/$common_repo.git $ROOT/repos/$common_repo

# other requirements
# java 11