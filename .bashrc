# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

export PATH="$PATH:/opt/nvim-linux-x86_64/bin"

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
. "$HOME/.cargo/env"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Compile all Java files
alias jc='javac -d target/classes src/main/java/**/*.java'

# Run a Java class by path
# Usage: jr f3.TestsNB7  or  jr LABA.uppg4.Airport
alias jr='java -server -cp target/classes'

