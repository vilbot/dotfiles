# zsh in the "None" desktop (tty/hyprland.lua sets ZDOTDIR to this folder): your normal
# ~/.zshrc, plus session commands that work in every terminal here.
() {
    local here=$ZDOTDIR
    ZDOTDIR=$HOME  # ~/.zshrc as usual (history, completion dump in ~)
    source ~/.zshrc
    ZDOTDIR=$here  # shells started from here get these commands too
}

logout()   { qs -p ~/dotfiles/tty/shell ipc call lock lock; }  # back to the login form (a lock over None)
shutdown() { systemctl poweroff; }
poweroff() { systemctl poweroff; }
reboot()   { systemctl reboot; }

# Ctrl+D on an empty line does nothing (no closing the terminal); `exit` still closes it.
setopt ignore_eof
_tty_ctrl_d() { [[ -n $BUFFER ]] && zle delete-char-or-list; }
zle -N _tty_ctrl_d
bindkey '^D' _tty_ctrl_d
bindkey -M viins '^D' _tty_ctrl_d 2>/dev/null
