#!/bin/bash
# shellcheck disable=SC2086
# SPDX-License-Identifier: MIT-0

set -euo pipefail

ETC=${ROOT:-}/etc

function modify_sysctl_settings() {
  # Settings to update
  declare -A to_modify
  to_modify["net.ipv4.ip_forward"]=1

  local cfg=$ETC/sysctl.conf
  local any_value=".*$"
  for key in "${!to_modify[@]}"; do
    local value=${to_modify[$key]}
    local esc_value=${value//\//\\/}  # escape any "/"
    local ena_key="^(\s*)$key\s*="
    local dis_key="^(\s*)#\s*$key\s*="

    if grep -qiE "$ena_key" $cfg; then
      sed -ri "s/${ena_key}${any_value}/\1$key = $esc_value/I" $cfg
    elif grep -qiE "$dis_key" $cfg; then
      sed -ri "0,/$dis_key/I{s/${dis_key}${any_value}/\1$key = $esc_value/I}" $cfg
    else
      echo "$key = $value" >> $cfg
    fi
    if grep -qiE "${ena_key}\s*$value$" $cfg; then
      echo "$key set to '$value'."
    else
      echo "Failed to set $key to '$value'."
      exit 1
    fi
  done
}

modify_sysctl_settings
