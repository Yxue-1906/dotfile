#!/usr/bin/env bash

system=$(uname);

if [[ ! ( -d ~/.vim/autoload ) ]];then
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

if grep -q MINGW <<< $system; then
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
else
    ln -s "~/.vimrc" "vim/.vimrc"
fi
