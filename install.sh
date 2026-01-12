#!/usr/bin/env bash

# With code borrowed (stolen) from https://github.com/classy-giraffe/easy-arch/
# It'll be commented with # classy-giraffe to credit the snippets I used

source ./format.sh

# Setting up a password for the user account (function).
# classy-giraffe
userpass_selector() {
	input_print "Please enter name for a user account (enter empty to not create one): "
	read -r username
	if [[ -z "$username" ]]; then
		return 0
	fi
	input_print "Please enter a password for $username (you're not going to see the password): "
	read -r -s userpass
	if [[ -z "$userpass" ]]; then
		echo
		error_print "You need to enter a password for $username, please try again."
		return 1
	fi
	echo
	input_print "Please enter the password again (you're not going to see it): "
	read -r -s userpass2
	echo
	if [[ "$userpass" != "$userpass2" ]]; then
		echo
		error_print "Passwords don't match, please try again."
		return 1
	fi
	return 0
}

# Setting up a password for the root account (function).
# classy-giraffe
rootpass_selector() {
	input_print "Please enter a password for the root user (you're not going to see it): "
	read -r -s rootpass
	if [[ -z "$rootpass" ]]; then
		echo
		error_print "You need to enter a password for the root user, please try again."
		return 1
	fi
	echo
	input_print "Please enter the password again (you're not going to see it): "
	read -r -s rootpass2
	echo
	if [[ "$rootpass" != "$rootpass2" ]]; then
		error_print "Passwords don't match, please try again."
		return 1
	fi
	return 0
}

# Microcode detector (function).
# classy-giraffe
microcode_detector() {
	CPU=$(grep vendor_id /proc/cpuinfo)
	if [[ "$CPU" == *"AuthenticAMD"* ]]; then
		info_print "An AMD CPU has been detected, the AMD microcode will be installed."
		microcode="amd-ucode"
	else
		info_print "An Intel CPU has been detected, the Intel microcode will be installed."
		microcode="intel-ucode"
	fi
}

# User enters a hostname (function).
# classy-giraffe
hostname_selector() {
	input_print "Please enter the hostname: "
	read -r hostname
	if [[ -z "$hostname" ]]; then
		error_print "You need to enter a hostname in order to continue."
		return 1
	fi
	return 0
}

# User chooses locale (function)
# classy-giraffe
locale_selector() {
	input_print "Please write the locales you use (example format: en_US.UTF-8), the first one will be used for locale.conf. Press Ctrl+D when finished: "
	mapfile -t locales
	for locale in "${locales[@]}"; do
		if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<<"$locale")" /etc/locale.gen; then
			error_print "Locale ${locale} doesn't exist."
			return 1
		else
			sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
		fi
	done
	echo "LANG=${locales[0]}" >/mnt/etc/locale.conf
	return 0
}

# User chooses the console keyboard layout (function).
# classy-giraffe
keyboard_selector() {
	input_print "Please insert the keyboard layout to use in console (enter empty to use US, or \"/\" to look up for keyboard layouts): "
	read -r kblayout
	case "$kblayout" in
		'')
			kblayout="us"
			info_print "The standard US keyboard layout will be used."
			return 0
			;;
		'/')
			localectl list-keymaps
			clear
			return 1
			;;
		*)
			if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
				error_print "The specified keymap doesn't exist."
				return 1
			fi
			info_print "Changing console layout to $kblayout."
			loadkeys "$kblayout"
			return 0
			;;
	esac
}

print_recs() {
	ram_total=$(free -h | awk '/Mem:/{print $2}')
	ram_total=${ram_total//[^0-9.0-9]/}
	ram_total=$(printf "%1.f" "$ram_total")
	sswap=$(echo "$ram_total" | awk '{print sqrt($0)}')
	sswap=$(printf "%1.f" "$sswap")
	hswap=$((sswap + ram_total))

	txt1 "Do install to /mnt first!"
	txt1 "Recommended swap size: $sswap ($hswap if hibernating)"
	txt1 "Don't forget to add your user to the wheel group on the sudoers file"
	txt1 "On the sudoers file add the following lines:"
	txt2 'Defaults passwd_timeout=0'
	txt2 'Defaults pwfeedback'
	txt1 "Generate fstab"
	txt1 "Set up the bootloader"
}

doinstall() {
	info_print "Preparing pacstrap"
	cli_pkgs_dir="./packages/cli/"

	mapfile -t pkgs <"$cli_pkgs_dir"/00-cli
	microcode_detector
	pkgs+=("$microcode")
	pacstrap -K /mnt "${pkgs[@]}"
}

doconf() {
	info_print "Enabling NetworkManager"
	systemctl enable NetworkManager --root=/mnt

	until locale_selector; do :; done
	until keyboard_selector; do :; done
	echo "KEYMAP=$kblayout" >/mnt/etc/vconsole.conf

	until hostname_selector; do :; done
	echo "$hostname" >/mnt/etc/hostname

	info_print "Generating fstab."
	genfstab -U /mnt >>/mnt/etc/fstab

	until userpass_selector; do :; done
	until rootpass_selector; do :; done

	info_print "Configuring timezone and whatnot"
	arch-chroot /mnt /bin/bash -e <<-EOF
		ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime
		hwclock --systohc
		locale-gen

		mkinitcpio -P

		grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB
		grub-mkconfig -o /boot/grub/grub.cfg
	EOF

	info_print "Setting root password."
	echo "root:$rootpass" | arch-chroot /mnt chpasswd

	cat >/mnt/etc/sudoers.d/tweaks <<-EOF
		Defaults passwd_timeout=0
		Defaults pwfeedback
	EOF

	if [[ -n "$username" ]]; then
		echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/wheel
		info_print "Adding the user $username to the system with root privilege."
		arch-chroot /mnt useradd -m -G wheel,games -s /bin/bash "$username"
		info_print "Setting user password for $username."
		echo "$username:$userpass" | arch-chroot /mnt chpasswd
	fi

	# Pacman eye-candy features.
	info_print "Enabling colors, multilib, animations, and parallel downloads for pacman."
	sed -Ei 's/^#(VerbosePkgLists)$/\1/;s/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
	arch-chroot /mnt /bin/bash -e <<-EOF
		pacman -Sy &>/dev/null
	EOF

	# Disabling debug packages for yay
	info_print "Disabling makepkg debug packages and activating parallel compilation"
	# shellcheck disable=SC2016
	sed -Ei 's/ (debug lto)/ !\1/;s/^#(MAKEFLAGS=).*/\1\"--jobs=\$(nproc)\"/' /mnt/etc/makepkg.conf # ignore

	# Better history
	info_print "Enabling better history search"
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

	info_print "Enabling Reflector"
	systemctl enable "reflector.timer" --root=/mnt

	info_print "Done!"
}

printf "%s\n" "Welcome!"
PS3="Choose an option: "
menu_opts=("Install to /mnt" "Recommendations" "Configure")

select opt in "${menu_opts[@]}"; do
	case $opt in
		"Install to /mnt")
			doinstall
			break
			;;
		"Recommendations")
			print_recs
			break
			;;
		"Configure")
			doconf
			break
			;;
		*)
			error_print "Invalid option"
			;;
	esac
done
