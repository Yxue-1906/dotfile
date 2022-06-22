#!/usr/bin/env bash

function print_progress() {
    printf "${FMT_BLUE}%s${FMT_RESET}" "$*"
}

function echo_progress() {
    print_progress "$*"
    echo
}

function print_done() {
    printf "${FMT_GREEN}%s${FMT_RESET}" "$1"
}

function echo_done() {
    print_done "$*"
    echo
}

function print_error() {
   printf "${FMT_RED}%s${FMT_RESET}" "$1"
}

function echo_error() {
    print_error "$*"
    echo
}

function print_other() {
    printf "${FMT_YELLOW}%s${FMT_RESET}" "$1"
}

function echo_other() {
    print_other "$*"
    echo
}

function set_up_variable() {
  FMT_RED=$(printf '\033[31m')
  FMT_GREEN=$(printf '\033[32m')
  FMT_YELLOW=$(printf '\033[33m')
  FMT_BLUE=$(printf '\033[34m')
  FMT_BOLD=$(printf '\033[1m')
  FMT_RESET=$(printf '\033[0m')

  echo_progress "checking pkg manager..."

  if command -v apt >>/dev/null; then
    PKG_INSTALL="sudo apt install -y"
    PKG_UPDATE="sudo apt update -y"
  elif command -v yum >>/dev/null; then
    PKG_INSTALL="sudo yum install -y"
    PKG_UPDATE="true"
  elif command -v pacman >>/dev/null; then
    echo_error "not support for arch" && exit 255
  else
    echo_error "can't find any package manager" && exit 255
  fi
  UPDATED=false

  echo_progress "checking networking..."

  if ! nc -z -w 1 google.com 443 >/dev/null; then
    printf "could not connect to google.com, please specify your proxy, or use "
    print_other "http://localhost:10809"
    printf " by default:"
    read -r PROXY
    echo -e "proxy is: ${PROXY:=http://localhost:10809}"
    if ! grep -P "^http://.*?:[[:digit:]]+$" <<<"$PROXY" >/dev/null 2>&1; then
      echo_error 'proxy should match pattern "^http://.*?:[[:digit:]]+$"' && exit 255
    fi

    echo_progress "checking proxy..."

    if ! nc -z -w 1 \
      $(sed -E "s%^http://(.*?):[[:digit:]]+$%\1%" <<<"$PROXY") \
      $(sed -E "s%^http://.*?:([[:digit:]]+)$%\1%" <<<"$PROXY"); then
      echo_error "could not connect to proxy!!";
      read -r -p "continue anyway? [y/N]" opt
      case $opt in
        y*|Y*)unset PROXY; ;;
        n*|N*|"") exit 255; ;;
      esac
    fi
  fi
}

function check_folder_structure() {
  echo_progress "checking folder structure...";
  test -d vim &&
    test -d zsh &&
    test -d tmux && return 0
  echo_error "please run script inside root of repository" && exit 255
}

function backup_and_link() {
  echo_progress "backing up $1 and trying to link to $2"

  if [ -h "$1" ]; then
    if [ "$(readlink -f "$1")" == "$(readlink -f "$2")" ] ||
        [ "$(readlink -f "$1")" -nt "$(readlink -f "$2")" ];then
      return;
    fi
    rm -f "$1" || {
      echo_error "failed remove $1" && return 255
    }
    ln -s "$(readlink -f "$2")" "$1" || {
      echo_error "failed create symbol link" && return 255
    }
  elif [ -e "$1" ] && [ "$1" -ot "$(readlink -f "$2")" ]; then
    BACKUP_NAME="$1.bak.$(date -u +"%Y%m%d%H%M%S")"
    mv "$1" "$BACKUP_NAME" || {
      echo_error "failed create backup" && return 255
    }
    print_progress "backup $1 as $BACKUP_NAME";
    ln -s "$(readlink -f "$2")" "$1" || {
      echo_error "failed create symbol link" && return 255
    };
  elif [ ! -e "$1" ]; then
    ln -s "$(readlink -f "$2")" "$1" || {
      echo_error "failed create symbol link" && return 255
    };
  else
    return;
  fi
}

function backup_and_replace() {
  echo # todo
}

function install_package() {
#  for pkg in "$@"; do
#    if ! command -v $pkg > /dev/null 2>&1; then TO_INSTALL="$TO_INSTALL $pkg"; fi
#  done
#  if [ -z "$TO_INSTALL" ]; then return 0; fi
  if LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"; then
    echo_error "please run script with sudo privilege" && return 255
  fi
  if ! $UPDATED;then
    $PKG_UPDATE && UPDATED=true;
  fi
  $PKG_INSTALL "$@"
}

function git_clone() {
  install_package git &&
    git clone "$1"
}

function install_and_config_zsh() {
  echo_progress "install and config zsh..."

  install_package zsh || {
    echo_error "failed install zsh" && return 255
  }
  backup_and_link ~/.zshrc zsh/zshrc &&
    backup_and_link ~/.oh-my-zsh zsh/oh-my-zsh &&
    backup_and_link ~/.p10k.zsh zsh/p10k.zsh || { # now use theme p10k, so...
      echo_error "failed config zsh" && return 255
    }
  while [ $(basename -- $SHELL) != "zsh" ]; do
    read -r -p "change default shell to zsh? [y/N]" opt
    case $opt in
      y* | Y*)  ;;
      n* | N* | "") break; ;;
    esac
    sudo -k chsh -s "$(command -v zsh)" "$USER" || {
      echo_error "change shell failed!!" && return 255
    }
    break
  done

  echo_done "install and config zsh done"
}

function install_and_config_vim() {
  echo_progress "install and config vim..."

  install_package vim || {
    echo_error "failed install vim" && return 255
  }
  backup_and_link ~/.vimrc vim/vimrc || {
    echo_error "failed config vim" && return 255
  }
  if [ ! -d ~/.vim/autoload ];then
    mkdir -p ~/.vim/autoload || {
      echo_error "failed make dir $HOME/.vim/autoload" && return 255
    }
  fi
  if [ ! -e ~/.vim/autoload/plug.vim ]; then
    ln -s "$(pwd)/vim/vim-plug/plug.vim" ~/.vim/autoload/plug.vim || {
      echo_error "failed create symbol link for $HOME/.vim/autoload/plug.vim"
      return 255;
    }
  fi
  echo_done "install and config vim done"
}

function install_and_config_tmux() {
  echo_progress "install and config tmux..."

  install_package tmux || {
    echo_error "failed install tmux" && return 255
  }
  backup_and_link ~/.tmux.conf tmux/tmux.conf || {
    echo_error "failed config tmux" && return 255
  }

  echo_done "install and config tmux done"
}

function show_menu() {
  echo -e \
    "input num to choose which to install and config.
0) all
1) zsh
2) vim
3) tmux
4) exit"
  read -p "please input your choose:" num
  case $num in
    0)
      install_and_config_zsh;
      install_and_config_vim;
      install_and_config_tmux;
      exit 0
      ;;
    1)
      install_and_config_zsh;
      show_menu;
      ;;
    2)
      install_and_config_vim;
      show_menu;
      ;;
    3)
      install_and_config_tmux;
      show_menu;
      ;;
    4)
      echo -e "bye" && exit 0;
      ;;
  esac
}

function main() {
  echo "DOTFILE_LOCATION=$(pwd)" > ~/.dotfile_config
  set_up_variable;
  check_folder_structure;
  show_menu;
}

main;
