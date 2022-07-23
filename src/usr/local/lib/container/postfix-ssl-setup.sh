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
    printf "$@" | postlog -t "entrypoint/postfix-ssl-setup" > /dev/null
}

log "setting up Postfix SSL configuration"

if [ ! -f "/etc/postfix/ssl/dhparams.pem" ]; then
    # generating Diffie Hellman parameters might take a few minutes...
    log "generating Diffie Hellman parameters"
    openssl dhparam -out "/etc/postfix/ssl/dhparams.pem" 2048
fi
