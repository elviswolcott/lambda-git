#!/bin/bash
# builds the image and copies out the zip
set -e
set -o pipefail

# arguments:
#   - v: version of git to build
while getopts "v:" opt; do
  case $opt in
    v)
      version=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# build git in amazonlinux:2
echo "building image with git v${version}"
docker build -t amazonlinux_git --build-arg version=$version .

# create a container to run the clean script
echo "creating container to build zip"
docker create -it --name builder amazonlinux_git bash
echo "copying clean script"
docker cp ./scripts/clean-git.sh builder:/clean-git.sh

# start the container and run the script
echo "starting container and running script"
docker start builder
docker exec builder ./clean-git.sh

# copy out the zip
echo "copying out final zip"
docker cp builder:/git.zip ./git.zip

# clean up
docker stop builder
docker rm builder