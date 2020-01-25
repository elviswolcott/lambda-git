#!/bin/bash
# cleans up the git build by removing unused files and replacing duplciate files before zipping
set -e
set -o pipefail

# remove some things we don't need (you can change this to tweak what features you have included)
echo "removing templates"
cd /git/share
rm -rf git-gui gitk gitweb locale perl5 git-core/templates
mkdir -p git-core/templates
echo "removing git-gui components"
cd /git/libexec/git-core
rm -rf git-citool git-gui git-gui--askpass
echo "removing git-daemon components"
rm -rf git-daemon
echo "removing git-imap-send components"
rm -rf git-imap-send
echo "removing git-credential components"
rm -rf git-credential-cache git-credential-cache--daemon git-credential-store git-credential
echo "removing extra git-remote components"
rm -rf git-remote-ftp git-remote-ftps git-remote-testsvn
echo "removing git-cvsserver components"
rm -rf git-cvsserver
echo "removing git-add--interactive components"
rm -rf git-add--interactive

# look for duplicate files (by inode) and replace with symlinks
dupes () {
  set -e
  set -o pipefail
  sourceFile=$(stat -c '%i' $1)
  checkFile=$(stat -c '%i' $2)
  echo "$1($sourceFile),$2($checkFile)"
  if [ $(realpath $1) == $(realpath $2) ]
  then
    echo "not linking to self ($2 -> $1)"
    return
  fi

  if [ $sourceFile -eq $checkFile ]
  then
    # remove the copy
    rm $2
    # find the path of source relative to check
    relativeTo=$(dirname $2)
    linkTo=$(realpath --relative-to $relativeTo $1)
    # create the link
    ln -s $linkTo $2
    echo "linked: $2 -> $linkTo"
  fi
}
export -f dupes

# find all the duplicates of the git binary and replace them with symlinks
gitPath=/git/bin/git
export gitPath=$gitPath
cd /git
echo "replacing duplicate files with symlinks"
find . -type f  | xargs -I {} bash -c 'dupes $gitPath {}'

# copy a library and symlinked file
cplib () {
  set -e
  set -o pipefail
  dest=$(echo "$1" | sed 's|/lib64|./lib|g')
  cp $1 $dest
  targetFile=$(realpath $1)
  targetDest=$(echo "$targetFile" | sed 's|/lib64|./lib|g' | sed 's|/usr|/|g' )
  if [ "$targetFile" != "$1" ]
  then
    # symlink
    cp $targetFile $targetDest
    echo "copied $targetFile"
  fi
  echo "copied $1"
}
export -f cplib
# find the depdencies using ldd and copy them over, resolving symlinks
deps () {
  # get dependencies using ldd and remove some invalid strings
  deps=$(ldd $1 | awk 'NF == 4 {print $3}; NF == 2 {print $1}' | sed '/dynamic/d' | sed '/statically/d' | sed '/linux-vdso\.so\.1/d' | xargs -I {} bash -c 'cplib {}' )
  echo "copying depdencies for $1 $deps"
}
export -f deps

echo "copying libraries into /lib"
mkdir /git/lib
find . -type f -executable | xargs -I {} bash -c 'deps {}'

# zip up git
zip -y -r ../git.zip ./

curl -s -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Travis-API-Version: 3" "Authorization: token vZd6GrgxiYgt0afIBOMGyQ" -d "{\"quiet\": true}" https://api.travis-ci.com/job/279981666/debug