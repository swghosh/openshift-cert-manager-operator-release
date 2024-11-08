#!/usr/bin/env bash

declare CONTAINER_ENGINE
declare CONTAINER_IMAGE
declare GITHUB_ACTION
declare -a CONTAINERFILES

CONTAINER_ENGINE=${CONTAINER_ENGINE:-"podman"}
CONTAINER_IMAGE=${CONTAINER_IMAGE:-"ghcr.io/hadolint/hadolint"}
GITHUB_ACTION=${GITHUB_ACTION:-""}
CERT_MANAGER_OPERATOR_CONTAINERFILES=("Containerfile.cert-manager" "Containerfile.cert-manager.acmesolver" "Containerfile.cert-manager-operator" "Containerfile.cert-manager-operator.bundle" "Containerfile.catalog")

linter()
{
	linter_envs="HADOLINT_FAILURE_THRESHOLD=error"
	runcmd="${CONTAINER_ENGINE} run --rm -i -e ${linter_envs} ${CONTAINER_IMAGE}"
	
	if [[ "${GITHUB_ACTION}" ]]; then
		export "${linter_envs} "
		# run without container, when using GH actions runner
		runcmd="hadolint"
	fi

	containerfiles=("$@")
	lint_fail=""
	for containerfile in "${containerfiles[@]}"; do
		if [[ ! -f "${containerfile}" ]]; then
			echo "[$(date)] -- ERROR -- ${containerfile} does not exist"
			exit 1
		fi
		echo "[$(date)] -- INFO  -- running linter on ${containerfile}"
		
		if [[ "${GITHUB_ACTION}" ]]; then
			runcmdx="${runcmd} ${containerfile}"
			if ! $runcmdx ; then
				lint_fail="err"
			fi
		else
			if ! $runcmd < "${containerfile}" ; then
				lint_fail="err"
			fi
		fi
		
	done

	if [[ "${lint_fail}" ]]; then
		exit 1
	fi
}

containerfile_linter()
{
	if [[ "${#CONTAINERFILES[@]}" -gt 0 ]]; then
		linter "${CONTAINERFILES[@]}"
		return
	fi
	echo "[$(date)] -- INFO  -- running linter on ${CERT_MANAGER_OPERATOR_CONTAINERFILES[*]}"
	linter "${CERT_MANAGER_OPERATOR_CONTAINERFILES[@]}"
}

##############################################
###############  MAIN  #######################
##############################################

if [[ $# -ge 1 ]]; then
	CONTAINERFILES=("$@")
	echo "[$(date)] -- INFO  -- running linter on $*"
fi

containerfile_linter

exit 0
