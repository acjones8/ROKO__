# Copyright 2016-2017 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: rindeal.eclass
# @MAINTAINER:
# Jan Chren (rindeal) <dev.rindeal+gentoo-overlay@gmail.com>
# @BLURB: Base eclass that should be inheritted by all ebuilds right after the EAPI specification.
# @DESCRIPTION:


# fight with portage and override it again and again
inherit portage-patches


if [[ -z "${_RINDEAL_ECLASS}" ]] ; then

case "${EAPI:-0}" in
    6) ;;
    *) die "Unsupported EAPI='${EAPI}' for '${ECLASS}'" ;;
esac


rindeal:func_exists() {
	declare -F "${1}" >/dev/null
}


### BEGIN: "Command not found" handler
if rindeal:func_exists command_not_found_handle ; then
	# portage registers a cnf handler for the `depend` phase
	# https://github.com/gentoo/portage/commit/40da7ee19c4c195da35083bf2d2fcbd852ad3846
	if [[ "${EBUILD_PHASE}" != depend ]] ; then
		eqawarn "${ECLASS}.eclass: command_not_found_handle() already registered"
	fi
else

	command_not_found_handle() {
		debug-print-function "${FUNCNAME}" "$@"
		local -r cmd="${1}"

		## do not die in a pipe
		[[ -t 1 ]] || return 127

		## do not die in a subshell
		read _pid _cmd _state _ppid _pgrp _session _tty_nr _tpgid _rest < /proc/self/stat
		(( $$ == _tpgid )) && return 127

		die "'${cmd}': command not found"
	}

fi
### END: "Command not found" handler


### BEGIN: hooking infrastructure

_rindeal:hooks:get_orig_prefix() {
	echo "__original_"
}

_rindeal:hooks:call_orig() {
	debug-print-function "${FUNCNAME}" "${@}"

	local -r -- ________f="$(_rindeal:hooks:get_orig_prefix)${1}"

	if ! rindeal:func_exists "${________f}" ; then
		die "${ECLASS}.eclass: ${FUNCNAME}: function '${________f}' doesn't exist"
	fi

	"${________f}" "${@:2}"
}

_rindeal:hooks:save() {
	debug-print-function "${FUNCNAME}" "${@}"

	(( $# != 1 )) && die

	local -r -- name="${1}"
	local -r -- orig_prefix="$(_rindeal:hooks:get_orig_prefix)"

	# make sure we don't create an infinite loop
	if ! rindeal:func_exists "${orig_prefix}${name}" ; then

		# save original implementation under a different name
		eval "${orig_prefix}$(declare -f "${name}")"
	fi
}

### END: hooking infrastructure


### BEGIN: inherit hook

_rindeal:hooks:save inherit

## "static assoc array"
if [[ -z "$(declare -p _RINDEAL_ECLASS_SWAPS 2>/dev/null)" ]] ; then
declare -g -A _RINDEAL_ECLASS_SWAPS=(
	['flag-o-matic']='flag-o-matic-patched'
	['ninja-utils']='ninja-utils-patched'
	['versionator']='versionator-patched'
)
fi

inherit() {
	local a args=()
	for a in "${@}" ; do
		if [[ ${_RINDEAL_ECLASS_SWAPS["${a}"]+exists} ]] ; then
			# unquoted variable allows us to ignore certain eclasses
			args+=( ${_RINDEAL_ECLASS_SWAPS["${a}"]} )
			# prevent infinite loops
			unset "_RINDEAL_ECLASS_SWAPS[${a}]"
		else
			args+=( "${a}" )
		fi
	done

	_rindeal:hooks:call_orig inherit "${args[@]}"
}

### END: inherit hook


### BEGIN: standard tool wrappers

# `NO_V` env var implementation for use in standard tool wrappers
_NO_V() {
	echo "$( (( NO_V )) || echo '--verbose' )"
}

epushd() {
	pushd "$@" >/dev/null || die -n
}

epopd() {
	popd "$@" >/dev/null || die -n
}

emkdir() {
	mkdir $(_NO_V) -p "${@}" || die -n
}

ecp() {
	cp $(_NO_V) "${@}" || die -n
}

emv() {
	mv $(_NO_V) "${@}" || die -n
}

echmod() {
	chmod $(_NO_V) "${@}" || die -n
}

erm() {
	rm $(_NO_V) --interactive=never --preserve-root --one-file-system "$@" || die -n
}

### END: standard tool wrappers


# this function can be used for a first line in files generated by the ebuild logic
print_generated_file_header() {
	printf "Automatically generated by %s/%s on\n" "${CATEGORY}" "${PF}" "$(date --utc --iso-8601=minutes)"
}


_RINDEAL_ECLASS=1
fi