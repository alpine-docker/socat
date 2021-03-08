#!/usr/bin/env make

include Makehelp.mk

export IMAGE_NAME ?= mx51io/alpine-socat
IMAGE = $(IMAGE_NAME):latest


## Compile code and create docker image
build:
	./scripts/make.sh build
PHONY: build


## Runs a simple test against the built image
test:
	docker run --rm --entrypoint=socat $(IMAGE) -V | head -2
	@echo "All tests completed successfully"
PHONY: test


## Executes a simple socat test within a running docker instance
testruntime:
	docker run --rm --entrypoint=/tmp/test-socat.sh $(IMAGE)
	@echo "All tests completed successfully"
PHONY: testruntime


## Tag and push new docker image to docker hub
release:
	./scripts/make.sh release
PHONY: release


## Deletes docker image locally
clean:
	docker image rm -f $(IMAGE) 2>/dev/null
PHONY: clean


## Create and push new Git tag
tag:
	./scripts/vtag.sh
PHONY: tag


## Create an interactive shell on local docker instance
interact:
	docker run --rm -it \
	  --entrypoint=/bin/sh \
	  $(IMAGE)
PHONY: interact
