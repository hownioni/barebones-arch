#!/usr/bin/env bash
# shellcheck disable=SC2016

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

dotfiles() {
	/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" "$@"
}

print_recs() {
	txt1 "Don't forget to install an AUR client"
	txt2 'git clone https://aur.archlinux.org/paru.git'
	txt1 "Finish CLI and GUI install"
	txt1 "Configure ly on /etc/ly/config.ini (clock format: %F %a - %r) and don't forget to enable it."
	txt1 "Create ssh keys and add them to your github account (don't forget to activate ssh-agent and config ~/.ssh)."
	txt2 'ssh-keygen'
	txt2 "With ssh-agent active:"
	txt2 'ssh-add .ssh/$ssh_key_file'
	txt1 "Afterwards change the repos to use ssh."
	txt2 'git remote set-url origin git@github.com:$USER/$REPO'
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

	paru -S --sudoloop --needed --noconfirm "${pkgs[@]}"
}

dogui() {
	info_print "Installing GUI"
	gui_pkgs_dir="./packages/gui"
	flatpak_dir="./packages/flatpak"

	PS3="Choose graphics protocol: "
	menu_opts=("X11" "Wayland")

	mapfile -t pkgs <"$gui_pkgs_dir"/00-gui
	mapfile -t -O "${#pkgs[@]}" pkgs <"$gui_pkgs_dir"/01-aur

	if ! pacman -Qs qtile >/dev/null && ! pacman -Qs dms-shell >/dev/null; then
		select opt in "${menu_opts[@]}"; do
			case $opt in
				"X11")
					mapfile -t -O "${#pkgs[@]}" pkgs <"$gui_pkgs_dir"/10-x11
					break
					;;
				"Wayland")
					paru -S --sudoloop --needed --asdeps - <"$gui_pkgs_dir"/20-dms-deps
					curl -fsSL https://install.danklinux.com | sh
					break
					;;
				*)
					echo "Invalid option"
					return 1
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

	paru -S --sudoloop --needed --asdeps - <"$gui_pkgs_dir"/02-depends
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

	sudo usermod -aG gamemode "$USER"

	dotfiles_repo="https://github.com/hownioni/dotfiles.git"
	wallpaper_repo="https://github.com/hownioni/Walls.git"

	git clone --bare "$dotfiles_repo" "$HOME/.dotfiles/" &>/dev/null
	dotfiles checkout -f
	dotfiles config --local status.showUntrackedFiles no

	[[ ! -d "$HOME/Pictures/" ]] && mkdir "$HOME/Pictures/"
	git clone "$wallpaper_repo" "$HOME/Pictures/Wallpapers/" &>/dev/null

	services=(cups.service avahi-daemon.service bluetooth.service)
	user_services=(obex.service ssh-agent.service playerctld.service)
	dev_type=$(hostnamectl chassis)
	if [[ "$dev_type" == "laptop" ]]; then
		sudo systemctl unmask power-profiles-daemon.service
		services+=(power-profiles-daemon.service)
	fi
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
