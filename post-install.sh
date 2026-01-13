#!/usr/bin/env bash

source ./format.sh

yes_or_no() {
	while true; do
		input_print "$* [y/n]: "
		read -r yn
		case $yn in
			[Yy]*) return 0 ;; # Return 0 for 'yes'
			[Nn]*)
				return 1
				;; # Return 1 for 'no'
			*) error_print "Please answer yes or no." ;;
		esac
	done
}

print_recs() {
	txt1 "Don't forget to install an AUR client"
	txt2 'git clone https://aur.archlinux.org/paru.git'
	txt1 "Finish CLI and GUI install"
	txt1 "Configure ly on /etc/ly/config.ini (clock format: %F %a - %r) and don't forget to enable it."
	txt1 "Create ssh keys and add them to your github account (don't forget to activate ssh-agent and config ~/.ssh)"
	txt2 'ssh-keygen'
	txt1 "Clone your dotfiles with this command (And make the alias): "
	# shellcheck disable=SC2016
	txt2 'git clone --bare "$dotfiles_repo" "$HOME"/.dotfiles &>/dev/null'
	# shellcheck disable=SC2016
	txt2 'alias dotfiles='\''/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'\'''
	txt2 'dotfiles checkout -f'
	# TODO: Add which extensions I use"
	txt1 "Configure firefox"
}

docli() {
	info_print "Installing CLI stuff from AUR"
	cli_pkgs_dir="./packages/cli/"
	dev_type=$(hostnamectl chassis)

	mapfile -t pkgs <"$cli_pkgs_dir"/01-aur

	if [[ "$dev_type" == "laptop" ]]; then
		mapfile -t -O "${#pkgs[@]}" pkgs <"$cli_pkgs_dir"/10-laptop
	fi

	paru -S --needed --noconfirm "${pkgs[@]}"
}

dogui() {
	info_print "Installing GUI"
	gui_pkgs_dir="./packages/gui"
	flatpak_dir="./packages/flatpak"

	PS3="Choose graphics protocol: "
	menu_opts=("X11" "Wayland")

	mapfile -t pkgs <"$gui_pkgs_dir"/00-gui
	mapfile -t deps <"$gui_pkgs_dir"/02-depends

	if yes_or_no "Do you want to use the AUR?"; then
		mapfile -t -O "${#pkgs[@]}" pkgs <"$gui_pkgs_dir"/01-aur
	else
		sudo pacman -S --noconfirm --needed "${pkgs[@]}"
		return
	fi

	if ! pacman -Qs qtile >/dev/null && ! pacman -Qs dms-shell >/dev/null && ! pacman -Qs noctalia-shell; then
		select opt in "${menu_opts[@]}"; do
			case $opt in
				"X11")
					mapfile -t -O "${#pkgs[@]}" pkgs <"$gui_pkgs_dir"/10-x11
					break
					;;
				"Wayland")
					if yes_or_no "Do you want to use DankMaterialShell? If not, a minimal niri install with noctalia will be done"; then
						sudo pacman -S --noconfirm --asdeps go
						curl -fsSL https://install.danklinux.com | sh
					else
						mapfile -t -O "${#pkgs[@]}" pkgs <"$gui_pkgs_dir"/20-wayland
					fi
					break
					;;
				*)
					echo "Invalid option"
					;;
			esac
		done
	fi

	if yes_or_no "Do you want productivity apps?"; then
		mapfile -t -O "${#pkgs[@]}" pkgs <"$gui_pkgs_dir"/80-productivity
	fi

	if yes_or_no "Do you want games?"; then
		mapfile -t -O "${#pkgs[@]}" pkgs <"$gui_pkgs_dir"/90-games
	fi

	paru -S --sudoloop --needed --noconfirm --noconfirm "${deps[@]}"
	paru -S --sudoloop --needed --noconfirm "${pkgs[@]}"

	if yes_or_no "Do you want flatpak apps?"; then
		while read -r inst ref; do
			if [ "$inst" = "user" ]; then
				flatpak install -y --user "$ref"
			else
				flatpak install -y --system "$ref"
			fi
		done <"$flatpak_dir"/00-flatpak

		while read -r line; do
			[[ -z "$line" || "$line" =~ ^# ]] && continue
			flatpak override "$line"
		done <"$flatpak_dir"/10-overrides
	fi

	txt1 "If on X11 and keyboard's layout is latam run this:"
	txt2 'sudo localectl set-x11-keymap latam pc105 deadtilde'
}

doconf() {
	info_print "Making some directories"
	(
		cd "$HOME" || exit
		mkdir --parents codino Games repos Documents/IRL
	)
	if [[ -f /etc/paru.conf ]]; then
		sudo sed -Ei 's/^#(SudoLoop)$/\1/;s/^#(NewsOnUpgrade)$/\1/' /etc/paru.conf
	fi

	if [[ -f /etc/nsswitch.conf ]]; then
		sudo sed -Ei 's/^(hosts: mymachines).*(resolve.*)/\1 mdns_minimal [NOTFOUND = return] \2/' /etc/nsswitch.conf
	fi

	tldr --update

	services=(cups.service avahi-daemon.service bluetooth.service)
	user_services=(obex.service ssh-agent.service playerctld.service)
	for service in "${services[@]}"; do
		sudo systemctl enable "$service"
	done
	for user_service in "${user_services[@]}"; do
		systemctl --user enable "$user_service"
	done
}

printf "%s\n" "Welcome!"
PS3="Choose an option: "
menu_opts=("Finish CLI install with AUR" "Install GUI" "Recommendations" "Configure some stuff")

select opt in "${menu_opts[@]}"; do
	case $opt in
		"Finish CLI install with AUR")
			docli
			break
			;;
		"Install GUI")
			dogui
			break
			;;
		"Recommendations")
			print_recs
			break
			;;
		"Configure some stuff")
			doconf
			break
			;;
		*)
			echo "Invalid option"
			;;
	esac
done
