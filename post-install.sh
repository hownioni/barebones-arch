#!/usr/bin/env bash

source ./format.sh

print_recs() {
    txt1 "1. Don't forget to install yay! (https://github.com/Jguer/yay.git)"
    txt1 "2. Configure ly on /etc/ly/config.ini (clock format: %F %a - %r)"
    txt1 "3. Don't forget to enable reflector.timer, ly, cups, avahi-daemon and bluetooth!"
    txt2 "3a. Edit the 'hosts:' line on /etc/nsswitch.conf to this:"
    txt3 "hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns"
    txt1 "5. Create ssh keys and add them to your github account (don't forget to activate ssh-agent and config ~/.ssh)"
    txt1 "6. Clone your dotfiles with this command (And make the alias): "
    # shellcheck disable=SC2016
    txt2 'git clone --bare "$dotfiles_repo" "$HOME"/.dotfiles &>/dev/null'
    # shellcheck disable=SC2016
    txt2 'alias dotfiles='\''/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'\'''
    txt1 "7. Run 'tldr --update'"
    txt1 "8. Configure firefox (PENDING: Add which extensions I use)"
}

docli() {
    echo "Installing aur cli"

    mapfile -t cli <./packages/aur-cli

    yay -S --noconfirm "${cli[@]}"
}

dogui() {
    echo "Installing gui"

    mapfile -t gui <./packages/gui
    mapfile -t aur_gui <./packages/aur-gui

    sudo pacman -S --noconfirm "${gui[@]}"
    sudo pacman -Rns --noconfirm xterm
    yay -S --noconfirm "${aur_gui[@]}"
    sleep 5
    sudo localectl set-x11-keymap latam pc105 deadtilde
}

doconf() {
    echo "Making some directories"
    (
        cd "$HOME" || exit
        mkdir codino Games repos Documents/IRL
    )
}

printf "%s\n" "Welcome!"
PS3="Choose an option: "
menu_opts=("Recommendations" "Finish cli install with aur" "Install GUI" "Configure some stuff")

select opt in "${menu_opts[@]}"; do
    case $opt in
    "Recommendations")
        print_recs
        break
        ;;
    "Finish cli install with aur")
        docli
        break
        ;;
    "Install GUI")
        dogui
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
