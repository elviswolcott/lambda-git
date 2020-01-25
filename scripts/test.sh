#!/bin/bash
# tests that git.zip works
set -e
set -o pipefail

while getopts "bv:" opt; do
  case $opt in
    b)
      echo "building new image" >&2
      # build an image that builds git from source
      rm -rf ./git.zip
      ./scripts/build.sh -v ${version:-"2.25.0"}
      ;;
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

# start a fresh amazonlinux image
echo "starting fresh container"
docker create -it --name tester amazonlinux:2 bash

# copy over the image and test script
echo "copying test script and zip"
docker cp ./git.zip tester:./git.zip
docker cp ./scripts/test-git.sh tester:/test-git.sh

# run the script in the container
echo "starting container and running test"
docker start tester
docker exec tester ./test-git.sh

# cleanup
docker stop tester
docker rm tester