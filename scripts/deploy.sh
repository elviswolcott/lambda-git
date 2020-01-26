#!/bin/bash
# creates the lambda layer and deploys it

# arguments:
#   - v: version of git to build (default: 2.25.0)
#   - n: name of layer to deploy to (default: lambda-git)
set -e
set -o pipefail

while getopts "v:n:" opt; do
  case $opt in
    v)
      v=$OPTARG
      ;;
    n)
      n=$OPTARG
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

version=${v:-"2.25.0"}
name=${n:-"lambda-git"}

# clean up any old resources
rm -rf ./git.zip

# build the layer
./scripts/build.sh -v $version

# get the list of regions (excluding gov regions)
get_regions () {
  echo $(aws ssm get-parameters-by-path --region "us-east-1" --path /aws/service/global-infrastructure/services/lambda/regions --query 'Parameters[].Value' --output text | tr '[:blank:]' '\n' | grep -v -e ^cn- -e ^us-gov- | sort -r)
}
regions=$(get_regions)

git config --global user.email "travis@travis-ci.com"
git config --global user.name "Travis CI"
git clone git@github.com:elviswolcott/lambda-git.git
versions=./lambda-git/VERSIONS.md

# add header to VERSIONS.md
echo "## Git \`v$version\`" >> $versions
echo "" >> $versions
echo "| Region | ARN |" >> $versions
echo "| ------ | --- |" >> $versions

# deploy the layer to each region (technichally it would be faster to upload to s3 and use the bucket, but I'd rather not bother setting that up)
for region in $regions;
do
  # publish a new version
  layerInfo=$(aws lambda publish-layer-version --layer-name "$name" --region "$region" --description "Git $version for Amazon Linux 2" --license-info "MIT" --compatible-runtimes nodejs12.x nodejs10.x python3.8 java11 --zip-file fileb://git.zip)
  layerVersion=$(echo $layerInfo | jq -r '.Version')
  arn=$(echo $layerInfo | jq -r '.LayerVersionArn')
  # add permissions so that any user can add the layer
  aws lambda add-layer-version-permission --region "$region" --layer-name "$name" --version-number "$layerVersion" --statement-id "public-access" --action "lambda:GetLayerVersion" --principal "*"
  # add the layer information to VERSIONS.md
  echo "| \`$region\` | \`$arn\` |" >> $versions
done

# commit VERSIONS.md
cd lambda-git
git checkout master
git add VERSIONS.md
git commit -m "docs: release layer for $version"
git push

