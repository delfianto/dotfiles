# File .zshrc; zsh initialization script
#
# Based on https://github.com/romkatv/dotfiles-public/blob/master/.zshrc

# [[ "${TERM}" == xterm* ]] || : ${PURE_POWER_MODE:=portable}

# Set path as array-unique-special (no duplicates)
typeset -aU path

# Initialize zsh auto complete
autoload -Uz compinit; compinit

# Load regex module
autoload -U regexp-replace

# Disable highlighting of text pasted into the command line.
zle_highlight=('paste:none')

# On every prompt, set terminal title to "user@host: cwd".
function set-term-title() { print -Pn '\e]0;%n@%m: %~\a' }
autoload -U add-zsh-hook
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

# Helper functions for sourcing file
zsh::source() {
  [[ -f "${1}" ]] && source "${1}"
}

zsh::source_rc() {
  zsh::source "${ZDOTDIR}/zshrc/${1}.zsh"
}

# Cleanup any declared private functions (prefixed with _)
# for fn in $(fn.list-fun | grep _fn); do
#   unset -f "${fn}"
# done

# if $(fn.is-macos); then
#   export PATH=$PATH:l
# fi

zsh::source_rc _shell_init
