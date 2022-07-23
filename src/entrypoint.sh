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

[ $# -gt 0 ] || set -- postfix start-fg

if [ "$1" == "postfix" ]; then
    /usr/local/lib/container/postfix-ssl-setup.sh
    /usr/local/lib/container/postfix-sql-setup.sh
    /usr/local/lib/container/postfix-spool-setup.sh

    /usr/local/lib/container/ssl-certs-watchdog.sh &
fi

exec "$@"
