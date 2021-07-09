#!/usr/bin/env bash

system=$(uname);

OLD_DOTFILES=~/"dotfile-$(date -u +"%Y%m%d%H%M%S")"
# mkdir $OLD_DOTFILES

function backup_if_exists() {
    if [[ -f $1 || -d $1 ]];then
        if [[ ! ( -d $OLD_DOTFILES ) ]];then
            mkdir $OLD_DOTFILES
        fi
        mv $1 $OLD_DOTFILES
    fi
}

if [[ ! ( -f ~/.vim/autoload/plug.vim ) ]];then
    echo "can't detect vim-plug, install now"
    if [[ ! ( -d ~/.vim/autoload ) ]];then 
        mkdir -p ~/.vim/autoload
    fi
    # repalce github.com in plug.vim with mirror site or vim-plug can't clone plugins
    # please replace socks5://localhost:10808 with your own proxy or just the commented line if you have no problem clone plugins or so
    curl -x socks5://localhost:10808 https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim | sed -E 's/github(\\?\.)com/hub.fastgit\1org/g' > ~/.vim/autoload/plug.vim
    if [[ ! ( -s ~/.vim/autoload/plug.vim ) ]];then
        echo "error when download vim-plug, please check your network or see line 24 in install.sh"
        rm -f ~/.vim/autoload/plug.vim
        exit 1
    fi
    # curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

echo "buck up old dotfiles may exist"
backup_if_exists ~/.vimrc

if grep -q MINGW <<< $system; then
    echo "WIN detected"
    # home=$HOME
    # home=${home//\//\\}
    # home=${home:1}
    # toreplace=${home%%\\*}
    # home=${home/$toreplace/${toreplace^^}:}

    # workdir=$(pwd)
    # workdir=${workdir//\//\\}
    # workdir=${workdir:1}
    # toreplace=${workdir%%\\*}
    # workdir=${workdir/$toreplace/${toreplace^^}:}

    # cmd <<< "mklink /D \"$home\\.vimrc\" \"$workdir\\vim\\.vimrc\" "

    cp -i 'vim/.vimrc' ~/
    read -p 'do you want to remap <Esc - CapsLock> ?(y/N)' ans ;ans=${ans^^}

    if [[ -z $ans || ${ans:0:1} = "Y" || ${ans:0:1} = $(echo -e "\n") ]];then
        cmd <<< '.\remap.reg'
        read -p 'remap will make effect after log out and log in, want to log out after install all the dotfiles?(n/Y)' ans1
        ans1=${ans1^^}
    fi
else
    # notice that source file path in symbol link base on 
    # where the symbol link located if use related path
    ln -s "$(pwd)/vim/.vimrc" ~/.vimrc 
fi

echo "Done"

# echo $ans1
if [[ -n ans1 && ${ans1:0:1} != $(echo -e "\n") && ${ans1:0:1} != "N" ]];then
    cmd <<< logoff
fi
