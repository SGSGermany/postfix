#!/bin/sh
# Postfix
# A container running Postfix, a open-source mail transfer agent (MTA).
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C

log() {
    printf "$@" | postlog -t "entrypoint/postfix-spool-setup" > /dev/null
}

error() {
    printf "$@" | postlog -t "entrypoint/postfix-spool-setup" -p "error" > /dev/null
}

setup_spool() {
    local SPOOL_TYPE="$(dirname "$1")"
    local SPOOL="$(basename "$1")"

    local SPOOL_BASE_PATH="/var/spool/postfix/$SPOOL_TYPE"
    local POSTFIX_SPOOL="/var/spool/postfix/$SPOOL"

    if [ -h "$POSTFIX_SPOOL" ]; then
        if [ ! -e "$POSTFIX_SPOOL" ]; then
            error "Invalid Postfix spool '%s': Broken symbolic link" "$POSTFIX_SPOOL"
            return 1
        elif [ "$(readlink -f "$POSTFIX_SPOOL")" != "$SPOOL_BASE_PATH/$SPOOL" ]; then
            error "Invalid Postfix spool '%s': Invalid symbolic link" "$POSTFIX_SPOOL"
            return 1
        elif [ ! -d "$SPOOL_BASE_PATH/$SPOOL" ]; then
            error "Invalid Postfix spool '%s': Not a directory" "$SPOOL_BASE_PATH/$SPOOL"
            return 1
        fi

        return 0
    fi

    if [ ! -e "$POSTFIX_SPOOL" ]; then
        error "Invalid Postfix spool '%s': No such file or directory" "$POSTFIX_SPOOL"
        return 1
    elif [ ! -d "$POSTFIX_SPOOL" ]; then
        error "Invalid Postfix spool '%s': Not a directory" "$POSTFIX_SPOOL"
        return 1
    fi

    if [ ! -e "$SPOOL_BASE_PATH" ]; then
        mkdir "$SPOOL_BASE_PATH"
    elif [ ! -d "$SPOOL_BASE_PATH" ]; then
        error "Invalid Postfix spool base directory '%s': Not a directory" "$SPOOL_BASE_PATH"
        return 1
    fi

    if [ ! -e "$SPOOL_BASE_PATH/$SPOOL" ]; then
        mv "$POSTFIX_SPOOL" "$SPOOL_BASE_PATH/$SPOOL"
    elif [ -d "$SPOOL_BASE_PATH/$SPOOL" ]; then
        chmod "$(stat -c '%a' "$POSTFIX_SPOOL")" "$SPOOL_BASE_PATH/$SPOOL"
        chown "$(stat -c '%U:%G' "$POSTFIX_SPOOL")" "$SPOOL_BASE_PATH/$SPOOL"

        rmdir "$POSTFIX_SPOOL"
    else
        error "Invalid Postfix spool '%s': Not a directory" "$SPOOL_BASE_PATH/$SPOOL"
        return 1
    fi

    ln -s "$SPOOL_TYPE/$SPOOL" "$POSTFIX_SPOOL"
}

log "setting up Postfix spools"

for POSTFIX_MAIL_QUEUE in "active" "corrupt" "deferred" "hold" "incoming" "maildrop" "saved"; do
    log "setting up Postfix '%s' mail queue" "$POSTFIX_MAIL_QUEUE"
    setup_spool "queue/$POSTFIX_MAIL_QUEUE"
done

for POSTFIX_MAIL_STATUS_LOG in "bounce" "defer" "flush" "trace"; do
    log "setting up Postfix mail status log '%s'" "$POSTFIX_MAIL_STATUS_LOG"
    setup_spool "status/$POSTFIX_MAIL_STATUS_LOG"
done
