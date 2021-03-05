#!/bin/bash

set -e

###
# GLOBALS
###

export DOCKER_BUILDKIT=1
BUILD_ARTEFACT_PATH="artefacts/"

###
# FUNCTIONS
###

die() {
  msg="$1"
  echo -e "$msg\nAborting."
  exit 1
}

source_socat_version_value() {
  export SOCAT_VERSION=$( curl -s https://pkgs.alpinelinux.org/package/edge/main/x86/socat | \
    docker run -i --rm -v output:/apps/output alpine/html2text -nobs | \
    awk '/^Version/ {print $2}' )

  echo " * Latest socat package version: $SOCAT_VERSION"
}

source_version_value() {
  # Check for GITHUB_REF value
  if [ ! -z "$GITHUB_REF" ]; then
    echo " * Using GITHUB_REF to source docker tag name"
    BRANCH_NAME="${GITHUB_REF}"
    BRANCH_NAME=${BRANCH_NAME##"refs/tags/"}
    BRANCH_NAME=${BRANCH_NAME##"refs/heads/"}
  elif [ ! -z "$BUILD_SOURCEBRANCH" ]; then
    echo " * Using Azure Build.SourceBranch variable to source docker tag name"
    BRANCH_NAME="${BUILD_SOURCEBRANCH}"
    BRANCH_NAME=${BRANCH_NAME##"refs/tags/"}
    BRANCH_NAME=${BRANCH_NAME##"refs/heads/"}
  else
    echo " * Using 'git rev-parse' to source docker tag name"
    set +e
    BRANCH_NAME=$( git rev-parse --symbolic-full-name --abbrev-ref HEAD 2>/dev/null )
    set -e
    echo
  fi

  # Check branch name value exists and is valid
  if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" == "HEAD" ]; then
    echo "error: git project not detected, or not initalised properly"
    echo "expecting valid tag/branch name (value was either HEAD or not present)."
    exit 1
  fi

  # Apply name fix
  BRANCH_NAME=$( echo $BRANCH_NAME | tr '/' '-' )

  # Strip 'version-*' substring if present
  BRANCH_NAME=${BRANCH_NAME##"version-"}

  # Check for 'v*.*.*' tag format
  if [[ $BRANCH_NAME =~ ^v[0-9]+.[0-9]+.[0-9]+ ]]; then
    BRANCH_NAME=${BRANCH_NAME##"v"}
  fi

  export DOCKER_TAG_NAME=$BRANCH_NAME
}

generate_build_props() {
  # Check path for generated artefacts
  if [ ! -d "$BUILD_ARTEFACT_PATH" ]; then
    echo "error: folder for build artefacts does not exist: $BUILD_ARTEFACT_PATH"
    exit 1
  fi

  # Generate build-time info
  echo "{\"version\":\"$DOCKER_TAG_NAME\"}"  > $BUILD_ARTEFACT_PATH/version.json
  echo "{\"socat_version\":\"$SOCAT_VERSION\"}" >> $BUILD_ARTEFACT_PATH/version.json

  # Curious what our build system will produce here ...
  echo "{\"build_timestamp\":\"$( date +%Y-%m-%d:%H:%M:%S )\",
\"build_platform\":\"$( uname )\",
\"build_hostname\":\"$( uname -n )\",
\"build_kernel_version\":\"$( uname -v )\",
\"build_kernel_release\":\"$( uname -r )\",
\"build_architecture\":\"$( uname -m )\"}" > $BUILD_ARTEFACT_PATH/build.json
}

docker_tag() {
  IMG="$1"
  TAG="$2"

  echo " * Tagging image: $IMG:$TAG"
  docker tag $IMG:latest $IMG:$TAG
}

docker_push() {
  IMG="$1"
  TAG="$2"

  echo " * Pushing image: $IMG:$TAG ..."
  docker push $IMG:$TAG || die "error: failed to push image"
}

build() {
  # Prepare build artefacts
  generate_build_props

  # Build image
  echo " * Building image ..."
  docker build \
    --build-arg SOCAT_VERSION=$SOCAT_VERSION \
    -t $IMAGE_NAME:latest .
  echo

  # Tag image
  docker_tag $IMAGE_NAME $DOCKER_TAG_NAME

  # Debug tags
  docker_tag $IMAGE_NAME "latest-debug"
  docker_tag $IMAGE_NAME "$DOCKER_TAG_NAME-debug"

  # Special 'image_name-debug:latest' tag required for be-build.yml template
  echo " * Extra tag!"
  echo " * Tagging image: $IMAGE_NAME-debug:latest"
  docker tag $IMAGE_NAME:latest $IMAGE_NAME-debug:latest

  # Extra tags (Azure)
  if [ ! -z "$BUILD_BUILDNUMBER" ]; then
    docker_tag $IMAGE_NAME "$BUILD_BUILDNUMBER"
    docker_tag $IMAGE_NAME "$BUILD_BUILDNUMBER-debug"
  fi

  echo
}


release() {
  docker_push $IMAGE_NAME "latest"
  docker_push $IMAGE_NAME $DOCKER_TAG_NAME

  # Push debug tags
  docker_push $IMAGE_NAME "latest-debug"
  docker_push $IMAGE_NAME "$DOCKER_TAG_NAME-debug"

  # Extra tags (Azure)
  if [ ! -z "$BUILD_BUILDNUMBER" ]; then
    docker_push $IMAGE_NAME "$BUILD_BUILDNUMBER"
    docker_push $IMAGE_NAME "$BUILD_BUILDNUMBER-debug"
  fi

  echo
}

load-kind() {
  echo " * Loading image into kind cluster: $IMAGE_NAME:$DOCKER_TAG_NAME ..."
  kind load docker-image $IMAGE_NAME:$DOCKER_TAG_NAME
  echo
}


###
# MAIN
###
TASK="$1"
echo

# Source image name
if [ -z "$IMAGE_NAME" ]; then
  echo "error: env var not set: IMAGE_NAME"
  exit 1
fi

# Source tag name from git
if [ -z "$DOCKER_TAG_NAME" ]; then
  source_version_value
fi

# Source socat version from alpinelinux package manager
if [ -z "$SOCAT_VERSION" ]; then
  source_socat_version_value
fi

echo " * Using tag name: $DOCKER_TAG_NAME"
echo

# Perform build or release
if [ "$TASK" == "release" ]; then
  release
else
  build
fi

echo " * Done."
echo
