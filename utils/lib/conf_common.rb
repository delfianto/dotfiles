# frozen_string_literal: true
# conf_common.rb - Shell initialization for all operating system.

require '/home/mipan/.config/dotfiles/utils/lib/shell_configurator.rb'

if __FILE__ == $0
  configure_shell do

    # Shell operations
    set_alias "cls", "clear && printf '\e[3J'"
    set_alias "cp", "cp -v"
    set_alias "mv", "mv -v"
    set_alias "sudo", "sudo "
    set_alias "which", "command -v"

    # # Colorful grep output
    set_alias "grep", "grep -i --color=auto"
    set_alias "egrep", "egrep -i --color=auto"
    set_alias "fgrep", "fgrep -i --color=auto"

    # Shell management
    set_alias "history", "fc -li"
    set_alias "shdir", "cd $ZDOTDIR"
    set_alias "reload", "exec $SHELL -l"

  end
end
