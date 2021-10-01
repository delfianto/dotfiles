# File .zshrc; zsh initialization script

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/dotfiles/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# # Initialize zinit
(( ${+commands[brew]} )) && source $(brew --prefix)/opt/zinit/zinit.zsh   # macOS
[[ -f /usr/share/zinit/zinit.zsh ]] && source /usr/share/zinit/zinit.zsh  # Linux

# Load powerlevel10k theme
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k

# Set function path
fpath=( "${ZDOTDIR}/zfunc" "${fpath[@]}" )

# Set path as array-unique-special (no duplicates)
typeset -aU path

# Initialize zsh built-in functions
autoload -Uz colors compinit regexp-replace zcalc
compinit -d
colors

# Initialize zsh custom functions
autoload -Uz ex jvm pkg svc sys iommu zsh-in zsh-rc

# On every prompt, set terminal title to "user@host: cwd".
function set-term-title() { print -Pn '\e]0;%n@%m: %~\a' }
autoload -U add-zsh-hook
add-zsh-hook precmd set-term-title

# Disable highlighting of text pasted into the command line.
zle_highlight=('paste:none')

ZLE_RPROMPT_INDENT=0          # don't leave an empty space after right prompt
READNULLCMD="${PAGER}"        # use the default pager instead of `more`
WORDCHARS=''                  # only alphanums make up words in word-based zle widgets
ZLE_REMOVE_SUFFIX_CHARS=''    # don't eat space when typing '|' after a tab completion

## Options section
setopt ALWAYS_TO_END          # full completions move cursor to the end
setopt APPEND_HISTORY         # immediately append history instead of overwriting
setopt AUTO_CD                # `dirname` is equivalent to `cd dirname`
setopt AUTO_PUSHD             # `cd` pushes directories to the directory stack
setopt CORRECT                # auto correct mistakes
setopt EXTENDED_GLOB          # (#qx) glob qualifier and more
setopt GLOB_DOTS              # glob matches files starting with dot; `*` becomes `*(D)`
setopt HIST_EXPIRE_DUPS_FIRST # if history needs to be trimmed, evict dups first
setopt HIST_IGNORE_ALL_DUPS   # don't add dups to history
setopt HIST_IGNORE_SPACE      # don't add commands starting with space to history
setopt HIST_REDUCE_BLANKS     # remove junk whitespace from commands before adding to history
setopt HIST_VERIFY            # if a cmd triggers history expansion, show it instead of running
setopt INTERACTIVE_COMMENTS   # allow comments in command line
setopt MULTIOS                # allow multiple redirections for the same fd
setopt NO_BANG_HIST           # disable old history syntax
setopt NO_BEEP                # no beep
setopt NO_BG_NICE             # don't nice background jobs; not useful and doesn't work on WSL
setopt NO_CASE_GLOB           # case insensitive globbing
setopt NO_CHECK_JOBS          # don't warn about running processes when exiting
setopt NUMERIC_GLOB_SORT      # sort filenames numerically when it makes sense
setopt PUSHD_IGNORE_DUPS      # don’t push copies of the same directory onto the directory stack
setopt PUSHD_MINUS            # `cd -3` now means "3 directory deeper in the stack"
setopt RCEXPANDPARAM          # array expension with parameters
setopt SHARE_HISTORY          # write and import history on every command
setopt EXTENDED_HISTORY       # write timestamps to history

# The following lines were added by compinstall
zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' rehash true                              # automatically find new executables in path

# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

HISTFILE=~/.zhistory
HISTSIZE=1000
SAVEHIST=500
WORDCHARS=${WORDCHARS//\/[&.;]}                                 # Don't consider certain characters part of the word

## Keybindings section
bindkey -e
bindkey '^[[7~' beginning-of-line                               # Home key
bindkey '^[[H' beginning-of-line                                # Home key

if [[ "${terminfo[khome]}" != "" ]]; then
  bindkey "${terminfo[khome]}" beginning-of-line                # [Home] - Go to beginning of line
fi

bindkey '^[[8~' end-of-line                                     # End key
bindkey '^[[F' end-of-line                                      # End key

if [[ "${terminfo[kend]}" != "" ]]; then
  bindkey "${terminfo[kend]}" end-of-line                       # [End] - Go to end of line
fi

bindkey '^[[2~' overwrite-mode                                  # Insert key
bindkey '^[[3~' delete-char                                     # Delete key
bindkey '^[[C'  forward-char                                    # Right key
bindkey '^[[D'  backward-char                                   # Left key
bindkey '^[[5~' history-beginning-search-backward               # Page up key
bindkey '^[[6~' history-beginning-search-forward                # Page down key

# Navigate words with ctrl+arrow keys
bindkey '^[Oc' forward-word                                     #
bindkey '^[Od' backward-word                                    #
bindkey '^[[1;5D' backward-word                                 #
bindkey '^[[1;5C' forward-word                                  #
bindkey '^H' backward-kill-word                                 # delete previous word with ctrl+backspace
bindkey '^[[Z' undo                                             # Shift+tab undo last action

## Plugins section: Enable fish style features
zsh-in \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Load the rest of zshrc files
zsh-rc 00.utils 01.alias 02.linux 03.macos

# To customize prompt, run `p10k configure` or edit ~/.config/dotfiles/.p10k.zsh.
zsh-in ${ZDOTDIR}/.p10k.zsh
