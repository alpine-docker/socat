#!/usr/bin/env bash

# Prerequisite
# Make sure you set secret enviroment variables in Travis CI
# DOCKER_USERNAME
# DOCKER_PASSWORD

set -ex

Usage() {
  echo "$0 [rebuild]"
}

install_jq() {
  # jq 1.6
  DEBIAN_FRONTEND=noninteractive
  #sudo apt-get update && sudo apt-get -q -y install jq
  curl -sL https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -o jq
  sudo mv jq /usr/bin/jq
  sudo chmod +x /usr/bin/jq
}

build() {

  # install crane
  curl -LO https://github.com/google/go-containerregistry/releases/download/v0.11.0/go-containerregistry_Linux_x86_64.tar.gz
  tar zxvf go-containerregistry_Linux_x86_64.tar.gz
  chmod +x crane
  
  if [[ ( "${CIRCLE_BRANCH}" == "master" ) ||( ${REBUILD} == "true" ) ]]; then

      docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
      docker buildx create --use
      docker buildx build --push \
        --platform linux/arm/v7,linux/arm64/v8,linux/arm/v6,linux/amd64,linux/ppc64le,linux/s390x \
        --build-arg VERSION=${latest} \
        -t ${image}:${latest} \
        -t ${image}:latest .
  
      ./crane copy ${image}:${tag} ${image}:latest
  
  
  fi
}

image="alpine/socat"

docker build -t socat . 

latest=`docker run -t --rm socat -V|awk '$1=$1' |awk '/socat version/{print $3}'`

echo "Latest release is: ${latest}"

status=$(curl -sL https://hub.docker.com/v2/repositories/${image}/tags/${tag})
echo $status

if [[ ( "${status}" =~ "not found" ) ||( ${REBUILD} == "true" ) ]]; then
   echo "build image for ${tag}"
   build
fi
