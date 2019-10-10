# File .zshrc; zsh initialization script
#
# Based on https://github.com/romkatv/dotfiles-public/blob/master/.zshrc

# Start zsh tracing (if enabled)
if [[ "${ZSH_TRACE}" == 'true' ]]; then
  zmodload zsh/datetime
  setopt PROMPT_SUBST
  PS4='+$EPOCHREALTIME %N:%i> '

  logfile=$(mktemp zsh_profile.XXXXXXXX)
  echo "Logging to $logfile"
  exec 3>&2 2>$logfile

  setopt XTRACE
fi

# Start zsh profiling (if enabled)
if [[ "${ZSH_ZPROF}" == 'true' ]]; then
  zmodload zsh/zprof
fi

[[ "${TERM}" == xterm* ]] || : ${PURE_POWER_MODE:=portable}

# Helper functions for sourcing file
fn.source() {
  [[ -f "${1}" ]] && source "${1}"
}

_fn.import() {
  cd "${ZDOTDIR}/zshrc"

  # Exclude linux-specific distro file from sourced
  for file in $(find . -type f ! -name '20-linux-*.zsh' | sort); do
    source "${file}"
  done; cd
}

# Set path as array-unique-special (no duplicates)
typeset -aU path

# Load os specific file and other zsh scripts
# Order of imports will be sequential according to prefix number
_fn.import

# Initialize zsh auto complete
autoload -Uz compinit; compinit

# Load regex module
autoload -U regexp-replace

# Disable highlighting of text pasted into the command line.
zle_highlight=('paste:none')

# On every prompt, set terminal title to "user@host: cwd".
function set-term-title() { print -Pn '\e]0;%n@%m: %~\a' }
add-zsh-hook precmd set-term-title

ZLE_RPROMPT_INDENT=0          # don't leave an empty space after right prompt
READNULLCMD="${PAGER}"        # use the default pager instead of `more`
WORDCHARS=''                  # only alphanums make up words in word-based zle widgets
ZLE_REMOVE_SUFFIX_CHARS=''    # don't eat space when typing '|' after a tab completion

setopt ALWAYS_TO_END          # full completions move cursor to the end
setopt AUTO_CD                # `dirname` is equivalent to `cd dirname`
setopt AUTO_PUSHD             # `cd` pushes directories to the directory stack
setopt EXTENDED_GLOB          # (#qx) glob qualifier and more
setopt GLOB_DOTS              # glob matches files starting with dot; `*` becomes `*(D)`
setopt HIST_EXPIRE_DUPS_FIRST # if history needs to be trimmed, evict dups first
setopt HIST_IGNORE_DUPS       # don't add dups to history
setopt HIST_IGNORE_SPACE      # don't add commands starting with space to history
setopt HIST_REDUCE_BLANKS     # remove junk whitespace from commands before adding to history
setopt HIST_VERIFY            # if a cmd triggers history expansion, show it instead of running
setopt INTERACTIVE_COMMENTS   # allow comments in command line
setopt MULTIOS                # allow multiple redirections for the same fd
setopt NO_BANG_HIST           # disable old history syntax
setopt NO_BG_NICE             # don't nice background jobs; not useful and doesn't work on WSL
setopt PUSHD_IGNORE_DUPS      # don’t push copies of the same directory onto the directory stack
setopt PUSHD_MINUS            # `cd -3` now means "3 directory deeper in the stack"
setopt SHARE_HISTORY          # write and import history on every command
setopt EXTENDED_HISTORY       # write timestamps to history

# The following lines were added by compinstall
zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# This tells zsh that small letters will match small and capital letters.
# (i.e. capital letters match only capital letters.)
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Zplug plugin initialization
if $(fn.is-fun zplug); then
  # powerlevel10k!
  zplug 'romkatv/powerlevel10k', as:theme, depth:1

  # To customize prompt, run `p10k configure` or edit ~/.config/dotfiles/.p10k.zsh.
  fn.source "${ZDOTDIR}/.p10k.zsh"

  # oh-my-zsh plugins
  zplug 'plugins/sudo', from:'oh-my-zsh', ignore:'oh-my-zsh.sh', if:"(($+commands[sudo]))"
  zplug 'plugins/systemd', from:'oh-my-zsh', ignore:'oh-my-zsh.sh', if:"(($+commands[systemctl]))"

  # Seems broken on Manjaro Linux KDE, will spawn tons of ssh-add process until ulimit is reached
  # zplug 'plugins/ssh-agent', from:'oh-my-zsh', ignore:'oh-my-zsh.sh', if:"[[ $OSTYPE != darwin* ]]"

  # Install plugins if there are plugins that have not been installed
  if [[ "${ZPLUG_AUTO_PKG}" == 'true' ]] && ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
      echo
      zplug install
    fi
  fi

  # Then, source plugins and add commands to $PATH
  zplug load

  # Workaround for issue https://github.com/zplug/zplug/issues/427 which sometimes still happen
  # because zplug cannot find the loadfile, causing __zplug::log::write::info consuming up to
  # 70% of the shell initialization time.
  if [[ "${ZPLUG_LOAD_FIX}" == 'true' ]]; then
    touch "$ZPLUG_LOADFILE"
  fi
fi

# Cleanup any declared private functions (prefixed with _)
# for fn in $(fn.list-fun | grep _fn); do
#   unset -f "${fn}"
# done

# Stop zsh profiling (if enabled)
if [[ "${ZSH_ZPROF}" == 'true' ]]; then
  zprof
fi

# Stop zsh tracing (if enabled)
if [[ "${ZSH_TRACE}" == 'true' ]]; then
  unsetopt XTRACE
  exec 2>&3 3>&-
fi
