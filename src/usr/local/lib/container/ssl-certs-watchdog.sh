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
    printf "$@" | postlog -t "entrypoint/ssl-certs-watchdog" > /dev/null
}

CERT_DIR="/etc/postfix/ssl/mx"
[ -e "$CERT_DIR" ] || exit 0
[ -d "$CERT_DIR" ] || { echo "Invalid certificate directory '$CERT_DIR': Not a directory" >&2; exit 1; }

log "starting SSL certificates watchdog service"
inotifywait -e close_write,delete,move -m "$CERT_DIR/" \
    | while read -r DIRECTORY EVENTS FILENAME; do
        log "receiving inotify event '%s' for '%s%s'" "$EVENTS" "$DIRECTORY" "$FILENAME"

        # wait till 300 sec (5 min) after the last event, new events reset the timer
        while read -t 300 -r DIRECTORY EVENTS FILENAME; do
            log "receiving inotify event '%s' for '%s%s'" "$EVENTS" "$DIRECTORY" "$FILENAME"
        done

        log "triggering configuration reload"
        postfix reload
    done
