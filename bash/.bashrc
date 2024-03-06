/usr/bin/xset r rate 220 60
# Disable the Caps lock key
/usr/bin/setxkbmap -option "ctrl:nocaps"

# Paste image from CLI to imagebin.ca - got this from Tadgy
imagebin() {
  [[ -z "$1" ]] && { printf "%s: %s\\n" "Usage" "${FUNCNAME[0]} <filename>" >&2; return 1; }
  curl -F file="@${1:-}" https://imagebin.ca/upload.php | grep ^url: | cut -d: -f2-
}

# Create a bind for yanking the current command line into the X11 clipboard
# using `CTRL + y`. You can then paste it to the term with `SHIFT + CTRL + v`
# or normally with `p` and `P` in vim.
if [[ -n $DISPLAY ]]; then
  copy_line_to_x_clipboard () {
    printf %s "$READLINE_LINE" | xclip -selection CLIPBOARD
  }
  bind -x '"\C-y": copy_line_to_x_clipboard'
fi



# Make bash a little more pleasant - these are valid for all versions.
# got this from Tadgy
shopt -s cdspell checkhash checkwinsize cmdhist histappend no_empty_cmd_completion

# Exit the shell on a Ctl+D. got this from Tadgy
IGNOREEOF=0
# History control.
HISTCONTROL=ignoredups:erasedups
HISTFILE="$HOME/.bash_history-${HOSTNAME%%.*}"
HISTFILESIZE=100000
HISTIGNORE="bg:bg *:fg:fg *:jobs:exit:clear:history"
HISTSIZE=-1
HISTTIMEFORMAT="%d/%m/%y %H:%M:%S  "
history -r

alias ls='ls -p --color=auto'
alias c='clear'

# Gen a random pw
alias gpp='gpg --gen-random --armor 1 30'
#
# Gen a random pw and put it in the clipboard
alias pw='gpg --gen-random --armor 1 30 |tr -d "\n" |xsel -ib'

# Gen 40 x  random pw with pwgen
alias genpass='pwgen -cns -C 30'

# Make lsblk output a bit nicer
alias lsblk="lsblk -o name,size,type,fstype,mountpoint,label,uuid"

# Du sorted and in MB and GB
alias dum='du -xcms --exclude=.ccache * | sort -rn | head -n10'
alias dug='du -xcs --block-size=1G * | sort -rn | head -n10'

# Default cal to month view
alias cal='cal -m'

# Change cat to the bat 
alias cat="bat --paging=never -pp --style='plain' $*"
#alias cat="bat --paging=never -pp --style='plain' --theme=TwoDark $*"

hash nc >/dev/null 2>&1 && alias pastebin='nc termbin.com 9999'
hash grep >/dev/null 2>&1 && alias egrep='grep -E --color=auto'
hash grep >/dev/null 2>&1 && alias fgrep='grep -F --color=auto'
hash grep >/dev/null 2>&1 && alias grep='grep --color=auto'

vi() { nvim "$@"; }
vim() { nvim "$@"; }

# My PS1 prompth
git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
export PS1="[\u@\h \W]\[\033[00;32m\]\$(git_branch)\[\033[00m\]\$ "
# export PS1='\n\u@\h:\W:>$'
#
export VISUAL=nvim
export EDITOR=nvim
export PAGER=bat
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export TERM='screen-256color'
export -f vi
export PATH="$HOME/.local/bin:$PATH"
#export LESSOPEN="| grep -P 'alias|$' --color=always %s"
#export LESSOPEN="|pygmentize -g %s"
export LESSOPEN='|bat --paging=never --color=always %s'
export LESS='-R'

# vim: ts=4 sts=4 sw=4 tw=80 cc=80 spell et
