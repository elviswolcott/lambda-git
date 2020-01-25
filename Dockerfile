FROM amazonlinux:2 AS build_image
ARG version=2.25.0

# everything required to build git from scratch
RUN yum install -y autoconf dh-autoreconf curl-devel expat-devel gettext-devel openssl-devel perl-devel zlib-devel getopt make gcc gcc-c++ tar wget nss zip

# removing any existing installation
RUN yum remove git -y
RUN rm -rf /bin/git /usr/libexec/git-core

# download release of source
RUN wget https://github.com/git/git/archive/v${version}.tar.gz 
RUN tar xvzf v${version}.tar.gz -C /tmp

RUN mkdir /git

WORKDIR /tmp/git-${version}

# build from source
RUN make configure
# by optimizing for size, the layer goes from ~40MB to ~8MB
RUN ./configure prefix="/git" CFLAGS="${CFLAGS} -Os"
RUN make
RUN make install

WORKDIR /

# git should now be installed and built from source