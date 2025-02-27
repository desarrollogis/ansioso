#!/usr/bin/env bash

_ansioso_find_config() {
    _ansioso_filename=
    _ansioso_path=$(pwd)
    while [ ! "$_ansioso_path" == '/' ]
    do
        _ansioso_filename="$_ansioso_path/ansible.cfg"
        [ -f "$_ansioso_filename" ] && break
        _ansioso_filename=
        _ansioso_path=$(dirname "$_ansioso_path")
    done
}

_ansioso_get_script() {
	READLINK=$(which greadlink)
	[ -z "$READLINK" ] && READLINK=$(which readlink)
	_ansioso_script=$("$READLINK" -f "${BASH_SOURCE[0]}")
	_ansioso_script_dir=$(dirname "$_ansioso_script")
	_ansioso_script_name=$(basename "$_ansioso_script")
}

_ansioso_install_script() {
    _ansioso_get_script
    _ansioso_link="/usr/local/bin/$_ansioso_script_name"
    [ -e "$_ansioso_link" ] \
        && echo 'Script already installed.'
    [ -e "$_ansioso_link" ] || (
        sudo ln -s "$_ansioso_script" "$_ansioso_link" \
            && echo 'Script installed.' \
            || echo 'Failed to install script.'
    )
    _ansioso_completion=
    [ -d /etc/bash_completion.d/ ] \
        && _ansioso_completion=/etc/bash_completion.d
    [ -z "$_ansioso_completion" ] \
        && [ -d /usr/local/etc/bash_completion.d/ ] \
        && _ansioso_completion=/usr/local/etc/bash_completion.d
    [ -z "$_ansioso_completion" ] \
        && echo 'No completion detected.' \
        && exit 0
    _ansioso_link="$_ansioso_completion/$_ansioso_script_name"
    [ -e "$_ansioso_link" ] \
       && echo 'Completion already installed.' \
       && exit 0
    sudo ln -s "$_ansioso_script" "$_ansioso_link" \
        && echo 'Completion installed.' \
        || echo 'Failed to install completion.'
    echo 'Reload bash to enable completion.'
}

_ansioso() {
	local cur prev script temp

	COMPREPLY=()
	cur=${COMP_WORDS[COMP_CWORD]}
	prev=${COMP_WORDS[COMP_CWORD-1]}
	script=$(which ${COMP_WORDS[0]})
	if [ -f "$script" -a -x "$script" ]
	then
		temp=
		case $COMP_CWORD in
			1)
				temp=$($script | awk '{print $2}')
				;;
			2)
				temp=
				case $prev in
					put-inventory|vim-inventory)
						temp=$($script list-inventories)
						;;
					put-playbook|vim-playbook|execute-playbook)
						temp=$($script list-playbooks)
						;;
					put-role|vim-role|test-role)
						temp=$($script list-roles)
						;;
					put-key)
						temp=$($script list-keys)
						;;
					put-user)
						temp=$($script list-users)
						;;
					ssh-server)
						temp=$($script list-servers)
						;;
				esac
				;;
		esac
		COMPREPLY=($(compgen -W "${temp}" -- ${cur}))
	fi
	return 0
}

ansioso() {
    _ansioso_find_config
	if [ ! -z "${_ansioso_filename}" ]
	then
        filename="$_ansioso_filename"
		CURRENT=$(pwd)
		ROOT=$(dirname "${filename}")
		INVENTORY=
		[ -f "${ROOT}/INVENTORY" ] && INVENTORY=$(cat "${ROOT}/INVENTORY")
		PLAYBOOK=
		[ -f "${ROOT}/PLAYBOOK" ] && PLAYBOOK=$(cat "${ROOT}/PLAYBOOK")
		ROLE=
		[ -f "${ROOT}/ROLE" ] && ROLE=$(cat "${ROOT}/ROLE")
		[ -f "${ROOT}/USER" ] && USER=$(cat "${ROOT}/USER")
		KEY=
		[ -f "${ROOT}/KEY" ] && KEY=$(cat "${ROOT}/KEY")
	fi
	case "${1}" in
		install-script)
            _ansioso_install_script
			;;
		deploy-skeleton)
			_ansioso_get_script
			rsync -av "${SCRIPTDIR}/ansible/" .
			;;
		config-show)
			[ "${filename}" = "" ] && exit 1
			echo "Current: ${CURRENT}"
			echo "Root: ${ROOT}"
			echo "Inventory: ${INVENTORY}"
			echo "Playbook: ${PLAYBOOK}"
			echo "Role: ${ROLE}"
			echo "User: ${USER}"
			echo "Key: ${KEY}"
			;;
		list-inventories)
			[ "${filename}" = "" ] && exit 1
			ls -1 "${ROOT}/inventories/"
			;;
		list-playbooks)
			[ "${filename}" = "" ] && exit 1
			cd "${ROOT}/playbooks" && ls -1 *yaml
			;;
		list-roles)
			[ "${filename}" = "" ] && exit 1
			ls -1 "${ROOT}/roles/"
			;;
		list-servers)
			[ "${filename}" == "" ] && exit 1
			HOSTS="${ROOT}/inventories/${INVENTORY}/hosts"
			[ -f "${HOSTS}.yaml" ] \
				&& (cat "${HOSTS}.yaml" | yq -r '.[].hosts | keys | .[]') \
				&& exit 0
			[ -f "${HOSTS}" ] \
				&& (cat "${HOSTS}" | awk '{print $1}') \
				&& exit 0
			exit 1
			;;
		list-users)
			[ "${filename}" == "" ] && exit 1
			HOSTS="${ROOT}/inventories/${INVENTORY}/hosts"
			[ -f "${HOSTS}.yaml" ] \
				&& (cat "${HOSTS}.yaml" | yq -r '.[].hosts.[].ansible_user') \
				&& exit 0
			[ -f "${HOSTS}" ] \
				&& (cat "${HOSTS}" | sed -rn 's/.+ansible_user=(.*)/\1/p') \
				&& exit 0
			exit 1
			;;
		list-keys)
			[ "${filename}" = "" ] && exit 1
			cd "${ROOT}/keys" && ls -1 *pem
			;;
		put-inventory)
			[ "${filename}" = "" ] && exit 1
			[ -d "${ROOT}/inventories/${2}" ] || mkdir -p "${ROOT}/inventories/${2}"
			touch "${ROOT}/inventories/${2}/hosts"
			echo "${2}" > "${ROOT}/INVENTORY"
			;;
		put-user)
			[ "${filename}" = "" ] && exit 1
			echo "${2}" > "${ROOT}/USER"
			;;
		put-playbook)
			[ "${filename}" = "" ] && exit 1
			if [ ! -f "${ROOT}/playbooks/${2}" ]
			then
				touch "${ROOT}/playbooks/${2}"
			fi
			echo "${2}" > "${ROOT}/PLAYBOOK"
			;;
		put-role)
			[ "${filename}" = "" ] && exit 1
			if [ ! -d "${ROOT}/roles/${2}" ]
			then
				mkdir -p "${ROOT}/roles/${2}/tasks"
				touch "${ROOT}/roles/${2}/tasks/main.yaml"
			fi
			echo "${2}" > "${ROOT}/ROLE"
			;;
		put-key)
			[ "${filename}" = "" ] && exit 1
			echo "${2}" > "${ROOT}/KEY"
			;;
		test-role)
			[ "${filename}" = "" ] && exit 1
			[ ! "${2}" = "" ] && ROLE="${2}"
			[ -d "${ROOT}/roles/${ROLE}" ] && [ ! -f "${ROOT}/playbooks/${ROLE}.yaml" ] && echo -e "---\n- hosts: all\n  roles:\n    - ${ROLE}" > "${ROOT}/playbooks/${ROLE}.yaml"
			;;
		ssh-server)
			[ "${filename}" = "" ] && exit 1
			[ "${2}" = "" ] && exit 1
			SSH=
			if [ -f "${ROOT}/inventories/${INVENTORY}/hosts" ]
			then
				SSH=$(cat "${ROOT}/inventories/${INVENTORY}/hosts" | grep "${2}" | sed -rn 's/.+ansible_user=(.*)/\1/p')
			fi
			[ "${SSH}" = "" ] && SSH="${USER}"
			[ ! "${SSH}" = "" ] && SSH="${SSH}@"
			[ -f "${ROOT}/keys/${KEY}" ] && SSH="-i ${ROOT}/keys/${KEY} ${SSH}"
			echo ssh ${SSH}${2}
			ssh ${SSH}${2}
			;;
		execute-playbook)
			[ -z "${filename}" ] && exit 1
			[ -z "${2}" ] || PLAYBOOK="${2}"
			[ -f "${ROOT}/inventories/${INVENTORY}/hosts" ] \
				&& [ -f "${ROOT}/playbooks/${PLAYBOOK}" ] \
				|| exit 1
			cd "${ROOT}"
			ANSIBLE=
			[ -f "${ROOT}/keys/${KEY}" ] \
				&& ANSIBLE="--private-key ${ROOT}/keys/${KEY} "
			ANSIBLE="$ANSIBLE-i inventories/${INVENTORY}/hosts"
			ANSIBLE="$ANSIBLE playbooks/${PLAYBOOK}"
			echo ansible-playbook $ANSIBLE
			ansible-playbook $ANSIBLE
			;;
		execute-playbook-continue)
			[ "${filename}" = "" ] && exit 1
			if [ ! "${2}" = "" ]
			then
				PLAYBOOK="${2}"
			fi
			[ -d "${ROOT}/inventories/${INVENTORY}" ] && [ -f "${ROOT}/playbooks/${PLAYBOOK}" ] || exit 1
			cd "${ROOT}"
			ansible-playbook -i "inventories/${INVENTORY}" "playbooks/${PLAYBOOK}"
			;;
		vim-inventory)
			[ "${filename}" = "" ] && exit 1
			if [ ! "${2}" = "" ]
			then
				INVENTORY="${2}"
			fi
			[ -d "${ROOT}/inventories/${INVENTORY}" ] && cd "${ROOT}/inventories/${INVENTORY}" && vim hosts || exit 1
			;;
		vim-playbook)
			[ "${filename}" = "" ] && exit 1
			if [ ! "${2}" = "" ]
			then
				PLAYBOOK="${2}"
			fi
			[ -f "${ROOT}/playbooks/${PLAYBOOK}" ] && cd "${ROOT}/playbooks" && vim "${PLAYBOOK}" || exit 1
			;;
		vim-role)
			[ "${filename}" = "" ] && exit 1
			if [ ! "${2}" = "" ]
			then
				ROLE="${2}"
			fi
			[ -d "${ROOT}/roles/${ROLE}" ] && cd "${ROOT}/roles/${ROLE}" && vim "tasks/main.yaml" || exit 1
			;;
		*)
			echo "${0} install-script"
			echo "${0} deploy-skeleton"
			echo "${0} config-show"
			echo "${0} list-inventories"
			echo "${0} list-playbooks"
			echo "${0} list-roles"
			echo "${0} list-servers"
			echo "${0} list-users"
			echo "${0} list-keys"
			echo "${0} put-inventory"
			echo "${0} put-playbook"
			echo "${0} put-role"
			echo "${0} put-user"
			echo "${0} put-key"
			echo "${0} test-role"
			echo "${0} ssh-server"
			echo "${0} execute-playbook"
			echo "${0} execute-playbook-continue"
			echo "${0} vim-inventory"
			echo "${0} vim-playbook"
			echo "${0} vim-role"
	esac
}

[ "$1" == 'test' ] && return 0
SCRIPT=$(echo "${0}" | grep '\.sh$')
if [ "${SCRIPT}" == '' ]
then
	complete -F _ansioso a.sh
	return 0
fi
ansioso "${1}" "${2}"
exit 0
# vim: set tabstop=4 shiftwidth=4 expandtab:
