#!/usr/bin/env bash

function check_folder_structure() {
  test -d vim &&
    test -d zsh &&
    test -d tmux && return 0
  echo "please run script inside root of repository" && exit 255
}

function set_up_variable() {
  FMT_RED=$(printf '\033[31m')
  FMT_GREEN=$(printf '\033[32m')
  FMT_YELLOW=$(printf '\033[33m')
  FMT_BLUE=$(printf '\033[34m')
  FMT_BOLD=$(printf '\033[1m')
  FMT_RESET=$(printf '\033[0m')
  if command -v apt >>/dev/null; then
    PAC_MAN="sudo apt install -y"
    PAC_UPDATE="sudo apt update -y"
  elif command -v yum >>/dev/null; then
    PAC_MAN="sudo yum install -y"
    PAC_UPDATE="sudo yum update -y"
  elif command -v pacman >>/dev/null; then
    echo "${FMT_RED}not support for arch${FMT_RESET}" && exit 255
  else
    echo "${FMT_RED}can't find any package manager${FMT_RESET}" && exit 255
  fi
  if ! nc -z -w 1 google.com 443 >/dev/null; then
    echo -e "could not connect to google.com, please specify your proxy, or use ${FMT_BLUE}http://localhost:10809${FMT_RESET} by default:"
    read -r PROXY
    echo -e "proxy is: ${PROXY:=http://localhost:10809}"
    if ! grep -P "^http://.*?:[[:digit:]]+$" <<<"$PROXY" >/dev/null 2>&1; then
      echo -e 'proxy should match pattern "^http://.*?:[[:digit:]]+$"' && exit 255
    fi
    if ! nc -z -w 1 \
      $(sed -E "s/^http://(.*?):[[:digit:]]+$" <<<"$PROXY") \
      $(sed -E "s/^http://.*?:([[:digit:]]+)$" <<<"$PROXY"); then
      echo -e "${FMT_RED}could not connect to proxy!!${FMT_RESET}";
      echo -e "continue anyway? [y/N]"
      read -r opt;
      case $opt in
        y*|Y*)unset PROXY; ;;
        n*|N*|"") exit 255; ;;
      esac
    fi
  fi
}

function backup_and_link() {
  if [ -h "$1" ]; then
    echo -e "${FMT_YELLOW}original $1 points to $(readlink -f "$1")${FMT_RESET}";
    if [ "$(readlink -f "$1")" == "$(readlink -f "$2")" ] ||
        [ "$(readlink -f "$1")" -nt "$(readlink -f "$2")" ];then
      return;
    fi
    rm -f "$1" || {
      echo -e "${FMT_RED}failed remove $1${FMT_RESET}" && return 255
    }
    ln -s "$(readlink -f "$2")" "$1" || {
      echo -e "${FMT_RED}failed create symbol link${FMT_RESET}" && return 255
    }
  elif [ "$1" -ot "$(readlink -f "$2")" ]; then
    mv "$1" "$1.bak.$(date -u +"%Y%m%d%H%M%S")" || {
      echo -e "${FMT_RED}failed create backup${FMT_RESET}" && return 255
    }
    ln -s "$(readlink -f "$2")" "$1" || {
      echo -e "${FMT_RED}failed create symbol link${FMT_RESET}" && return 255
    };
  elif [ ! -e "$1" ]; then
    ln -s "$(readlink -f "$2")" "$1" || {
      echo -e "${FMT_RED}failed create symbol link${FMT_RESET}" && return 255
    };
  fi
}

function backup_and_replace() {
  echo # todo
}

function install_package() {
  for pkg in "$@"; do
    if ! command -v $pkg > /dev/null 2>&1; then TO_INSTALL="$TO_INSTALL $pkg"; fi
  done
  if [ -z "$TO_INSTALL" ]; then return 0; fi
  if LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"; then
    echo "${FMT_RED}please run script with sudo privilege${FMT_RESET}" && return 255
  fi
  $PAC_UPDATE &&
    $PAC_MAN "$@"
}

function git_clone() {
  install_package git &&
    git clone "$1"
}

function install_and_config_zsh() {
  install_package zsh || {
    echo -e "${FMT_RED}failed install zsh${FMT_RESET}" && return 255
  }
  backup_and_link ~/.zshrc zsh/zshrc &&
    backup_and_link ~/.oh-my-zsh zsh/oh-my-zsh &&
    backup_and_link ~/.p10k.zsh zsh/p10k.zsh || { # now use theme p10k, so...
      echo -e "${FMT_RED}failed config zsh${FMT_RESET}" && return 255
    }
  while [ $(basename -- $SHELL) != "zsh" ]; do
    printf "change default shell to zsh? [y/N]"
    read -r opt
    case $opt in
      y* | Y*) break ;;
      n* | N* | "") ;;
    esac
    sudo -k chsh -s "$(command -v zsh)" "$USER" || {
      echo "${FMT_RED}${FMT_BOLD}change shell failed!!${FMT_RESET}" && return 255
    }
    break
  done
  echo -e "${FMT_GREEN}install and config zsh done${FMT_RESET}"
}

function install_and_config_vim() {
  install_package vim || {
    echo -e "${FMT_RED}failed install vim${FMT_RESET}" && return 255
  }
  backup_and_link ~/.vimrc vim/vimrc &&
    backup_and_link ~/.vim vim/dotvim || {
      echo -e "${FMT_RED}failed config vim${FMT_RESET}" && return 255
    }
  [ -d ~/.vim/autoload ] && mkdir -p ~/.vim/autoload || {
    echo -e "${FMT_RED}failed make dir $HOME/.vim/autoload" && return 255
  }
  [ -e ~/.vim/autoload/plug.vim ] &&
    ln -s "$(pwd)/vim/vim-plug/plug.vim" ~/.vim/autoload/plug.vim || {
      echo -e "${FMT_RED}failed create symbol link for $HOME/.vim/autoload/plug.vim"
      return 255;
    }
  echo -e "${FMT_GREEN}install and config vim done${FMT_RESET}"
}

function install_and_config_tmux() {
  install_package tmux || {
    echo -e "${FMT_RED}failed install tmux${FMT_RESET}" && return 255
  }
  backup_and_link ~/.tmux.conf tmux/tmux.conf || {
    echo -e "${FMT_RED}failed config tmux${FMT_RESET}" && return 255
  }
  echo -e "${FMT_GREEN}install and config tmux done${FMT_RESET}"
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
  check_folder_structure;
  set_up_variable;
  show_menu;
}

main;
