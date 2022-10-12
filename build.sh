#!/usr/bin/env bash

# Prerequisite
# Make sure you set secret enviroment variables in Travis CI
# DOCKER_USERNAME
# DOCKER_PASSWORD

set -ex

Usage() {
  echo "$0 [rebuild]"
}

image="alpine/socat"

#curl -s https://pkgs.alpinelinux.org/package/edge/main/x86/socat |tee output
#docker run -i --rm -v output:/apps/output alpine/html2text -nobs < output > report

curl -s https://pkgs.alpinelinux.org/package/edge/main/x86/socat | docker run -i --rm -v output:/apps/output alpine/html2text -nobs  > report

latest=$(awk '/^Version/ {print $2}' report)

sum=0
echo "Latest release is: ${latest}"

tags=`curl -s https://hub.docker.com/v2/repositories/${image}/tags/ |jq -r .results[].name`

for tag in ${tags}
do
  if [ ${tag} == ${latest} ];then
    sum=$((sum+1))
  fi
done

if [[ ( $sum -ne 1 ) || ( $1 == "true" ) ]];then
  docker build --build-arg VERSION=${latest} --no-cache -t ${image}:${latest} .

  if [[ "$TRAVIS_BRANCH" == "master" ]]; then
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
    # docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
    docker buildx create --use
    docker buildx build --push \
      --platform linux/arm/v7,linux/arm64/v8,linux/arm/v6,linux/amd64,linux/ppc64le,linux/s390x \
      --build-arg VERSION=${latest} \
      -t ${image}:${latest} \
      -t ${image}:latest .
  fi

fi
