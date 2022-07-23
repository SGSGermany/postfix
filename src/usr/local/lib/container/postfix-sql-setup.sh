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
    printf "$@" | postlog -t "entrypoint/postfix-sql-setup" > /dev/null
}

read_secret() {
    local SECRET="/run/secrets/$1"
    local DEFAULT="${2:-}"

    [ -e "$SECRET" ] || { [ -z "$DEFAULT" ] || echo "$DEFAULT"; return 0; }
    [ -f "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Not a file" >&2; return 1; }
    [ -r "$SECRET" ] || { echo "Failed to read '$SECRET' secret: Permission denied" >&2; return 1; }
    cat "$SECRET" || return 1
}

envsubst() {
    local VARIABLES="$(for ARG in "$@"; do
        echo "$ARG" | awk 'match($0, /^[a-zA-Z_][a-zA-Z0-9_]*=/, m) {print sprintf("${%s}", substr($0, RSTART, RLENGTH-1))}'
    done)"

    env -i "$@" \
        sh -c '/usr/bin/envsubst "$1"' 'envsubst' "$VARIABLES"
}

sponge() {
    local FILE="$1"
    local CONTENT="$(cat)"
    [ -n "$CONTENT" ] && printf '%s\n' "$CONTENT" > "$FILE" || : > "$FILE"
}

if [ -z "$(find /etc/postfix/sql -name '*.cf' -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    exit
fi

log "setting up Postfix SQL configuration"

MYSQL_DATABASE="$(read_secret "mail_mysql_database" "mail")"
MYSQL_USER="$(read_secret "mail_mysql_user" "mail")"
MYSQL_PASSWORD="$(read_secret "mail_mysql_password")"

for FILE in /etc/postfix/sql/*.cf; do
    log "injecting MySQL login credentials into '%s'" "$FILE"
    envsubst \
        MYSQL_DATABASE="$MYSQL_DATABASE" \
        MYSQL_USER="$MYSQL_USER" \
        MYSQL_PASSWORD="$MYSQL_PASSWORD" \
        < "$FILE" \
        | sponge "$FILE"
done
