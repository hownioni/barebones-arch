#!/usr/bin/env bash

source ./format.sh

# Microcode detector (function).
microcode_detector() {
	CPU=$(grep vendor_id /proc/cpuinfo)
	if [[ "$CPU" == *"AuthenticAMD"* ]]; then
		echo "An AMD CPU has been detected, the AMD microcode will be installed."
		microcode="amd-ucode"
	else
		echo "An Intel CPU has been detected, the Intel microcode will be installed."
		microcode="intel-ucode"
	fi
}

print_recs() {
	ram_total=$(free -h | awk '/Mem:/{print $2}')
	ram_total=${ram_total//[^0-9.0-9]/}
	ram_total=$(printf "%1.f" "$ram_total")
	sswap=$(echo "$ram_total" | awk '{print sqrt($0)}')
	sswap=$(printf "%1.f" "$sswap")
	hswap=$((sswap + ram_total))

	txt1 "Recommended swap size: $sswap ($hswap if hibernating)"
	txt1 "Don't forget to add your user to the wheel group on the sudoers file"
	txt1 "On the sudoers file add the following lines:"
	txt2 'Defaults passwd_timeout=0'
	txt2 'Defaults pwfeedback'
	txt1 "Generate fstab"
	txt1 "Set up the bootloader"
}

doinstall() {
	echo "Preparing pacstrap"
	cli_pkgs_dir="./packages/cli/"

	mapfile -t pkgs <"$cli_pkgs_dir"/00-cli
	microcode_detector
	pkgs+=("$microcode")
	pacstrap -K /mnt "${pkgs[@]}"
}

doconf() {
	# Pacman eye-candy features.
	echo "Enabling colors, multilib, animations, and parallel downloads for pacman."
	sed -Ei 's/^#(VerbosePkgLists)$/\1/;s/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
	arch-chroot /mnt /bin/bash -e <<-EOF
		pacman -Sy &>/dev/null
	EOF

	# Disabling debug packages for yay
	echo "Disabling makepkg debug packages and activating parallel compilation"
	# shellcheck disable=SC2016
	sed -Ei 's/ (debug lto)/ !\1/;s/^#(MAKEFLAGS=).*/\1\"--jobs=\$(nproc)\"/' /mnt/etc/makepkg.conf # ignore

	# Better history
	echo "Enabling better history search"
	cat >/mnt/etc/profile.d/bash_history.sh <<-EOF
		# Save 10,000 lines of history in memory
		export HISTSIZE=10000
		# Save 200,000 lines of history to disk (will have to grep ~/.bash_history for full listing)
		export HISTFILESIZE=200000
		# Append to history instead of overwrite
		shopt -s histappend
		# Ignore redundant or space commands
		export HISTCONTROL=ignoreboth
		# Ignore more
		export HISTIGNORE='ls:ll:la:pwd:clear:history'
		# Set time format
		export HISTTIMEFORMAT='%F %T '
		# Multiple commands on one line show up as a single line
		shopt -s cmdhist
		# Append new history lines, clear the history list, re-read the history list, print prompt.
		export PROMPT_COMMAND="history -a; history -c; history -r; \$PROMPT_COMMAND"
	EOF
}

printf "%s\n" "Welcome!"
PS3="Choose an option: "
menu_opts=("Recommendations" "Install to /mnt" "Configure")

select opt in "${menu_opts[@]}"; do
	case $opt in
		"Recommendations")
			print_recs
			break
			;;
		"Install to /mnt")
			doinstall
			break
			;;
		"Configure")
			doconf
			break
			;;
		*)
			echo "Invalid option"
			;;
	esac
done
