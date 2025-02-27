#!/usr/bin/env bash

test_ansioso_get_script() {
    _ansioso_get_script
    assertTrue "[ -r '${_ansioso_script}' ]"
}

test_ansioso_get_script_dir() {
    _ansioso_get_script
    assertTrue "[ -d '${_ansioso_script_dir}' ]"
}

test_ansioso_get_script_name() {
    _ansioso_get_script
    assertTrue "[ ! -z '${_ansioso_script_name}' ]"
}

#set -x
DIRNAME=$(dirname $BASH_SOURCE)
. $DIRNAME/../a.sh test
. shunit2
# vim: set tabstop=4 shiftwidth=4 expandtab:
