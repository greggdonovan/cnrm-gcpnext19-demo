#!/usr/bin/env bash

# A gsutil wrapper that
# - adds a timeout in case gsutil hangs
# - logs the runtime of each gsutil command
# - enables retries, debugging and timeout via env vars which make it easier to set them by
#   high-level context, e.g. init container vs bare-metal cron
#
# The wrapper works by intercepting gsutil calls, adding appropriate options and filtering
# and augmenting its output.
#
# To use this, source this file in your script, and just invoke gsutil normally (without
# specifying its path). All gsutil calls in the enclosing script as well as those in child
# processes will be affected. The following environment variables may be set:
#
# GSUTIL_RETRIES=<int>
#     Max number of retries. The default is 6 which, with exponential back-off, amounts to
#     approx. 1 minute of total wait time in the case of quick retryable errors.
#     [https://cloud.google.com/storage/docs/gsutil/addlhelp/RetryHandlingStrategy]
#
# GSUTIL_DEBUG=<'on'|'off'>
#     on - Call gsutil with the -D option, and *mask GCS credentials* in the debugging output.
#     off - Doesn't add -D or output scrubbing. This is the default.
#
# GSUTIL_TIMEOUT_SECONDS=<int>
#     Timeout duration for the whole gsutil call including any retries. It defaults to 2 minutes
#     which should be more than enough for our use cases of EFF and IDF files. You might want to
#     set different values depending on the specific context.

# We don't really need to "save" the path to the real gsutil. This is just for readability.
export real_gsutil=$(which gsutil)

export enclosing_script=$(basename "$0")

function add_log_prefix {
    while read line; do
        info_log --gsutil_wrapper=true --enclosing_script="$enclosing_script" "$line"
    done
}

# Exported so they can be called by the timeout-wrapped bash process:
export -f add_log_prefix info_log

# define a function to shadow the gsutil command
function gsutil {
    ## env vars as named params
    GSUTIL_RETRIES=${GSUTIL_RETRIES-6}
    GSUTIL_DEBUG=${GSUTIL_DEBUG-off}
    GSUTIL_TIMEOUT_SECONDS=${GSUTIL_TIMEOUT_SECONDS-120}

    args="$@"

    # Enabling debug output from gsutil isn't safe with most operations -- `cat`, for instance,
    # produces its result on stdout, so debug output would be mixed in with the catted contents.
    # Therefore, only enable debug for `rsync` and `cp` that don't put important output on stdout.
    # Similarly, structured logging with `add_log_prefix` is only safe on those commands, to avoid
    # altering the real output of commands like `cat`.
    debug_opt=''
    filter_output='cat'
    debug_eligible_regex="(^| )(cp|rsync)( )"
    if [[ "${args}" =~ ${debug_eligible_regex} ]]; then
        if [[ "${GSUTIL_DEBUG}" == "on" ]]; then
            debug_opt='-D'
            sensitive_regex="\(X-GUploader-UploadID:.*\)"
            sensitive_regex="\(authorization: Bearer [^ ]*\)\|${sensitive_regex}"
            sensitive_regex="\(client_secret=[^ ]*\)\|${sensitive_regex}"
            sensitive_regex="\(refresh_token=[^ ]*\)\|${sensitive_regex}"
            sensitive_regex="\(crypt.py\] \[.*\]\)\|${sensitive_regex}"
            sensitive_regex="\(\/o\/oauth.*\/token .*\)\|${sensitive_regex}"
            filter_output="sed 's/${sensitive_regex}/<***>/' | add_log_prefix"
        else
            filter_output="add_log_prefix"
        fi
    fi

    start_time=$(date -u +%s%3N)

    timeout --signal=KILL ${GSUTIL_TIMEOUT_SECONDS}s \
        bash -co pipefail "${real_gsutil} ${debug_opt} -o 'Boto:num_retries=${GSUTIL_RETRIES}' ${args} 2>&1 | ${filter_output}"
    exit_status=$?

    end_time=$(date -u +%s%3N)
    elapsed_ms=$((end_time - start_time))

    # Log to stderr so the output isn't mixed up with genuine `gsutil cat` output:
    >&2 info_log "gsutil complete" --gsutil_wrapper=true --enclosing_script="$enclosing_script" --status="${exit_status}" --runtime="${elapsed_ms}ms" --args="${args}"

    return ${exit_status}
}

export -f gsutil
