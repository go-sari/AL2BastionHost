#!/bin/bash
# shellcheck disable=SC2086
# SPDX-License-Identifier: MIT-0

set -euo pipefail

ETC_SSH=${ROOT:-}/etc/ssh

function harden_host_keys() {
  rm -fv $ETC_SSH/ssh_host_*
  ssh-keygen -t rsa -b 4096 -f $ETC_SSH/ssh_host_rsa_key -N ''
  ssh-keygen -t ed25519 -f $ETC_SSH/ssh_host_ed25519_key -N ''
  if getent group ssh_keys > /dev/null; then
    chgrp ssh_keys $ETC_SSH/ssh_host_ed25519_key $ETC_SSH/ssh_host_rsa_key
    chmod g+r $ETC_SSH/ssh_host_ed25519_key $ETC_SSH/ssh_host_rsa_key
  fi
  umask 022
  awk '$5 >= 3071' $ETC_SSH/moduli > $ETC_SSH/moduli.safe
  mv -f $ETC_SSH/moduli.safe $ETC_SSH/moduli
}

function modify_settings() {
  # Settings to update
  # We're assuming the STIG High component was already applied
  declare -A to_modify
  to_modify["AllowAgentForwarding"]=no
  to_modify["AllowUsers"]=ec2-user
  to_modify["AuthenticationMethods"]=publickey
  to_modify["AuthorizedKeysFile"]=".ssh/authorized_keys .ssh/authorized_keys2"
  to_modify["Banner"]=/etc/issue.net
  to_modify["Ciphers"]="chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
  to_modify["KexAlgorithms"]="curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256"
  to_modify["LogLevel"]=VERBOSE
  to_modify["MACs"]="hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com"
  to_modify["PermitTTY"]=yes
  to_modify["PrintLastLog"]=no
  to_modify["PubkeyAcceptedKeyTypes"]="ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-512,ssh-rsa,ssh-dss"
  to_modify["Subsystem sftp"]=/bin/false

  local cfg=$ETC_SSH/sshd_config
  local any_value=".*$"
  for key in "${!to_modify[@]}"; do
    local value=${to_modify[$key]}
    local esc_value=${value//\//\\/}  # escape any "/"
    local ena_key="^(\s*)$key\s+"
    local dis_key="^(\s*)#\s*$key\s+"

    if grep -qiE "$ena_key" $cfg; then
      sed -ri "s/${ena_key}${any_value}/\1$key $esc_value/i" $cfg
    elif grep -qiE "$dis_key" $cfg; then
      sed -ri "0,/$dis_key/{s/${dis_key}${any_value}/\1$key $esc_value/}" $cfg
    else
      echo "$key $value" >> $cfg
    fi
    if grep -qiE "${ena_key}$value$" $cfg; then
      echo "$key set to '$value'."
    else
      echo "Failed to set $key to '$value'."
      exit 1
    fi
  done
}

function disable_settings() {
  # Settings to disable
  declare -a to_disable
  to_disable=("HostKey\s+\S+dsa_key")

  local cfg=$ETC_SSH/sshd_config

  for regex in "${to_disable[@]}"; do
      echo "Disabling $regex"
      sed -ri "s/^\s*${regex}\s*(#.*)?\$/#\0/i" $cfg
  done
}

harden_host_keys

modify_settings
disable_settings
