#!/usr/bin/env bash

function BACKUP_INIT(){
    OLD_DOTFILES=~/"dotfile-$(date -u +"%Y%m%d%H%M%S")";echo "buck up old dotfiles may exist"
    backup_if_exists ~/.vimrc
    backup_if_exists ~/.zshrc
    if ! echo $(uname -a) | grep 'Linux' > /dev/null;then
        echo '
        %1 start "" mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c ""%~s0"" ::","","runas",1)(window.close)&&exit
        ' > $HOME/mklink.bat
    fi
    # mkdir $OLD_DOTFILES
    echo testing connection with google.com
    USE_PROXY=$(ping -$(if echo $(uname -a)| grep -P "^Linux" > /dev/null;then echo c;else echo n;fi) 2 google.com > /dev/null;echo $?)
    NO_ZSH=$(which zsh > /dev/null;echo $?)
    NO_VIM=$(which vim > /dev/null;echo $?)
    if [[ $USE_PROXY -ne 0 ]];then
        read -p "Please specify your proxy or enter to use default proxy socks5://localhost:10808:" PROXY
        if [[ -z "$PROXY" ]];then
            PROXY="socks5://localhost:10808";
        fi
    fi
}

function SET_UP_APP(){
    if echo $(uname -a ) | grep -P "^Linux" > /dev/null;then
        # Linux
        sudo apt update
        if [[ $NO_ZSH -eq 1 ]];then
            sudo apt install zsh
            sudo chsh -s $(which zsh)
        fi &&
        if [[ $NO_VIM -eq 1 ]];then
            sudo apt install vim
        fi &&
        return 0 || 
        return 1
    elif echo $(uname -a) | grep -P "^MSYS" > /dev/null;then
        # MSYS
        if [[ $NO_ZSH -eq 1 ]];then
            pacman -S zsh
            echo -e '\003[31mPlease edit config files(msys2/mingw32/mingw64/clang64/ucrt64.ini) in your MSYS2 install directory.\033[0m' 
        fi &&
        if [[ $NO_VIM -eq 1 ]];then
            pacman -S vim
        fi &&
        return 0 || 
        return 1
    elif echo $(unmae -a) | grep -P "^MINGW" > /dev/null;then
        #Git bash
        echo Sorry, Git bash doest support zsh!
        return 1
    else
        echo Unknown Operating system!
        return 1
    fi
}

function backup_if_exists() {
    if [[ -f $1 || -d $1 ]];then
        if [[ ! ( -d $OLD_DOTFILES ) ]];then
            mkdir $OLD_DOTFILES
        fi
        mv $1 $OLD_DOTFILES
    fi
}

# config zsh
function CONFIG_ZSH(){
    if [[ ! -d ~/.oh-my-zsh ]];then
        if [[ $USE_PROXY -ne 0 ]];then
            echo no | bash -c "$(curl -x $PROXY -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sed -E 's/github\.com/hub\.fastgit\.org/g')"
        else
            echo no | bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        fi
        if echo $(uname -a) | grep -P '^Linux' > /dev/null;then
            echo Try changing default shell to zsh... &&
                sudo cp /etc/passwd ~/passwd.bak && sudo sed -i -E "s%(^$USER.*)/bin/bash%$(which zsh)%" /etc/passwd &&
            echo Success! || echo Failed, please check.
        fi
    fi &&
    if [[ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ]];then
        if [[ $USE_PROXY -ne 0 ]];then
            git clone --depth=1 https://gitee.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
        else
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
        fi
        echo "Maybe you need to install fonts to get best experience"
    fi &&
    if [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]];then
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    fi &&
    if [[ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]];then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    fi
    if [[ ! -f $HOME/.zshrc ]];then
        if echo $(uname -a) | grep -P '^Linux' > /dev/null;then
            # Linux
            ln -s "$(pwd)/zsh/zshrc" ~/.zshrc 
        else
            echo '
            mklink "<1>/.zshrc" "<2>/zsh/zshrc"  
            ' | sed "s%<1>%$(cygpath -m $HOME)%" | sed "s%<2>%$(cygpath -m $(pwd))%" >> $HOME/mklink.bat
        fi
    fi
    return 0
}

function CONFIG_VIM(){
    if [[ ! ( -f ~/.vim/autoload/plug.vim ) ]];then
        echo "can't detect vim-plug, install now"
        mkdir -p ~/.vim/autoload > /dev/null 2>&1;
        if [[ $USE_PROXY -ne 0 ]];then
            # repalce github.com in plug.vim with mirror site or vim-plug can't clone plugins
            curl -x $PROXY https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim | sed -E 's/github(\\?\.)com/hub.fastgit\1org/g' > ~/.vim/autoload/plug.vim
        else
            curl https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim > ~/.vim/autoload/plug.vim
        fi && echo Install vim-plug successfull! ||
        (echo "Error when download vim-plug, please check your proxy!" && rm -f ~/.vim/autoload/plug.vim)
        
        return 1
        # curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
    if echo $(uname) | grep -q Linux > /dev/null ; then
        # notice that source file path in symbol link base on 
        # where the symbol link located if use related path
        ln -s "$(pwd)/vim/vimrc" ~/.vimrc 
    else
        echo "WIN detected"
        echo '
        mklink "<1>/.vimrc" "<2>/vim/vimrc"  
        ' | sed "s%<1>%$(cygpath -m $HOME)%" | sed "s%<2>%$(cygpath -m $(pwd))%" >> $HOME/mklink.bat
        
        read -p 'Do you want to remap <Esc - CapsLock> ?(y/N)' ans ;ans=${ans^^}

        if echo $ans | grep -P '^Y$' > /dev/null;then
            start '.\remap.reg'
            read -p 'Remap will make effect after log out and log in, want to log out after install all the dotfiles?(n/Y)' ans1
            ans1=${ans1^^}
        fi
    fi
}

BACKUP_INIT
if SET_UP_APP;then
    CONFIG_ZSH
fi
CONFIG_VIM
if [[ -f $HOME/mklink.bat ]];then
    start $HOME/mklink.bat
fi
sleep 5

echo "Done"
rm $HOME/mklink.bat > /dev/null 2>&1

# echo $ans1
if [[ -n ans1 && ${ans1:0:1} != $(echo -e "\n") && ${ans1:0:1} != "N" ]];then
    cmd <<< logoff
fi
