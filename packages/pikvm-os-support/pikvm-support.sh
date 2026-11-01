#!/bin/bash

set -eo pipefail
shopt -s lastpipe

log() {
	echo ":: $PIKVM_UPTERM_ARGV0: $*" >&2
}

dbg() {
	if [[ $PIKVM_DEBUG ]]; then
		echo "DBG: $PIKVM_UPTERM_ARGV0: $*" >&2
	fi
}

err() {
	echo "E: $PIKVM_UPTERM_ARGV0: $*" >&2
}

die() {
	err "$@"
	exit 1
}

usage() {
	if (( $# )); then
		echo "$PIKVM_UPTERM_ARGV0: $*" >&2
		echo >&2
	fi
	_usage >&2
	exit 1
}

_usage() {
	# [-k|--keep] [-A|--attach=SESSION]
	cat <<EOF
Usage: ${0##*/}

Launch a PiKVM remote support session.

Run this command if instructed to by a PiKVM remote support engineer.
After running this command, provide the session join URL that will be printed
to the remote support engineer.

WARNING: anyone who knows the session join URL will be able to remotely access
         your PiKVM and the network it is attached to. Only ever provide the
         session join URL to someone you trust.

You will be able to see all actions performed by the remote support engineer.
To forcibly terminate the session, close the web terminal.

EOF
}


#
# reexecute
#

# TODO(intelfx): invent a solution to elevate within `systemd-run`
if (( EUID != 0 )); then
	die "This script needs to be run as root. Use \`su -\` to start a root shell, or \`su -c $0\`."
fi

if ! [[ ${PIKVM_UPTERM_REEXECUTED+set} ]]; then
	PIKVM_UPTERM_ARGV0="${0##*/}"
	PIKVM_UPTERM_ID="pikvm-upterm-$$"
	exec systemd-run \
		--pty \
		--wait \
		--collect \
		--service-type=exec \
		--unit="$PIKVM_UPTERM_ID.service" \
		-p KillMode=control-group \
		-p PrivateTmp=true \
		-p User=root \
		-p SetLoginEnvironment=true \
		-E PIKVM_UPTERM_REEXECUTED=1 \
		-E PIKVM_UPTERM_ARGV0="$PIKVM_UPTERM_ARGV0" \
		-E PIKVM_UPTERM_ID="$PIKVM_UPTERM_ID" \
		${PIKVM_DEBUG:+-E PIKVM_DEBUG="$PIKVM_DEBUG"} \
		"$BASH_SOURCE" "$@"
		# XXX: using PAMName= to start a true session as root would be
		#      intuitive, but the session can survive the loss of the
		#      leader depending on logind settings, which is not what we want.
		# -p PAMName=login \
fi

#
# args
#

if args=$(getopt -o 'kA:' --long 'keep,attach:' -n "$PIKVM_UPTERM_ARGV0" -- "$@"); then
	eval set -- "$args"
else
	usage
fi
unset args

unset PIKVM_UPTERM_KEEP
unset PIKVM_UPTERM_ATTACH
while :; do
	case "$1" in
	-k|--keep)   PIKVM_UPTERM_KEEP=1 ;;
	-A|--attach) shift; PIKVM_UPTERM_ATTACH="$1" ;;
	--) shift; break ;;
	*) die "getopt error" ;;
	esac
	shift
done

case "$#" in
0) ;;
*) usage "unexpected positional arguments" ;;
esac

if [[ ${PIKVM_UPTERM_KEEP+set} ]]; then
	die "Sorry, unimplemented: -k/--keep"
fi

if [[ ${PIKVM_UPTERM_ATTACH+set} ]]; then
	die "Sorry, unimplemented: -A/--attach=${PIKVM_UPTERM_ATTACH@Q}"
fi

if ! [[ $PIKVM_UPTERM_ID ]]; then
	die "Invalid invocation: \$PIKVM_UPTERM_ID not set"
fi

if ! [[ $HOME && -d $HOME ]]; then
	die "Invalid invocation: \$HOME=$HOME not set or not a directory"
fi


#
# functions
#

check_key() {
	local k="$1"
	[[ -f "$k" && -f "$k.pub" ]] || {
		dbg "key ${k@Q}: file does not exist"
		return 1
	}
	ssh-keygen -y -f "$k" -P "" &>/dev/null || {
		dbg "key ${k@Q}: protected by a passphrase"
		return 1
	}
	return 0
}

make_key() {
	local k="$1"
	if ! ssh-keygen -t ed25519 -f "$k" -C "upterm@pikvm" -P "" >/dev/null; then
		die "failed to generate ssh key ${k@Q}, exiting"
	fi
}

choose_key() {
	local k="$1"
	if check_key "$k"; then
		PIKVM_UPTERM_KEY="$k"
		PIKVM_UPTERM_KEY_PUB="$k.pub"
		dbg "choosing key ${PIKVM_UPTERM_KEY@Q} and ${PIKVM_UPTERM_KEY_PUB@Q}"
		return 0
	fi
	return 1
}

cleanup() {
	if [[ $PIKVM_UPTERM_TMPDIR ]]; then
		rm -r "$PIKVM_UPTERM_TMPDIR"
	fi
}


#
# constants
#

PIKVM_UPTERM_HOST_FLAGS=(
	# TODO(intelfx): bring this up
	# --server "wss://upterm.pikvm.org"
	--skip-host-key-check
	--accept
)


#
# variables
#

PIKVM_UPTERM_TMPDIR=
PIKVM_UPTERM_KEY=
PIKVM_UPTERM_KEY_PUB=


#
# main
#

trap cleanup EXIT

PIKVM_UPTERM_TMPDIR="$(mktemp -d --tmpdir "$SCRIPT_NAME.XXXXXX")" \
	|| die "Failed to create a temporary directory"

PIKVM_UPTERM_KEY_OWN="${PIKVM_UPTERM_TMPDIR:?}/upterm_id_ed25519"
PIKVM_UPTERM_KEYS=(
	"${PIKVM_UPTERM_KEY_OWN:?}"
	"$HOME/.ssh/id_ed25519"
	"$HOME/.ssh/id_ecdsa"
	"$HOME/.ssh/id_rsa"
)

for k in "${PIKVM_UPTERM_KEYS[@]}"; do
	choose_key "$k" && break ||:
done

if ! [[ $PIKVM_UPTERM_KEY ]]; then
	log "no ssh key configured -- generating key ${PIKVM_UPTERM_KEY_OWN@Q}"
	make_key "${PIKVM_UPTERM_KEY_OWN:?}"
	choose_key "${PIKVM_UPTERM_KEY_OWN:?}" ||:
fi

if ! [[ $PIKVM_UPTERM_KEY ]]; then
	die "failed to find or generate ssh key, exiting"
fi

cat <<EOF

                               !!! WARNING !!!

         The session key and join URL will be printed below. Copy-paste
         everything after this warning and provide it to the support engineer.

         Anyone who knows the session join URL will be able to remotely access
         your PiKVM and the network it is attached to. Only ever provide the
         session join URL to someone you trust.

                               !!! WARNING !!!

         After the session is started, you may close the window at any time
         to forcibly interrupt the session and disconnect the remote side.

         Press any key to start the session, or Ctrl-C to abort.

EOF

read -n1 -s -r || exit

upterm host "${PIKVM_UPTERM_HOST_FLAGS[@]}" \
	# EOL
