__prompt_git_status() {
  # Generate a git branch/status prompt.
  # Based on git-prompt.sh by Shawn O. Pearce <spearce@spearce.org>.
  # Arguments:
  #   $1                            The printf format string for the prompt.  Must include %s.
  # Environment variables:
  #   GIT_PROMPT_SHOW_TYPE=1                Show type of repository (Bare, Shallow).
  #   GIT_PROMPT_SHOW_UPSTREAM=1            Show status of this repository compaired to upstream:
  #                ??                       - No upstream set.
  #                ==                       - Working tree is equal to upstream.
  #                <>                       - Divergent from upstream.
  #                >> or >x                 - Working tree is ahead of upstream
  #                                           (x = commits ahead when used with
  #                                           next option).
  #
  #                << or <x                 - Working tree is behind upstream
  #                                           (x = commits behind when used with
  #                                           next option).
  #   GIT_PROMPT_SHOW_UPSTREAM_EXTENDED=1	In addition to upstream status, show the number of commits difference (inplies above).
  #   GIT_PROMPT_SHOW_IGNORED=1             Show a ! if the current directory is ignored, or _ if the git operation was timed out.
  #   GIT_PROMPT_SHOW_UNSTAGED=1            Show a * if there are unstaged changes (superceeded by above).
  #   GIT_PROMPT_SHOW_UNCOMMITTED=1         Show a & if there are staged but uncommitted changes (superceeded by above).
  #   GIT_PROMPT_SHOW_UNTRACKED=1           Show a + if there are untracked files in the working directory (superceeded by above).
  #   GIT_PROMPT_SHOW_STASH=1               Show a $ if there is a stash in this repository (superceeded by above).
  #
  # Displays:               The printf formatted git prompt based upon $1 and the environment vaiables above, for example:
  #                         S:branch_name >5 *
  # Returns:                0 = Produced a prompt successfully.
  #                         1 = An error occured.
  local BRANCH COUNT GIT_PROMPT GIT_PROMPT_MARKER_SET GIT_REPO_INFO IFS=$'\n'

  # Bail out if there's no format argument given, or it doesn't contain %s
  (( $# !=  1 )) || [[ "$1" != *%s* ]] && return 1

  # Get some repository information.
  # shellcheck disable=SC2207
  GIT_REPO_INFO=( $( git rev-parse --is-bare-repository --is-shallow-repository --is-inside-git-dir --is-inside-work-tree 2>/dev/null) ) || return 1

  # Generate the prompt.
  if [[ "${GIT_REPO_INFO[2]}" == "true" ]]; then
    # In the git directory, use a special branch marker.
    GIT_PROMPT+="!GIT_DIR!"
  elif [[ "${GIT_REPO_INFO[3]}" == "true" ]]; then
    # In the working directory, generate the prompt.
    # Add type markers.
    [[ -n "$GIT_PROMPT_SHOW_TYPE" ]] && {
      if [[ "${GIT_REPO_INFO[0]}" == "true" ]]; then
        GIT_PROMPT+="B:"
      elif [[ "${GIT_REPO_INFO[1]}" == "true" ]]; then
        GIT_PROMPT+="S:"
      fi
    }

    # Add the branch or a no commits marker.
    BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [[ "$BRANCH" == "HEAD" ]]; then
      GIT_PROMPT+="?NO COMMITS?"

      # Output the prompt and escape early.
      # shellcheck disable=SC2059
      printf -- "$1" "$GIT_PROMPT"
      return 0
    else
      GIT_PROMPT+="$BRANCH"
    fi

    # Add upstream status.
    [[ -n "$GIT_PROMPT_SHOW_UPSTREAM" ]] || [[ -n "$GIT_PROMPT_SHOW_UPSTREAM_EXTENDED" ]] && {
      COUNT="$(git rev-list --count --left-right "${BRANCH:+refs/prefetch/remotes/origin/}${BRANCH:-@{upstream\}}...HEAD" 2>/dev/null | tr '[:blank:]' ' ')"
      case "$COUNT" in
        "")
          # No upstream.
          GIT_PROMPT+=" ??"
        ;;
        "0 0")
          # Equal to upstream.
          GIT_PROMPT+=" =="
        ;;
        "0 "*)
          # Ahead of upstream.
          GIT_PROMPT+=" >"
          if [[ -n "$GIT_PROMPT_SHOW_UPSTREAM_EXTENDED" ]]; then
            # Show the number of the difference.
            GIT_PROMPT+="${COUNT#0 }"
          else
            GIT_PROMPT+=">"
          fi
        ;;
        *" 0")
          # Behind upstream.
          GIT_PROMPT+=" <"
          if [[ -n "$GIT_PROMPT_SHOW_UPSTREAM_EXTENDED" ]]; then
            # Show the number of the difference.
            GIT_PROMPT+="${COUNT% 0}"
          else
            GIT_PROMPT+="<"
          fi
        ;;
        *)
          # Divergent from upstream.
          GIT_PROMPT+=" <>"
        ;;
      esac
    }

    # Add a marker if directory is ignored, there's unstaged files, uncommitted changes, untracked files or a stash.
    [[ -n "$GIT_PROMPT_SHOW_IGNORED" ]] && git check-ignore . >/dev/null 2>&1 && {
      GIT_PROMPT+=" !"
      GIT_PROMPT_MARKER_SET=1
    }
    [[ -z "$GIT_PROMPT_MARKER_SET" ]] && [[ -n "$GIT_PROMPT_SHOW_UNSTAGED" ]] && {
      timeout --signal=KILL 2s git ls-files --modified --exclude-standard --directory --error-unmatch -- ':/*' >/dev/null 2>&1
      ERR=$?
      if (( ERR == 124 )) || (( ERR == 137 )); then
        GIT_PROMPT+=" _"
        GIT_PROMPT_MARKER_SET=1
      elif (( ERR == 0 )); then
        GIT_PROMPT+=" *"
        GIT_PROMPT_MARKER_SET=1
      fi
    }
    [[ -z "$GIT_PROMPT_MARKER_SET" ]] && [[ -n "$GIT_PROMPT_SHOW_UNCOMMITTED" ]] && ! git diff --name-only --cached --exit-code >/dev/null 2>&1 && {
      GIT_PROMPT+=" &"
      GIT_PROMPT_MARKER_SET=1
    }
    [[ -z "$GIT_PROMPT_MARKER_SET" ]] && [[ -n "$GIT_PROMPT_SHOW_UNTRACKED" ]] && {
      timeout --signal=KILL 2s git ls-files git ls-files --others --exclude-standard --directory --error-unmatch -- ':/*' >/dev/null 2>&1
      ERR=$?
      if (( ERR == 124 )) || (( ERR == 137 )); then
        GIT_PROMPT+=" _"
        GIT_PROMPT_MARKER_SET=1
      elif (( ERR == 0 )); then
        GIT_PROMPT+=" +"
        GIT_PROMPT_MARKER_SET=1
      fi
    }
    [[ -z "$GIT_PROMPT_MARKER_SET" ]] && [[ -n "$GIT_PROMPT_SHOW_STASH" ]] && git rev-parse --verify --quiet refs/stash >/dev/null && {
      GIT_PROMPT+=" $"
      GIT_PROMPT_MARKER_SET=1
    }
  fi

  # Output the prompt.
  # shellcheck disable=SC2059
  printf -- "$1" "$GIT_PROMPT"

  return 0
}

__prompt_user_colour() {
  # Determine the colour of the username in the prompt.

  if [[ "$LOGNAME" == "root" ]]; then
    printf "%s" "1;31m"		# Bright Red.
  elif [[ "$LOGNAME" == "lv8pv" ]]; then
    printf "%s" "1;32m"		# Bright Green.
  else
    printf "%s" "1;36m"		# Bright Cyan.
  fi

  return 0
}

__git_prompt_command() {
  # Perform git actions.
  # Environment variables:
  #   GIT_DISABLE_PROMPT_PREFETCH=1	Disable automatic 'prefetch' of upstream refs.
  #					This can also be disabled on a per repository basis using:
  #						git config ---local -replace-all --type bool script.DisablePromptPrefetch true
  # Returns:				0 = Tasks completed successfully.
  #					1 = An error occured.
  local GIT_REPO_INFO LC_ALL="C" NOW REPO_TIMESTAMP TIMESTAMP_VAR

  # shellcheck disable=SC2207
  GIT_REPO_INFO=( $( git rev-parse --is-inside-work-tree --show-toplevel 2>/dev/null) ) || return 1

  # Only process if in a work directory.
  [[ "${GIT_REPO_INFO[0]}" == "true" ]] && {
    # Run prefetch tasks if not disabled.
    [[ -z "$GIT_DISABLE_PROMPT_PREFETCH" ]] && [[ "$(git config --local --get --type bool script.DisablePromptPrefetch 2>/dev/null)" != "true" ]] && {
      git maintenance run --task=prefetch 2>/dev/null || {
        printf "\\033[1;31m%s\\033[0m\\n" "Git maintenance 'prefetch' task failed." >&2
        return 1
      }
    }

    # The time now.
    if [[ "$PLATFORM" == "Linux" ]]; then
      NOW="$(date +'%s%3N')"
    elif [[ "$PLATFORM" == "Darwin" ]]; then
      NOW="$(perl -e 'use Time::HiRes; printf "%.3f", Time::HiRes::time();')"
      NOW="${NOW/.}"
    fi

    # Determine the timestamp variable name depending on bash version.
    if (( BASH_VERSINFO[0] >= 4 )); then
      TIMESTAMP_VAR="GIT_REPO_TIMESTAMP[${GIT_REPO_INFO[1]//[^[:alnum:]]/_}]"
    else
      # This is going to pollute the environment, but Darwin is a PITA.
      TIMESTAMP_VAR="GIT_REPO_TIMESTAMP_${GIT_REPO_INFO[1]//[^[:alnum:]]/_}"
    fi

    if [[ -n "${!TIMESTAMP_VAR}" ]]; then
      # Monitor the git repo.
      REPO_TIMESTAMP="$(git config --local --get --type int script.AutoMergeLast)"
      (( ${!TIMESTAMP_VAR:-0} < REPO_TIMESTAMP )) && {
        # Display message depending on status.
        if [[ "$(git config --local --get --type bool script.AutoMergeSuccess)" == "true" ]]; then
          printf "\\033[1;32m%s" "Git auto-merge succeeded for this repo."
          if [[ "${GIT_REPO_INFO[1]}" == "$HOME" ]]; then
            printf "  %s\\033[0m\\n" "Re-source .bash* files."
          else
            printf "\\033[0m\\n"
          fi
          # Update the timestamp in the environment.
          declare -g "$TIMESTAMP_VAR"="$NOW"
        else
          printf "\\033[1;31m%s\\033[0m\\n" "Git auto-merge failed for this repo - correct manually." >&2
        fi
      }
    else
      # Just set the timestamp in the environment.
      declare -g "$TIMESTAMP_VAR"="$NOW"
    fi
  }

  return 0
}
# Determine the platform being logged into.
PLATFORM="$(uname -s)"

# PROMPT_COMMAND="__nanorc_prompt_command; __ssh_agent_prompt_command; __git_prompt_command"
# The commands to execute before the prompt is displayed.
PROMPT_COMMAND="__git_prompt_command"
#
# Git prompt options.
GIT_PROMPT_SHOW_TYPE=1
GIT_PROMPT_SHOW_UPSTREAM=1
GIT_PROMPT_SHOW_UPSTREAM_EXTENDED=1
GIT_PROMPT_SHOW_IGNORED=1
GIT_PROMPT_SHOW_UNSTAGED=1
GIT_PROMPT_SHOW_UNCOMMITTED=1
GIT_PROMPT_SHOW_UNTRACKED=1
GIT_PROMPT_SHOW_STASH=1
GIT_DISABLE_PROMPT_PREFETCH=0

# Version specific set up.
if (( BASH_VERSINFO[0] >= 4 )); then
  # Add to the shopts.
  shopt -s checkjobs dirspell

  # Trim the path in the prompt.
  PROMPT_DIRTRIM=2
  # Coloured username + host + directory:
  PS1='[\[\033[$(__prompt_user_colour)\]\u\[\033[0m\]@\[\033[1;33m\]\h\[\033[0m\]] \[\033[1;34m\]\w\[\033[0m\]$(__prompt_git_status "\[\\033[1;35m\] (%s)\[\\033[0m\]")\n->'
else
  # Set the prompts.
  # Coloured username + host + directory:
  # shellcheck disable=SC2154
  PS1='[\[\033[$(__prompt_user_colour)\]\u\[\033[0m\]@\[\033[1;33m\]\h\[\033[0m\]] \[\033[1;34m\]$(printf "%s" "${PWD/#$HOME/~}" | awk -F/ '\''{if (NF>3) {printf ".../" $(NF-1) "/" $NF} else {printf $0}}'\'')\[\033[0m\]$(__prompt_git_status "\[\\033[1;35m\] (%s)\[\\033[0m\]")\n->'
fi

# Set the debugger prompt.
# shellcheck disable=SC2155
export PS4='+(\[\033[1;33m\]$?\[\033[0m\]) \[\033[1;34m\]${BASH_SOURCE##*/}\[\033[0m\]${FUNCNAME[0]:+(\[\033[1;32m\]${FUNCNAME[0]}\[\033[0m\])}:\[\033[1;31m\]$LINENO\[\033[0m\]: '

# Gen a random pw and put it in the clipboard
hash gpg >/dev/null 2>&1 && alias pw='gpg --gen-random --armor 1 30 |tr -d "\n" |xsel -ib'
hash gpg >/dev/null 2>&1 && alias genpass='gpg --gen-random --armor 1 30 |tr -d "\n" |xsel -ib'
hash mkpasswd >/dev/null 2>&1 && alias mkpasswd='mkpasswd -m sha512crypt'
hash mkpasswd >/dev/null 2>&1 && alias pwgen='mkpasswd -m sha512crypt'
hash pinfo >/dev/null 2>&1 && alias info='pinfo'
hash ping >/dev/null 2>&1 && alias ping='ping -b'
hash minicom >/dev/null 2>&1 && alias minicom='minicom -m -c on'
hash ip >/dev/null 2>&1 && alias ip='ip -color=auto'
hash iftop >/dev/null 2>&1 && alias iftop='TERM=vt100 iftop'
hash diff >/dev/null 2>&1 && alias diff='diff --color=auto -u'
hash nc >/dev/null 2>&1 && alias pastebin='nc termbin.com 9999'
hash grep >/dev/null 2>&1 && alias egrep='grep -E --color=auto'
hash grep >/dev/null 2>&1 && alias fgrep='grep -F --color=auto'
hash grep >/dev/null 2>&1 && alias grep='grep --color=auto'
hash ls >/dev/null 2>&1 && alias ls='ls -p --color=auto'
# Du sorted and in MB and GB
hash du >/dev/null 2>&1 && alias dum='du -xcms --exclude=.ccache * | sort -rn | head -n10'
hash du >/dev/null 2>&1 && alias dug='du -xcs --block-size=1G * | sort -rn | head -n10'
# Make lsblk output a bit nicer
hash lsblk >/dev/null 2>&1 && alias lsblk="lsblk -o name,size,type,fstype,mountpoint,label,uuid"
hash clear >/dev/null 2>&1 && alias c='clear'
# Default cal to month view
hash cal >/dev/null 2>&1 && alias cal='cal -m'
# Change cat to the bat 
hash bat >/dev/null 2>&1 && alias cat="bat --paging=never --style='plain' -pp $*"
# GIT aliases
hash git >/dev/null 2>&1 && alias gl="git log --all --graph"
hash git >/dev/null 2>&1 && alias gis="git status"
hash neomutt>/dev/null 2>&1 && alias mutt="neomutt"

#alias cat="bat --paging=never -pp --style='plain' --theme=TwoDark $*"

##############################
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
# Make bash a little more pleasent - these are valid for all versions.

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
# Dissable CTRL + S (suspend terminal) This helps with using CTRL + S in history
stty -ixon



vi() { nvim "$@"; }
vim() { nvim "$@"; }

# My PS1 prompth
# git_branch() {
#   git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
# }
# export PS1="[\u@\h \W]\[\033[00;32m\]\$(git_branch)\[\033[00m\]\$ "
# export PS1='\n\u@\h:\W:>$'
#
export VISUAL=nvim
export EDITOR=nvim
export PAGER=bat
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
# export TERM=screen-256color
export TERM=xterm-color
export -f vi
export PATH="$HOME/.local/bin:$PATH"
#export LESSOPEN="| grep -P 'alias|$' --color=always %s"
#export LESSOPEN="|pygmentize -g %s"
export LESSOPEN='|bat --paging=never --color=always %s'
export LESS='-R'
# I like the Default bat theme best. 
# export BAT_THEME="gruvbox-dark"
# export BAT_THEME="Nord"

# Load the .inputrc file (not sure why this is needed)
bind -f "~/.inputrc"
#
# Set vi mode in the shell
# set -o vi
# vim: ts=4 sts=4 sw=4 tw=80 cc=80 spell et
