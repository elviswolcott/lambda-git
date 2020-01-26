#!/bin/bash
# runs in an clean amazonlinux box to pull in the git zip and test it\
set -e
set -o pipefail

# need to unzip the git files
if [ "$TRAVIS" = true ] ;
then
  echo -e "travis_fold:start:install_unzip\033[33;1minstalling unzip on test container\033[0m"
fi
yum install unzip -y
if [ "$TRAVIS" = true ] ;
then
  echo -e "\ntravis_fold:end:install_unzip\r"
fi


if [ "$TRAVIS" = true ] ;
then
  echo -e "travis_fold:start:unzip_git\033[33;1munzipping git on test container\033[0m"
fi
mkdir /git
unzip git.zip -d /git
if [ "$TRAVIS" = true ] ;
then
  echo -e "\ntravis_fold:end:unzip_git\r"
fi

# get the version
echo "checking version"
/git/bin/git --version
# try cloning a repo
echo "cloning sample repository"
/git/bin/git clone https://github.com/octocat/Hello-World
cd Hello-World
# git config needs to be used locally for lambda
echo "configuring git"
/git/bin/git config --local user.name "Docker"
/git/bin/git config --local user.email "docker@example.com"
# commiting a change
echo "committing a change"
echo "TEST" > test.md
/git/bin/git add .
/git/bin/git commit -m "make a commit"
# adding a tag
echo "tagging a commit"
/git/bin/git tag "tag"
# changes AREN'T pushed, we're trusting that it works
