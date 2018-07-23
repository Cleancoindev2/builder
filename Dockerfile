# Start from the sgx-rust base image
FROM baiduxlab/sgx-rust:1.0.1

# Add all the things we need to build chainlink
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y curl git gcc libssl1.0.0 build-essential jq

# Install go 1.10.1
RUN cd /usr/local && \
  curl -sS https://dl.google.com/go/go1.10.1.linux-amd64.tar.gz | tar -xz
ENV GOPATH /go
ENV GOROOT /usr/local/go
ENV PATH $GOPATH/bin:$GOROOT/bin:$PATH
RUN mkdir -p $GOPATH/bin && mkdir $GOPATH/src

# Dep is used to manage dependencies
RUN curl -sS https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

# GPG Keys for Node and Yarn
# Release team keys published here: https://github.com/nodejs/node#release-team
RUN set -ex \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
  ; do \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
done

# Node
ENV NODE_VERSION 8.11.1

RUN curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

# Yarn
ENV YARN_VERSION 1.5.1

RUN set -ex \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
      gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
      gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
      gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz

# Install goverage to capture go test coverage
RUN go get -u github.com/haya14busa/goverage
RUN curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 \
      > "/usr/local/bin/cc-test-reporter" \
      && chmod +x "/usr/local/bin/cc-test-reporter"

# Clone the Rust SGX SDK
RUN git clone https://github.com/baidu/rust-sgx-sdk/ /opt/rust-sgx-sdk

# Install tarpaulin for rust code coverage
ENV PATH /root/.cargo/bin:$PATH
RUN RUSTFLAGS="--cfg procmacro2_semver_exempt" cargo install cargo-tarpaulin
