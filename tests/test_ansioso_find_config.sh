#!/usr/bin/env bash

test_ansioso_find_config() {
    _ansioso_find_config
	assertNotEquals "${_ansioso_filename}" ''
}

#set -x
DIRNAME=$(dirname $BASH_SOURCE)
. $DIRNAME/../a.sh test
. shunit2
# vim: set tabstop=4 shiftwidth=4 expandtab:
