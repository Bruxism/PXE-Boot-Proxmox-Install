#!/bin/bash
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

TEMPLATE_DIR="${SCRIPT_DIR}"
declare -x AUTHORIZED_KEYS="$(cat "${TEMPLATE_DIR}"/authorized_keys)"

OUTPUT_DIR="${SCRIPT_DIR}"/..

# `set -a` to automatically export all following declared variables, and
#		then `set +a` to turn that off
set -a

# Customize these as needed
# $SERVER is optional if HTTP, TFTP, GATEWAY, and DNS are all the same IP
# 	In which case, you may set SERVER and any of the exceptions
#		 which will then take precedence
SERVER=

HTTP_IP=
HTTP_PORT=
TFTP_IP=

HOSTNAME=
HOST_DOMAIN=

HOST_IP=
HOST_NETMASK=
HOST_GATEWAY=
HOST_DNS=

set +a

declare -a TEMPLATE_FILES=(
	"autoexec.ipxe" \
	"preseed.cfg" \
	"proxmoxinstall.sh" \
	"authorized_keys" )

declare -a TEMPLATE_PATHS=("${TEMPLATE_FILES[@]/#/$TEMPLATE_DIR/}")

main() {
local template
declare -x root_hash="$(ask_password)"
mkdir -p "${OUTPUT_DIR}"

# Fill out $SERVER for NUL server IP addresses
server_fill_vars

# Runs the substitutions of the declared customized variables at the top of
#		this script
for template in "${TEMPLATE_PATHS[@]}"; do
	envsubst < "${template}" > "${OUTPUT_DIR}"/"$(basename ${template})"
done
}

server_fill_vars() {
HTTP_IP=${HTTP_IP:=${SERVER}}
TFTP_IP=${TFTP_IP:=${SERVER}}
HOST_GATEWAY=${HOST_GATEWAY:=${SERVER}}
HOST_DNS=${HOST_DNS:=${SERVER}}
}

# Asks for and automatically converts the prompted password to hash
#  for the root password set in `preseed.cfg`
# I made it a point to use a subshell `$()` and 
#  to command from read to printf to pipe to `-stdin` in openssl
#  in order to maximize security
# 	This way, variables are certainly transient, and since `printf`
#	 is a builtin, a 'new' command isn't issued that shows
#	 the cleartext password
ask_password() {
	local root_password test_password pass_type pass_salt pass_hash \
	 root_hash test_hash
	local -i first=1

	until [ "${first}" -eq 0 ] && \
	 [ "${root_hash}" = "${test_hash}" ]; do
		first=0

		root_hash=$({
			IFS= read -rsp 'Password: ' root_password
			printf '%s' "${root_password}" |
			openssl passwd -6 -stdin
			})
		echo >&2
		# `echo` because otherwise CLI prompt doesn't start on newline
		#   and >&2 because the only stdout we want is the final hash in
		#   the `printf` below
		
		# These use bash shell expansions to cut around the dollar signs
		#  that delimit sections (type, salt, and) of the hash itself
		# See: https://web.archive.org/web/20260930110318/https://www.gnu.org/software/bash/manual/bash.html#:~:text=%24{parameter%23%23word}
		pass_type="${root_hash#\$}"
		pass_type="${pass_type%%\$*}"

		pass_salt="${root_hash#*\$}"
		pass_salt="${pass_salt#*\$}"
		pass_salt="${pass_salt%%\$*}"

		pass_hash="${root_hash#*\$}"
		pass_hash="${pass_hash#*\$}"
		pass_hash="${pass_hash#*\$}"

		test_hash=$({	
			IFS= read -rsp 'Password: ' test_password
			printf '%s' "${test_password}" |
			openssl passwd -"${pass_type}" \
			-salt "${pass_salt}" \
			-stdin
			})
		echo >&2  

		[ "${root_hash}" != "${test_hash}" ] && \
		 echo "Passwords mismatch; try again" >&2
	done

	printf '%s' "${root_hash}"
}

main