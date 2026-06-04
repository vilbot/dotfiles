zmodload zsh/datetime
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
export EDITOR=nvim

autoload -Uz compinit && compinit -C
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

bindkey -e
bindkey '^[f' vi-forward-word

eval "$(/opt/homebrew/bin/brew shellenv)"

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

if [ -f "$(brew --prefix)/etc/profile.d/z.sh" ]; then
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

ZSH_HIGHLIGHT_STYLES[arg0]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=white'
