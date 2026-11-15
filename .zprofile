# zsh login shells. On a real console (tty1-6) after logging in: pick a desktop (tty/chooser.sh).
if [[ -o interactive && -z $WAYLAND_DISPLAY && $TTY == /dev/tty[1-6] && -r ~/dotfiles/tty/chooser.sh ]]; then
    source ~/dotfiles/tty/chooser.sh
fi
