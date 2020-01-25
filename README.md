[![Travis (.com) build status](https://img.shields.io/travis/com/elviswolcott/lambda-git?logo=travis)](https://travis-ci.com/elviswolcott/lambda-git)
# `git` layer for AWS Lambda

> Build Lambda layers to add git to your functions

# Usage

> Note: The binaries are built against `amazonlinux:2` and will work with `nodejs12.x`, `nodejs10.x`,`python3.8`, and `java11`. If you are using a runtime that uses Amazon Linux, modify `Dockerfile` build `FROM amazonlinux:1`. See [Runtime OS Versions](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html) if you are not sure which OS your runtime uses.

> Warning: The layer is missing some git components that are not well suited to use in Lambda (i.e. imap-send or gui). If you need different components, `/scripts/clean-git.sh` can be modified to not remove them.

1. Add the layer to your Lambda function. The [version history](VERSIONS.md) includes all of the available ARNs.
1. Add the environment variable `GIT_EXEC_PATH` with a value of `/opt/libexec/git-core`
1. The git binary will be available as `/opt/bin/git`.

Example: Cloning a repository in NodeJS
```js
const child_process = require('child_process');

exports.handler = async (event) => {
    const result = child_process.execSync('cd /tmp ; /opt/bin/git clone https://github.com/octocat/Hello-World.git').toString();
    const response = {
        statusCode: 200,
        body: result,
    };
    return response;
};
```

In lambda `/tmp` is writeable and preserved as long as a function environment is reused.
It is recommended for your function to begin cloning any repositories into `/tmp` while it performs any additional setup. 
You can take advantage of this by checking if the repository exists already and simply pulling new changes instead of cloning when your execution environment is reused.

# Deployment

When a new tag is published to the `master` branch, Travis builds `git` from source in a container running `amazonlinux:2`.

The `git` binary is zipped and then released as a layer using the AWS CLI.

In the future, a Lambda will run using the layer to monitor for tags on the source repository. This will the layer to be updated as soon as a new version of git is released.

# Methodology
It turns out getting a git binary onto Lambda isn't easy.

Normally the best way to get a binary into your Lambda is by compiling with the `-static` flag to include shared libraries in the executable. 
Unfortunately, git uses NSS, and resultingly cannot be compiled with the `-static` flag.
While it would also be possible to obtain git through `yum` or `yumdownloader`, it ends up being a pain to work with and Amazon often does not provide the most recent version until a few months after release.

The approach used here is to build git from source in a Docker container. To reduce size, the `clean-git` script does some housekeeping like removing components that aren't needed for use in Lambda, replacing duplicate files with a symbolic link to a single copy, identifying shared libraries and making copies. These files are then zipped and copied out of the container as the Lambda Layer.

A benefit of this approach is that it is possible to modify the build process to exclude elements of git that you do not require. It can also be quickly modified to add other programs to the layer or create layers for arbitrary binaries. While it would be easier to just install through a package manager and copy everything from the container out, this approach ensures there are not unneeded libraries or other files and makes it possible to always have the latest version available.