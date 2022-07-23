#!/bin/bash
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
shopt -u nullglob

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"

setup_spool() {
    local SPOOL_PATH="$1"
    local POSTFIX_SPOOL="/var/spool/postfix/$(basename "$SPOOL_PATH")"

    if [ -e "$MOUNT/$POSTFIX_SPOOL" ]; then
        if [ -e "$MOUNT/$SPOOL_PATH" ]; then
            cmd buildah run "$CONTAINER" -- \
                sh -c 'chmod "$(stat -c %a "$1")" "$2"; chown "$(stat -c %U:%G "$1")" "$2";' "sh" \
                    "$POSTFIX_SPOOL" "$SPOOL_PATH"

            cmd buildah run "$CONTAINER" -- \
                rmdir "$POSTFIX_SPOOL"
        else
            cmd buildah run "$CONTAINER" -- \
                mv "$POSTFIX_SPOOL" "$SPOOL_PATH"
        fi
    fi

    cmd buildah run "$CONTAINER" -- \
        ln -s "$SPOOL_PATH" "$POSTFIX_SPOOL"
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

pkg_install "$CONTAINER" --virtual .postfix \
    postfix \
    postfix-mysql

pkg_install "$CONTAINER" --virtual .postfix-run-deps \
    inotify-tools \
    gettext

cmd buildah run "$CONTAINER" -- \
    deluser vmail

user_changeuid "$CONTAINER" postfix 65536

user_add "$CONTAINER" ssl-certs 65537

user_add "$CONTAINER" mysql 65538

user_add "$CONTAINER" dovecot-sock 65539

cmd buildah run "$CONTAINER" -- \
    adduser postfix dovecot-sock

user_add "$CONTAINER" mta-sts 65540

cmd buildah run "$CONTAINER" -- \
    adduser postfix mta-sts

echo + "mkdir …/usr/share/postfix" >&2
mkdir "$MOUNT/usr/share/postfix"

echo + "mv -t …/usr/share/postfix " \
    "…/etc/postfix/dynamicmaps.cf{,.d/} …/etc/postfix/postfix-files.cf{,.d/}" \
    "…/etc/postfix/main.cf.proto …/etc/postfix/master.cf.proto" >&2
mv -t "$MOUNT/usr/share/postfix" \
    "$MOUNT/etc/postfix/dynamicmaps.cf" \
    "$MOUNT/etc/postfix/dynamicmaps.cf.d" \
    "$MOUNT/etc/postfix/postfix-files" \
    "$MOUNT/etc/postfix/postfix-files.d" \
    "$MOUNT/etc/postfix/main.cf.proto" \
    "$MOUNT/etc/postfix/master.cf.proto"

echo + "rm -rf …/etc/postfix" >&2
rm -rf "$MOUNT/etc/postfix"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

cmd buildah run "$CONTAINER" -- \
    find "/etc/postfix/sql" -name '*.cf' -mindepth 1 -maxdepth 1 \
        -exec chmod 640 {} \;

cmd buildah run "$CONTAINER" -- \
    find "/etc/postfix/sql" -name '*.cf' -mindepth 1 -maxdepth 1 \
        -exec chown root:postfix {} \;

setup_spool "/run/postfix/pid"

setup_spool "/run/postfix/private"
setup_spool "/run/postfix/public"

cmd buildah run "$CONTAINER" -- \
    ln -s "/run/dovecot" "/var/spool/postfix/dovecot"

cmd buildah run "$CONTAINER" -- \
    ln -s "/run/mta-sts" "/var/spool/postfix/mta-sts"

VERSION="$(pkg_version "$CONTAINER" postfix)"

cleanup "$CONTAINER"

cmd buildah config \
    --port "25/tcp" \
    --port "587/tcp" \
    --port "465/tcp" \
    "$CONTAINER"

cmd buildah config \
    --volume "/etc/postfix/ssl" \
    --volume "/var/spool/postfix/queue" \
    --volume "/var/spool/postfix/status" \
    --volume "/run/mysql" \
    --volume "/run/dovecot" \
    --volume "/run/mta-sts" \
    "$CONTAINER"

cmd buildah config \
    --entrypoint '[ "/entrypoint.sh" ]' \
    --cmd '[ "postfix", "start-fg" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="Postfix" \
    --annotation org.opencontainers.image.description="A container running Postfix, a open-source mail transfer agent (MTA)." \
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/postfix" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
