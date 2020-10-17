# =========================================================================
# File 05_plugins.zsh; Custom ZSH plugin initialization (zplug, p10k, etc)
# =========================================================================

if $(zsh::is_fun zplug); then
  # powerlevel10k!
  zplug 'romkatv/powerlevel10k', as:theme, depth:1

  # To customize prompt, run `p10k configure` or edit ~/.config/dotfiles/.p10k.zsh
  zsh::source "${ZDOTDIR}/.p10k.zsh"

  # oh-my-zsh plugins
  zplug 'plugins/sudo', from:'oh-my-zsh', ignore:'oh-my-zsh.sh', if:"(($+commands[sudo]))"
  zplug 'plugins/systemd', from:'oh-my-zsh', ignore:'oh-my-zsh.sh', if:"(($+commands[systemctl]))"

  # Seems broken on Manjaro Linux KDE, will spawn tons of ssh-add process until ulimit is reached
  # zplug 'plugins/ssh-agent', from:'oh-my-zsh', ignore:'oh-my-zsh.sh', if:"[[ $OSTYPE != darwin* ]]"

  # Install plugins if there are plugins that have not been installed
  if [[ "${ZPLUG_AUTO_PKG}" == true ]] && ! zplug check; then
    zplug check --verbose
    printf "\nInstall missing packages? [y/N]: "
    if read -q; then
      printf '\n'
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
else
  echo "ZPLUG is not installed yet" >&2
fi
