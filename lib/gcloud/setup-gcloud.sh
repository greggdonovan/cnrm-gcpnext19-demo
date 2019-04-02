#!/usr/bin/env bash

GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS:-''}

PATH="$PATH:/cloud_sdk/bin"
ls -lR /cloud_sdk

if [[ ! -z "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then

    if [[ -z "${CLOUDSDK_CONFIG}" ]]; then
      echo "ERROR: The env var CLOUDSDK_CONFIG isn't defined or is empty."
      exit 1
    fi
    if [[ -z "${GCLOUD_CONFIGS}" ]]; then
      echo "ERROR: The env var GCLOUD_CONFIGS isn't defined or is empty."
      exit 1
    fi

    # copy the config files to a writable location so gcloud auth can do its thing
    cp -ur "${GCLOUD_CONFIGS}" "${CLOUDSDK_CONFIG}"

    chmod -R u+w "${CLOUDSDK_CONFIG}"/*

    gcloud config configurations activate default

    gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}"
fi
