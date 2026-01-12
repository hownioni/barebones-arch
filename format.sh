# shellcheck shell=bash
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
# classy-giraffe
info_print() {
	printf "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] %s${RESET}\n" "$1"
}

# Pretty print for input (function).
# classy-giraffe
input_print() {
	printf "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] %s${RESET}" "$1"
}

# Alert user of bad input (function).
# classy-giraffe
error_print() {
	printf "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] %s${RESET}\n" "$1"
}

txt1() {
	text="$1"
	printf '%-s● %s\n' ' ' "$text"
}

txt2() {
	text="$1"
	printf '%-4s○ %s\n' ' ' "$text"
}

txt3() {
	text="$1"
	printf '%-8s■ %s\n' ' ' "$text"
}
