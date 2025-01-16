## local variables.
cert_manager_submodule_dir = cert-manager
cert_manager_operator_submodule_dir = cert-manager-operator
istio_csr_submodule_dir = cert-manager-istio-csr
cert_manager_containerfile_name = Containerfile.cert-manager
cert_manager_acmesolver_containerfile_name = Containerfile.cert-manager.acmesolver
cert_manager_operator_containerfile_name = Containerfile.cert-manager-operator
cert_manager_operator_bundle_containerfile_name = Containerfile.cert-manager-operator.bundle
istio_csr_containerfile_name = Containerfile.cert-manager-istio-csr
commit_sha = $(strip $(shell git rev-parse HEAD))
source_url = $(strip $(shell git remote get-url origin))
release_version = v$(strip $(shell git branch --show-current | cut -d'-' -f2))

## cert-manager-operator-release and cert-manager follow same naming for release
## branches except for cert-manager-operator which has release version as suffix in
## the branch name like in aforementioned repositories, which will be used for
## deriving the submodules branch.
PARENT_BRANCH_SUFFIX = $(strip $(shell git branch --show-current | cut -d'-' -f2))

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

## current branch name of the istio-csr submodule.
ISTIO_CSR_BRANCH ?= release-$(PARENT_BRANCH_SUFFIX)

ifeq ($(PARENT_BRANCH_SUFFIX), main)
ISTIO_CSR_BRANCH = main
endif

## container build tool to use for creating images.
CONTAINER_ENGINE ?= podman

## image name for cert-manager-operator.
CERT_MANAGER_OPERATOR_IMAGE ?= cert-manager-operator

## image name for cert-manager-operator-bundle.
CERT_MANAGER_OPERATOR_BUNDLE_IMAGE ?= cert-manager-operator-bundle

## image name for cert-manager.
CERT_MANAGER_IMAGE ?= cert-manager

## image name for cert-manager-acmesolver.
CERT_MANAGER_ACMESOLVER_IMAGE ?= cert-manager-acmesolver

## image name for cert-manager catalog.
CATALOG_IMAGE ?= cert-manager-catalog

## image version to tag the created images with.
IMAGE_VERSION ?= $(release_version)

## image for istio-csr
ISTIO_CSR_IMAGE ?= cert-manager-istio-csr

## image tag makes use of the branch name and
## when branch name is `main` use `latest` as the tag.
ifeq ($(PARENT_BRANCH_SUFFIX), main)
IMAGE_VERSION = latest
endif

## args to pass during image build
IMAGE_BUILD_ARGS ?= --build-arg RELEASE_VERSION=$(release_version) --build-arg COMMIT_SHA=$(commit_sha) --build-arg SOURCE_URL=$(source_url)

## tailored command to build images.
IMAGE_BUILD_CMD = $(CONTAINER_ENGINE) build $(IMAGE_BUILD_ARGS)

## path to store the tools binary.
TOOL_BIN_DIR = $(strip $(shell git rev-parse --show-toplevel --show-superproject-working-tree | tail -1))/bin/tools

## URL to download Operator Package Manager tool.
OPM_DOWNLOAD_URL = https://github.com/operator-framework/operator-registry/releases/download/v1.48.0/linux-amd64-opm

## Operator Package Manager tool path.
OPM_TOOL_PATH ?= $(TOOL_BIN_DIR)/opm

## Operator bundle image to use for generating the catalog. It is intended to be used with the update-catalog target.
OPERATOR_BUNDLE_IMAGE ?=

## Catalog directory where generated catalog will be stored. Directory must be of the form `catalogs/v<ocp_release>/catalog` and must have `openshift-cert-manager-operator` subdirectory. Ex: `catalogs/v4.17/catalog`. It is intended to be used with the update-catalog target.
CATALOG_DIR ?=

## Replicate generated catalog bundle file to other version catalogs. To be used with update-catalog target. Default value is `no`.
REPLICATE_BUNDLE_FILE_IN_CATALOGS ?= no

## Use `--migrate-level` flag during bundle generation. To be used with update-catalog target. Default value is `yes`. Refer https://github.com/konflux-ci/build-definitions/blob/main/task/fbc-validation/0.1/TROUBLESHOOTING.md for details.
USE_MIGRATE_LEVEL_FLAG ?= yes

## Name of the catalog bundle file to be used. To be used with update-catalog target.
BUNDLE_FILE_NAME ?=

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
	@ awk '/^#/{ comment = substr($$0,3) } comment && /^[a-zA-Z][a-zA-Z0-9_-]+ ?\?=/{ print "   ", $$1, $$2, comment }' $(MAKEFILE_LIST) | column -t -s '?=' | sort
	@ echo ''

## execute all required targets.
.PHONY: all
all: verify

## checkout submodules branch to match the parent branch.
.PHONY: switch-submodules-branch
switch-submodules-branch:
	cd $(cert_manager_submodule_dir); git checkout $(CERT_MANAGER_BRANCH); cd - > /dev/null
	cd $(cert_manager_operator_submodule_dir); git checkout $(CERT_MANAGER_OPERATOR_BRANCH); cd - > /dev/null
	cd $(istio_csr_submodule_dir); git checkout $(ISTIO_CSR_BRANCH); cd - > /dev/null
	# update with local cache.
	git submodule update

## update submodules revision to match the revision of the origin repository.
.PHONY: update-submodules
update-submodules:
	git submodule update --remote $(istio_csr_submodule_dir)
	git submodule update --remote $(cert_manager_submodule_dir)
	git submodule update --remote $(cert_manager_operator_submodule_dir)

## build all the images - operator, operand and operator-bundle.
.PHONY: build-images
build-images: build-operand-images build-operator-image build-bundle-image build-catalog-image

## build operator image.
.PHONY: build-operator-image
build-operator-image:
	$(IMAGE_BUILD_CMD) -f $(cert_manager_operator_containerfile_name) -t $(CERT_MANAGER_OPERATOR_IMAGE):$(IMAGE_VERSION) .

## build all operand images
.PHONY: build-operand-images
build-operand-images: build-cert-manager-image build-cert-manager-acmesolver-image build-istio-csr-image

## build operator bundle image.
.PHONY: build-bundle-image
build-bundle-image:
	$(IMAGE_BUILD_CMD) -f $(cert_manager_operator_bundle_containerfile_name) -t $(CERT_MANAGER_OPERATOR_BUNDLE_IMAGE):$(IMAGE_VERSION) .

## build operand cert-manager image.
.PHONY: build-cert-manager-image
build-cert-manager-image:
	$(IMAGE_BUILD_CMD) -f $(cert_manager_containerfile_name) -t $(CERT_MANAGER_IMAGE):$(IMAGE_VERSION) .

## build operand cert-manager-acmesolver image.
.PHONY: build-cert-manager-acmesolver-image
build-cert-manager-acmesolver-image:
	$(IMAGE_BUILD_CMD) -f $(cert_manager_acmesolver_containerfile_name) -t $(CERT_MANAGER_ACMESOLVER_IMAGE):$(IMAGE_VERSION) .

## build operator catalog image.
.PHONY: build-catalog-image
build-catalog-image:
	$(CONTAINER_ENGINE) build -f Containerfile.catalog -t $(CATALOG_IMAGE):$(IMAGE_VERSION) .

## update catalog using the provided bundle image.
.PHONY: update-catalog
update-catalog: get-opm
	# Ex: make update-catalog OPERATOR_BUNDLE_IMAGE=registry.stage.redhat.io/cert-manager/cert-manager-operator-bundle@sha256:4114321b0ab6ceb882f26501ff9b22214d90b83d92466e7c5a62217f592c1fed CATALOG_DIR=catalogs/v4.17/catalog BUNDLE_FILE_NAME=bundle-v1.15.0.yaml REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=yes
	./hack/update_catalog.sh $(OPM_TOOL_PATH) $(OPERATOR_BUNDLE_IMAGE) $(CATALOG_DIR) $(BUNDLE_FILE_NAME) $(REPLICATE_BUNDLE_FILE_IN_CATALOGS) $(USE_MIGRATE_LEVEL_FLAG)

## update catalog and build catalog image.
.PHONY: catalog
catalog: get-opm update-catalog build-catalog-image

## build operand istio-csr image.
.PHONY: build-istio-csr-image
build-istio-csr-image:
	$(IMAGE_BUILD_CMD) -f $(istio_csr_containerfile_name) -t $(ISTIO_CSR_IMAGE):$(IMAGE_VERSION) .

## check shell scripts.
.PHONY: verify-shell-scripts
verify-shell-scripts:
	./hack/shell-scripts-linter.sh

## check containerfiles.
.PHONY: verify-containerfiles
verify-containerfiles:
	./hack/containerfile-linter.sh

## verify the changes are working as expected.
.PHONY: verify
verify: verify-shell-scripts verify-containerfiles validate-renovate-config build-images

## update all required contents.
.PHONY: update
update: update-submodules

## get opm(operator package manager) tool.
.PHONY: get-opm
get-opm:
	$(call get-bin,$(OPM_TOOL_PATH),$(TOOL_BIN_DIR),$(OPM_DOWNLOAD_URL))

define get-bin
@[ -f "$(1)" ] || { \
	[ ! -d "$(2)" ] && mkdir -p "$(2)" || true ;\
	echo "Downloading $(3)" ;\
	curl -fL $(3) -o "$(1)" ;\
	chmod +x "$(1)" ;\
}
endef

## clean up temp dirs, images.
.PHONY: clean
clean:
	podman rmi -i $(CERT_MANAGER_OPERATOR_IMAGE):$(IMAGE_VERSION) \
$(CERT_MANAGER_IMAGE):$(IMAGE_VERSION) \
$(CERT_MANAGER_ACMESOLVER_IMAGE):$(IMAGE_VERSION) \
$(CERT_MANAGER_OPERATOR_BUNDLE_IMAGE):$(IMAGE_VERSION) \
$(CATALOG_IMAGE):$(IMAGE_VERSION)

	rm -r $(TOOL_BIN_DIR)

## validate renovate config.
.PHONY: validate-renovate-config
validate-renovate-config:
	./hack/renovate-config-validator.sh

