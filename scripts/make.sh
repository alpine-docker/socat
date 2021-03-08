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

# Error if env var not found
check_env_var() {
  VAR_NAME=$1
  VAR_VALUE=$2

  if [ -z "${VAR_VALUE}" ]; then
    die "error: environment variable not found: ${VAR_NAME}"
  fi
}

# Lookup latest socat version from alpinelinux packages
source_socat_version_value() {
  export SOCAT_VERSION=$( curl -s https://pkgs.alpinelinux.org/package/edge/main/x86/socat | \
    docker run -i --rm -v output:/apps/output alpine/html2text -nobs | \
    awk '/^Version/ {print $2}' )

  echo " * Latest socat package version: $SOCAT_VERSION"
}

# Determine DOCKER_TAG_NAME value
source_version_value() {
  # Check if building off tag in Azure
  if [[ $BUILD_SOURCEBRANCH == refs/tags/* ]]; then
    echo " * Azure BUILD_SOURCEBRANCH env var with tag value detected: $BUILD_SOURCEBRANCH"

    # Clean up tag name
    TAG_NAME=${BUILD_SOURCEBRANCH##"refs/tags/"}

    # Use as docker image version
    export DOCKER_TAG_NAME="$TAG_NAME"

  else
    # Source version via git describe (borrowed from spice project)
    echo " * Using 'git describe' to source version value"
    set +e
    GIT_DESCRIBE=$( git describe --always --tags --long 2> /dev/null )
    set -e
    echo

    # Check branch name value exists and is valid
    if [ -z "$GIT_DESCRIBE" ]; then
      die "error: git project not detected, or not initalised properly"
    fi

    # Use as docker image version
    export DOCKER_TAG_NAME=$GIT_DESCRIBE
  fi
}

# Include build information within image
generate_build_props() {
  # Check path for generated artefacts
  if [ ! -d "$BUILD_ARTEFACT_PATH" ]; then
    echo "error: folder for build artefacts does not exist: $BUILD_ARTEFACT_PATH"
    exit 1
  fi

  # Generate build-time info
  echo -n "{\"version\":\"$DOCKER_TAG_NAME\", "  > $BUILD_ARTEFACT_PATH/version.json
  echo "\"socat_version\":\"$SOCAT_VERSION\"}" >> $BUILD_ARTEFACT_PATH/version.json

  # Curious what our build system will produce here ...
  echo "{\"build_timestamp\":\"$( date +%Y-%m-%d:%H:%M:%S )\",
\"build_platform\":\"$( uname )\",
\"build_hostname\":\"$( uname -n )\",
\"build_kernel_version\":\"$( uname -v )\",
\"build_kernel_release\":\"$( uname -r )\",
\"build_architecture\":\"$( uname -m )\"}" > $BUILD_ARTEFACT_PATH/build.json
}

# Tag a docker image
docker_tag() {
  IMG="$1"
  TAG="$2"

  echo " * Tagging image: $IMG:$TAG"
  docker tag $IMG:latest $IMG:$TAG
}

# Push a docker image
docker_push() {
  IMG="$1"
  TAG="$2"

  echo " * Pushing image: $IMG:$TAG ..."
  docker push $IMG:$TAG || die "error: failed to push image"
}


# Make build
run_build() {
  echo " * Building image ..."

  # Source socat version from alpinelinux package manager
  if [ -z "$SOCAT_VERSION" ]; then
    source_socat_version_value
  fi
  
  # Prepare build artefacts
  generate_build_props

  # Build image
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


# make test
run_test() {
  echo " * Testing static docker image: $IMAGE_NAME:$DOCKER_TAG_NAME ..."

  # Simple test: check socat version
  docker run --rm \
    --entrypoint=socat \
    $IMAGE_NAME:$DOCKER_TAG_NAME \
    -V | head -2
}

# make testruntime
run_testruntime() {
  echo " * Testing runtime docker instance: $IMAGE_NAME:$DOCKER_TAG_NAME ..."

  # Create socat tunnel and test 
  docker run --rm \
    --entrypoint=/tmp/test-socat.sh \
    $IMAGE_NAME:$DOCKER_TAG_NAME
}


# Make release
run_release() {
  echo " * Releasing docker image: $IMAGE_NAME:$DOCKER_TAG_NAME ..."

  # Push latest tags
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
check_env_var "IMAGE_NAME" $IMAGE_NAME

# Source tag name from git
if [ -z "$DOCKER_TAG_NAME" ]; then
  source_version_value
fi

echo " * Using tag name: $DOCKER_TAG_NAME"
echo

# Perform task, default to "make build"
case $TASK in
  "test" | "testruntime" | "release" )
    run_$TASK;;

  *)
    run_build
esac

echo " * Done."
echo
