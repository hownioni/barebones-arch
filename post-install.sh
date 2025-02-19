#!/usr/bin/env bash

print_recs() {
    echo "1. Don't forget to install yay! (https://github.com/Jguer/yay.git)"
    echo "2. Configure ly on /etc/ly/config.ini (clock format: %F %a - %r)"
    echo "3. Don't forget to enable ly, cups and bluetooth!"
    echo "4a. Create ssh keys and add them to your github account (don't forget to activate ssh-agent and config ~/.ssh)"
    echo "4b. Clone your dotfiles with this command (Also make the alias <3): "
    printf "\t%s\n" 'git clone --bare "$dotfiles_repo" "$HOME"/.dotfiles &>/dev/null'
    printf "\talias dotfiles='%s'\n" '/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'
    echo "Configure firefox (PENDING: Add which extensions I use)"
}

docli() {
    echo "Installing aur cli"

    mapfile -t cli <./packages/aur-cli.txt

    yay -S --noconfirm "${cli[@]}"
}

dogui() {
    echo "Installing gui"

    mapfile -t gui <./packages/gui.txt
    mapfile -t aur_gui <./packages/aur-gui.txt

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
        mkdir codino repos Documents/IRL
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
