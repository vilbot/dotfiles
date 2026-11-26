zmodload zsh/datetime
export PATH="$HOME/.local/bin:$HOME/.local/share/bob/nvim-bin:$PATH"
export EDITOR=nvim
export SUDO_EDITOR="$HOME/.local/share/bob/nvim-bin/nvim"

pdf() {
  nohup zathura "$@" >/dev/null 2>&1 &!
}

[[ $OSTYPE == darwin* ]] && is_mac=1 || is_mac=0

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

if (( is_mac )); then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Docker Desktop CLI completions
    fpath=("$HOME/.docker/completions" $fpath)
    export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"
    export PATH="$PATH:$HOME/.lmstudio/bin"
    zsh_plugins="$(brew --prefix)/share"
else
    zsh_plugins=/usr/share/zsh/plugins
fi

autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

bindkey -e

if (( is_mac )) && [[ -f "$(brew --prefix)/etc/profile.d/z.sh" ]]; then
    source "$(brew --prefix)/etc/profile.d/z.sh"
fi

autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats '(%b)'
setopt PROMPT_SUBST

_cmd_start=0
preexec() {
    print -Pn "\e]0;$1\a"
    _cmd_start=$EPOCHREALTIME
}
precmd() {
    vcs_info
    print -Pn "\e]0;%1~\a"
    if (( _cmd_start > 0 )); then
        local elapsed=$(printf "%.0f" $(( (EPOCHREALTIME - _cmd_start) * 1000 )))
        _cmd_duration="${elapsed}ms"
        _cmd_start=0
    else
        _cmd_duration=""
    fi
}

NEWLINE=$'\n'
PROMPT='%F{green}%~%f ${vcs_info_msg_0_}${NEWLINE}> '
RPROMPT='%F{#787878}$_cmd_duration'

# Plugins last: syntax highlighting has to be sourced after everything else.
[[ -f $zsh_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source $zsh_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
if [[ -f $zsh_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source $zsh_plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    ZSH_HIGHLIGHT_STYLES[arg0]='fg=magenta'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=magenta,underline'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=white'
fi
unset zsh_plugins

# Android SDK (wherever its installer put it on this OS)
for d in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
    [[ -d $d ]] && export ANDROID_HOME=$d && break
done
[[ -n $ANDROID_HOME ]] && path+=("$ANDROID_HOME/emulator" "$ANDROID_HOME/platform-tools")
unset d

# Never list the same directory twice in PATH.
typeset -U path
