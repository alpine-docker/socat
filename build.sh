#!/usr/bin/env bash

###
# NOTE - use "make build" instead of running this script
###

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
echo "Lastest release is: ${latest}"

tags=`curl -s https://hub.docker.com/v2/repositories/${image}/tags/ |jq -r .results[].name`

for tag in ${tags}
do
  if [ ${tag} == ${latest} ];then
    sum=$((sum+1))
  fi
done

if [[ ( $sum -ne 1 ) || ( $1 == "rebuild" ) ]];then
  docker build --build-arg VERSION=${latest} --no-cache -t ${image}:${latest} .
  docker tag ${image}:${latest} ${image}:latest

  if [[ "$TRAVIS_BRANCH" == "master" ]]; then
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
    docker push ${image}:${latest}
    docker push ${image}:latest
  fi

fi
