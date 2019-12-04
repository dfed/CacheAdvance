#!/bin/bash -l
set -ex

# Find the directory in which this script resides.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $ACTION == "swift-package" ]; then
  $DIR/build.swift $SDK "$DESTINATION" $SHOULD_TEST $ENABLE_CODE_COVERAGE
fi

if [ $ACTION == "pod-lint" ]; then
  bundle exec pod lib lint --verbose --fail-fast --swift-version=$SWIFT_VERSION
fi

if [ $ACTION == "carthage" ]; then
  swift package generate-xcodeproj --output generated/
  carthage build --project-directory generated/ --verbose --no-skip-current
fi
