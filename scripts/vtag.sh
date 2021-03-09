#!/bin/bash

set -e

die() {
  MSG="$1"
  echo -e "$MSG\nAborting."
  exit 1
}

# Check args
unset VERSION_ARG

if [ $# -gt 0 ]; then
  VERSION_ARG="$1"
fi

# Fetch latest origin changes
echo " * Perform git fetch --all ..."
git fetch --all

# Compare local with origin
echo " * Comparing local to origin ..."

BRANCH_NAME=$( git rev-parse --symbolic-full-name --abbrev-ref HEAD 2>/dev/null )
LOCAL_REF=$( git rev-parse "$BRANCH_NAME" )
REMOTE_REF=$( git rev-parse origin/"$BRANCH_NAME" )

if [[ ! "$LOCAL_REF" == "$REMOTE_REF" ]]; then
  echo
  die "error: git ref for local $BRANCH_NAME does not match origin. Have you pulled the latest changes?"
fi

# Read last git tag
LATEST_TAG=$( git describe --abbrev=0 --tags --match v*.*.* )
echo
echo " * LAST GIT TAG: $LATEST_TAG"
echo

# Prompt for new version number
if [[ -z "$VERSION_ARG" ]]; then
  read -p "Please enter new version number: " NEW_VERSION
  echo
else
  NEW_VERSION="$VERSION_ARG"
fi

# Verify version number
if [[ ! "$NEW_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$ ]]; then
  echo "error: invalid version format: $NEW_VERSION"
  echo
  echo "New git tag should use the format: v*.*.*(-word.*)?"
  echo
  echo "Examples:"
  echo " - v0.1.2"
  echo " - v0.1.2-rc.1"
  echo " - v0.1.2-alpha.2"
  echo
  echo "Aborting."
  exit 1
fi

# Check if tag exists
if [[ $( git rev-parse -q --verify "refs/tags/$NEW_VERSION" ) ]]; then
  die "error: tag exists: $NEW_VERSION"
fi

# Create and push new tag
echo " * Creating new tag: $NEW_VERSION ..."
echo
git tag $NEW_VERSION -m "[RELMGMT: Tagged $NEW_VERSION]"
git push origin $NEW_VERSION

# Finished
echo
echo " * Done."
echo

