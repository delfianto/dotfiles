# Helper functions for sourcing file
zsh_source() {
  [[ -f "${1}" ]] && source "${1}" || echo "Cannot source: ${1}"
}

# Source additional .zsh files
zsh_import() {
  cd "${ZDOTDIR}/source"

  for file in $(ls *.zsh); do
    source "${file}"
  done

  cd
}

# Initialzie powerlevel10k
zsh_import; zsh_source '/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme'

# Initialize zsh auto complete
autoload -Uz compinit; compinit

# Auto complete command alias
setopt COMPLETE_ALIASES

# Set history mode to append
setopt APPEND_HISTORY
