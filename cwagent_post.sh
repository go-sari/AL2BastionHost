#!/bin/bash
# shellcheck disable=SC2086
# SPDX-License-Identifier: MIT-0

set -euxo pipefail

ETC=${ROOT:-}/etc

function config_rsyslog() {
    local cfg=$ETC/rsyslog.conf

    # change default umask, otherwise the fileCreateMode won't be effective
    local umask=037
    local header="#### GLOBAL DIRECTIVES ####"
    if grep -qiE "^\s*\\\$umask\s+" $cfg; then
      sed -ri "s/^(\s*\\\$umask\s+)\S+/\1$umask/" $cfg
    elif grep -q "^${header}$" $cfg; then
      sed -ri "s/^${header}$/\0\n\n\$umask $umask/" $cfg
    fi
    # shellcheck disable=SC2046
    if [ $(grep -cE "^\s*\\\$umask\s+$umask$" $cfg) -ne 1 ]; then
      echo "Failed to set umask."
      exit 1
    fi
    local file=/var/log/secure
    local mode=0640
    local group=cwagent
    local action="action(type=\"omfile\" file=\"$file\" fileCreateMode=\"$mode\" fileGroup=\"$group\")"
    sed -ri "s;^(authpriv\.\*)(\s+)\S+\s*$;\1\2""$action"";" $cfg
    local actualFile=${ROOT:-}$file
    chmod $mode $actualFile
    if getent group $group; then
      chgrp $group $actualFile
    fi
}

config_rsyslog
