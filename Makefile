## cert-manager-operator-release and cert-manager follow same naming for release
## branches except for cert-manager-operator which has release version as suffix in
## the branch name like in aforementioned repositories, which will be used for
## deriving the submodules branch.
PARENT_BRANCH_SUFFIX ?= $(strip $(shell git branch --show-current | cut -d'-' -f2))

## current branch name of the cert-manager submodule.
CERT_MANAGER_BRANCH ?= release-$(PARENT_BRANCH_SUFFIX)
## check if the parent module branch is main and assign the equivalent cert-manager
## branch instead of deriving the branch name.
ifeq ($(PARENT_BRANCH_SUFFIX), main)
CERT_MANAGER_BRANCH = master
endif

## current branch name of the cert-manager-operator submodule.
CERT_MANAGER_OPERATOR_BRANCH ?= cert-manager-$(PARENT_BRANCH_SUFFIX)
## check if the parent module branch is main and assign the equivalent cert-manager-operator
## branch instead of deriving the branch name.
ifeq ($(PARENT_BRANCH_SUFFIX), main)
CERT_MANAGER_OPERATOR_BRANCH = master
endif

## default container build tool to use for creating images.
CONTAINER_ENGINE ?= docker

## default image name for cert-manager-operator.
CERT_MANAGER_OPERATOR_IMAGE ?= cert-manager-operator

## default image name for cert-manager-operator-bundle.
CERT_MANAGER_OPERATOR_BUNDLE_IMAGE ?= cert-manager-operator-bundle

## default image name for cert-manager.
CERT_MANAGER_IMAGE ?= cert-manager

## default image name for cert-manager-acmesolver.
CERT_MANAGER_ACMESOLVER_IMAGE ?= cert-manager-acmesolver

## default image version to tag the created images.
IMAGE_VERSION ?= release-$(PARENT_BRANCH_SUFFIX)

## default image tag makes use of the branch name and
## when branch name is `main` use `latest` as the tag.
ifeq ($(PARENT_BRANCH_SUFFIX), main)
IMAGE_VERSION = latest
endif

.DEFAULT_GOAL := help
## usage summary.
.PHONY: help
help:
	@ echo
	@ echo '  Usage:'
	@ echo ''
	@ echo '    make <target> [flags...]'
	@ echo ''
	@ echo '  Targets:'
	@ echo ''
	@ awk '/^#/{ comment = substr($$0,3) } comment && /^[a-zA-Z][a-zA-Z0-9_-]+ ?:/{ print "   ", $$1, comment }' $(MAKEFILE_LIST) | column -t -s ':' | sort
	@ echo ''
	@ echo '  Flags:'
	@ echo ''
	@ awk '/^#/{ comment = substr($$0,3) } comment && /^[a-zA-Z][a-zA-Z0-9_-]+ ?\?=/{ print "   ", $$1, $$2, comment }' $(MAKEFILE_LIST) | column -t -s '?=' | sort | egrep -v "PARENT_BRANCH_SUFFIX"
	@ echo ''

## execute all required targets.
.PHONY: all
all: verify

## checkout submodules branch to match the parent branch.
.PHONY: switch-submodules-branch
switch-submodules-branch:
	cd cert-manager; git checkout $(CERT_MANAGER_BRANCH); cd - > /dev/null
	cd cert-manager-operator; git checkout $(CERT_MANAGER_OPERATOR_BRANCH); cd - > /dev/null

## update submodules revision to match the revision of the origin repository.
.PHONY: update-submodules
update-submodules:
	git submodule update --remote cert-manager
	git submodule update --remote cert-manager-operator

## build all the images - operator, operand and operator-bundle.
.PHONY: build-images
build-images: build-operand-images build-operator-image build-bundle-image

## build operator image.
.PHONY: build-operator-image
build-operator-image:
	$(CONTAINER_ENGINE) build -f Containerfile.cert-manager-operator -t $(CERT_MANAGER_OPERATOR_IMAGE):$(IMAGE_VERSION) .

## build all operand images
.PHONY: build-operand-images
build-operand-images:
	$(CONTAINER_ENGINE) build -f Containerfile.cert-manager -t $(CERT_MANAGER_IMAGE):$(IMAGE_VERSION) .
	$(CONTAINER_ENGINE) build -f Containerfile.cert-manager.acmesolver -t $(CERT_MANAGER_ACMESOLVER_IMAGE):$(IMAGE_VERSION) .

## build operator bundle image.
.PHONY: build-bundle-image
build-bundle-image:
	$(CONTAINER_ENGINE) build -f Containerfile.cert-manager-operator.bundle -t $(CERT_MANAGER_OPERATOR_BUNDLE_IMAGE):$(IMAGE_VERSION) .

## build operand cert-manager image.
.PHONY: build-cert-manager-image
build-cert-manager-image:
	$(CONTAINER_ENGINE) build -f Containerfile.cert-manager -t $(CERT_MANAGER_IMAGE):$(IMAGE_VERSION) .

## build operand cert-manager-acmesolver image.
.PHONY: build-cert-manager-acmesolver-image
build-cert-manager-acmesolver-image:
	$(CONTAINER_ENGINE) build -f Containerfile.cert-manager.acmesolver -t $(CERT_MANAGER_ACMESOLVER_IMAGE):$(IMAGE_VERSION) .

## verify the changes are working as expected.
.PHONY: verify
verify: build-images

## update all required contents.
.PHONY: update
update: update-submodules
