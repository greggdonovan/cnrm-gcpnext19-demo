#!/usr/bin/env bash

: "${KUBERNETES_CLUSTER?KUBERNETES_CLUSTER is required}"
: "${KUBERNETES_NAMESPACE?KUBERNETES_NAMESPACE is required}"
: "${KUBERNETES_CONTAINER_NAME?KUBERNETES_CONTAINER_NAME is required}"

set -o errexit
set -u
set -x

echo "hello from run.sh"

script_dir=$(readlink -f "$(dirname "$(type -p "$0")")")
# shellcheck source=lib/gcloud/setup-gcloud.sh
# . "/scripts/setup-gcloud.sh" # Set up gcs authentication
# shellcheck source=lib/gcloud/gsutil-wrapper.sh
#  "/scripts/gsutil-wrapper.sh"

YOURKIT_OPTS='-agentpath:/yourkit/lib/libyjpagent.so=sampling,port=10001,listen=all,logdir=/var/log/search/yourkit,onexit=snapshot,dir=/var/log/search/yourkit'

echo "KUBERNETES_CLUSTER=${KUBERNETES_CLUSTER}"
echo "KUBERNETES_NAMESPACE=${KUBERNETES_NAMESPACE}"
echo "KUBERNETES_CONTAINER_NAME=${KUBERNETES_CONTAINER_NAME}"
bucket="${KUBERNETES_CLUSTER}-${KUBERNETES_NAMESPACE}-${KUBERNETES_CONTAINER_NAME}"

echo "Enabling YourKit with YOURKIT_OPTS=\"${YOURKIT_OPTS}\" bucket=${bucket}"
mkdir -p /var/log/search/yourkit/

function onexit() {
  echo "about to sync yourkit"
  /opt/java/openjdk/bin/java "${YOURKIT_OPTS}" -jar /search/dist/CopyToStorage_deploy.jar /var/log/search/yourkit ${bucket}
}

trap onexit EXIT

/opt/java/openjdk/bin/java "${YOURKIT_OPTS}" -jar /search/dist/Example_deploy.jar