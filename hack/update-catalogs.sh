#!/bin/bash

export OPERATOR_BUNDLE_IMAGE="registry.redhat.io/cert-manager/cert-manager-operator-bundle@sha256:f3324ea2051d4ffb00136de53f5355bcc0449bc79349833ddaae528cb37cd3b0"
export BUNDLE_FILE_NAME="bundle-v1.16.0.yaml"

make update-catalog CATALOG_DIR=catalogs/v4.14/catalog REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=no
make update-catalog CATALOG_DIR=catalogs/v4.15/catalog REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=no
make update-catalog CATALOG_DIR=catalogs/v4.16/catalog REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=no
make update-catalog CATALOG_DIR=catalogs/v4.17/catalog REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=yes
make update-catalog CATALOG_DIR=catalogs/v4.17/catalog REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=yes
make update-catalog CATALOG_DIR=catalogs/v4.18/catalog REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=yes
make update-catalog CATALOG_DIR=catalogs/v4.19/catalog REPLICATE_BUNDLE_FILE_IN_CATALOGS=no USE_MIGRATE_LEVEL_FLAG=yes
