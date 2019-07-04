# zsh environment file; based on https://github.com/romkatv/dotfiles-public/blob/master/.zshenv

# set zsh dotfile location
export ZDOTDIR=${ZDOTDIR-$HOME/.config/dotfiles}

export EDITOR=/usr/bin/nano
export PAGER=less

# This affects every invocation of `less`.
#
#   -i   case-insensitive search unless search string contains uppercase letters
#   -R   color
#   -F   exit if there is less than one page of content
#   -X   keep content on screen after exit
#   -M   show more info at the bottom prompt line
#   -x4  tabs are 4 instead of 8
export LESS=-iRFXMx4

if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

eval $(dircolors -b)
