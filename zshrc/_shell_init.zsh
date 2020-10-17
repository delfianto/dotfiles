# ==================================================
# File _shell_init.zsh; Initialize all custom stuff
#
# To enable tracing and profiling, set the
# ZSH_TRACE and ZSH_PROF environment variable
# ==================================================

# ======= TRACING AND PROFILING =======
if [[ "${ZSH_TRACE}" == true ]]; then
  zmodload zsh/datetime
  setopt PROMPT_SUBST
  PS4='+$EPOCHREALTIME %N:%i> '

  logfile=$(mktemp zsh_profile.XXXXXXXX)
  echo "Logging to $logfile"
  exec 3>&2 2>$logfile

  setopt XTRACE
fi

if [[ "${ZSH_ZPROF}" == true ]]; then
  zmodload zsh/zprof
fi
# ====================================

zsh::source_rc 01_functions
zsh::source_rc 02_shell_alias
zsh::source_rc 03_linux_all
zsh::source_rc 03_macos_all
zsh::source_rc 05_plugins

# add .local/bin to PATH
zsh::path_munge "${HOME}/.local/bin"

# ======= TRACING AND PROFILING =======
if [[ "${ZSH_ZPROF}" == true ]]; then
  zprof
fi

if [[ "${ZSH_TRACE}" == true ]]; then
  unsetopt XTRACE
  exec 2>&3 3>&-
fi
# ====================================
