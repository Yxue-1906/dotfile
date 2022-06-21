#!/usr/bin/env bash

function check_folder_structure() {
  test -d vim &&
  test -d zsh &&
  test -d tmux && return 0;
  echo "please run script inside root of repository" && exit 255;
}

function set_up_variable() {
    if command -v apt >> /dev/null;then
      PAC_MAN="sudo apt install -y";
      PAC_UPDATE="sudo apt update -y";
    elif command -v yum >> /dev/null;then
      PAC_MAN="sudo yum install -y";
      PAC_UPDATE="sudo yum update -y";
    elif command -v pacman >> /dev/null;then
      echo "not support for arch" && exit 255;
    else
      echo "can't find any package manager" && exit 255;
    fi
    if ! nc -z -w 1 google.com 443 > /dev/null;then
      echo -e "could not connect to google.com, please specify your proxy:";
      read -r PROXY;
      echo -e "proxy is: ${PROXY:=http://localhost:10809}";
      if ! grep -P "^http://.*?:[[:digit:]]+$" <<< "$PROXY" > /dev/null 2>&1;then
        echo -e 'proxy should match pattern "^http://.*?:[[:digit:]]+$"' && exit 255;
      fi
      if ! nc -z -w 1 \
        $(sed -E "s/^http://(.*?):[[:digit:]]+$" <<< "$PROXY") \
        $(sed -E "s/^http://.*?:([[:digit:]]+)$" <<< "$PROXY");then
        echo -e 'could not connect to proxy' && exit 255;
      fi
    fi
}

function backup_and_link() {
  if [ -h "$1" ] && [ "$1" -ot "$2" ];then
    echo -e "original $1 pointing to $(readlink -f "$1")";
    rm -f "$1" || echo -e "failed remove $1" && return 255;
    ln -s "$(readlink -f "$2")" "$1" || echo -e "failed create symbol link" && return 255;
  elif [ "$1" -ot "$2" ]; then
    mv "$1" "$1.bak.$(date -u +"%Y%m%d%H%M%S")" || echo -e "failed create backup" && return 255;
    ln -s "$(readlink -f "$2")" "$1" || echo -e "failed create symbol link" && return 255;
  fi
}

function backup_and_replace() {
    echo # todo
}

function install_package() {
  for pkg in "$@";do
    if ! command -v $pkg;then TO_INSTALL="$TO_INSTALL $pkg";fi
  done
  if [ -z ${TO_INSTALL:+} ];then return 0;fi
  if LANG= sudo -n -v 2>&1 | grep -q "may not run sudo";then
    echo "please run script with sudo privilege" && return 255;
  fi
  $PAC_UPDATE &&
  $PAC_MAN "$@"
}

function git_clone() {
  install_package git &&
  git clone "$1";
}

function install_and_config_zsh() {
  install_package zsh || echo "faile install zsh" && return 255;
  backup_and_link ~/.zshrc zsh/zshrc &&
  backup_and_link ~/.oh-my-zsh zsh/oh-my-zsh &&
  backup_and_link ~/.p10k.zsh zsh/p10k.zsh ||     # now use theme p10k, so...
    echo -e "failed config zsh" && return 255;
  while [ $(basename -- $SHELL) != "zsh" ];do
    printf "change default shell to zsh? [y/N]";
    read -r opt;
    case $opt in
      y*|Y*) break; ;;
      n*|N*|"") ;;
    esac
    chsh -s "$(command -v zsh)" "$USER" || echo "change shell failed!!" && return 255;
    break;
  done
  echo -e "install and config zsh done";
}

function install_and_config_vim() {
  install_package vim || echo -e "failed install vim" && return 255;
  backup_and_link ~/.vimrc &&
  backup_and_link ~/.vim || echo -e "failed config vim" && return 255;
  echo -e "install and config vim done";
}

function install_and_config_tmux() {
  backup_and_link ~/.tmux.conf || echo -e "failed install tmux" && return 255;
  install_package tmux || echo -e "failed config tmux" && return 255;
  echo -e "install and config tmux done";
}

function show_menu() {
  echo -e "
  input num to choose which to install and config.
  0) all
  1) zsh
  2) vim
  3) tmux
  4) exit
  ";
  read -p "please input your choose:" num;
  case $num in
    0)
      install_and_config_zsh;
      install_and_config_vim;
      install_and_config_tmux;
      exit 0;
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