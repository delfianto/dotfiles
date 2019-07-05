# File .zshrc; zsh initialization script
# Based on https://github.com/romkatv/dotfiles-public/blob/master/.zshrc

# Helper functions for sourcing file
zsh_source() {
  [[ -f "${1}" ]] && source "${1}" || echo "Cannot source: ${1}"
}

zsh_import() {
  cd "${ZDOTDIR}/zsh"

  for file in $(ls *.zsh); do
    source "${file}"
  done

  cd
}

# Source os specific file and other zsh scripts
zsh_import; uname=$(perl -e "print lc('`uname`');")
zsh_source "${ZDOTDIR:-${HOME}}/zsh/${uname}.zshrc"; unset uname

autoload -Uz compinit; compinit # Initialize zsh auto complete

# Disable highlighting of text pasted into the command line.
zle_highlight=('paste:none')

# On every prompt, set terminal title to "user@host: cwd".
# function set-term-title() { print -Pn '\e]0;%n@%m: %~\a' }
# add-zsh-hook precmd set-term-title

ZLE_RPROMPT_INDENT=0           # don't leave an empty space after right prompt
READNULLCMD="${PAGER}"         # use the default pager instead of `more`
WORDCHARS=''                   # only alphanums make up words in word-based zle widgets
ZLE_REMOVE_SUFFIX_CHARS=''     # don't eat space when typing '|' after a tab completion

setopt ALWAYS_TO_END           # full completions move cursor to the end
setopt AUTO_CD                 # `dirname` is equivalent to `cd dirname`
setopt AUTO_PUSHD              # `cd` pushes directories to the directory stack
setopt EXTENDED_GLOB           # (#qx) glob qualifier and more
setopt GLOB_DOTS               # glob matches files starting with dot; `*` becomes `*(D)`
setopt HIST_EXPIRE_DUPS_FIRST  # if history needs to be trimmed, evict dups first
setopt HIST_IGNORE_DUPS        # don't add dups to history
setopt HIST_IGNORE_SPACE       # don't add commands starting with space to history
setopt HIST_REDUCE_BLANKS      # remove junk whitespace from commands before adding to history
setopt HIST_VERIFY             # if a cmd triggers history expansion, show it instead of running
setopt INTERACTIVE_COMMENTS    # allow comments in command line
setopt MULTIOS                 # allow multiple redirections for the same fd
setopt NO_BANG_HIST            # disable old history syntax
setopt NO_BG_NICE              # don't nice background jobs; not useful and doesn't work on WSL
setopt PUSHD_IGNORE_DUPS       # don’t push copies of the same directory onto the directory stack
setopt PUSHD_MINUS             # `cd -3` now means "3 directory deeper in the stack"
setopt SHARE_HISTORY           # write and import history on every command
setopt EXTENDED_HISTORY        # write timestamps to history

# The following lines were added by compinstall
zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
bindkey -e
