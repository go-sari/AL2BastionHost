#!/usr/bin/env bats
# shellcheck disable=SC2086

setup_file() {
  export WORKDIR=$(mktemp -d /tmp/.XXXXX)
  cp -prv ./test/* ${WORKDIR}
}

teardown_file() {
  [[ "$WORKDIR" =~ /tmp/.* ]] && rm -rfv ${WORKDIR}
}

@test "harden SSHD configuration" {
	ROOT=${WORKDIR} ./bin/sshd_post.sh
	diff -u ${WORKDIR}/etc/ssh/sshd_config test/etc/ssh/sshd_config.expected
	diff -u ${WORKDIR}/etc/ssh/moduli test/etc/ssh/moduli.expected
	# shellcheck disable=SC2046
	run ssh-keygen -lf ${WORKDIR}/etc/ssh/ssh_host_rsa_key.pub
    [[ "$status" -eq 0 ]]
    [[ "${output%% *}" -eq 4096 ]]
}

@test "config CWAgent log access" {
    ROOT=${WORKDIR} ./bin/cwagent_post.sh
    diff -u ${WORKDIR}/etc/rsyslog.conf test/etc/rsyslog.conf.expected
}
