#!/usr/bin/env bash

function BACKUP_INIT(){
    OLD_DOTFILES=~/"dotfile-$(date -u +"%Y%m%d%H%M%S")";echo "buck up old dotfiles may exist"
    if ! uname -a | grep 'Linux' > /dev/null;then
        if ! command -v diff > /dev/null;then
            pacman -S diffutils
        fi
        echo '
        %1 start "" mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c ""%~s0"" ::","","runas",1)(window.close)&&exit
        ' > "$HOME"/mklink.bat
    fi
    # mkdir $OLD_DOTFILES
    echo testing connection with google.com
    USE_PROXY=$(ping -$(if uname -a | grep -P "^Linux" > /dev/null;then echo c;else echo n;fi) 2 google.com > /dev/null;echo $?)
    NO_ZSH=$(command -v zsh > /dev/null;echo $?)
    NO_VIM=$(command -v vim > /dev/null;echo $?)
    NO_TMUX=$(command -v tmux > /dev/null;echo $?)
    if [[ $USE_PROXY -ne 0 ]];then
        read -r -p "\033[31m Please specify your proxy or enter to use default proxy\033[0m \033[41;37m socks5://localhost:10808: \033[0m" PROXY
        if [[ -z "$PROXY" ]];then
            PROXY="socks5://localhost:10808";
        fi
	git config --global http.https://github.com.proxy $PROXY
	git config --global https.https://github.com.proxy $PROXY
    fi
}

function SET_UP_APP(){
    if uname -a | grep -P "^Linux" > /dev/null;then
        # Linux
        sudo apt update
        if [[ $NO_ZSH -ne 0 ]];then
            sudo apt install zsh
        fi &&
        if [[ $NO_VIM -ne 0 ]];then
            sudo apt install vim
        fi &&
        if [[ $NO_TMUX -ne 0 ]];then
            sudo apt install tmux
        fi &&
        return 0 || 
        return 1
    elif uname -a | grep -P "^MSYS" > /dev/null;then
        # MSYS
        if [[ $NO_ZSH -ne 0 ]];then
            pacman -S zsh
            echo -e '\003[31mPlease edit config files(msys2/mingw32/mingw64/clang64/ucrt64.ini) in your MSYS2 install directory.\033[0m' 
        fi &&
        if [[ $NO_VIM -ne 0 ]];then
            pacman -S vim
        fi &&
        if [[ $NO_TMUX -ne 0 ]];then
            pacman -S tmux
        fi &&
        return 0 || 
        return 1
    elif uname -a | grep -P "^MINGW" > /dev/null;then
        #Git bash
        echo "\033[31m Sorry, Git bash doest support zsh! \033[0m"
        return 1
    else
        echo "\033[31m Unknown Operating system! \033[0m"
        return 1
    fi
}

function backup_if_exists() {
    if [[ ! ( -d $OLD_DOTFILES ) ]];then
        mkdir $OLD_DOTFILES
    fi
    mv $1 $OLD_DOTFILES
}

# config zsh
function CONFIG_ZSH(){
    if [[ ! -d ~/.oh-my-zsh ]];then
        if [[ $USE_PROXY -ne 0 ]];then
            echo no | bash -c "$(curl -x $PROXY -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sed -E 's/github\.com/hub\.fastgit\.org/g')"
        else
            echo no | bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        fi &&
        if uname -a | grep -P '^Linux' > /dev/null;then
            echo Try changing default shell to zsh... &&
                grep -P "^$USER.*/bin/.*sh^" | xargs -I line echo "\033[31m $(echo 'line' | sed -E "s%^(^USER.*)/bin/.*sh%\1$(command -v zsh)%") \033[0m"
            sudo cp /etc/passwd ~/passwd.bak && sudo sed -i -E "s%(^$USER.*)/bin/.*sh%$(command -v zsh)%" /etc/passwd &&
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
    if [[ ! ( -f $HOME/.zshrc ) ]] || ! diff ~/.zshrc zsh/zshrc > /dev/null;then
        backup_if_exists ~/.zshrc
        if uname -a | grep -P '^Linux' > /dev/null;then
            # Linux
            ln -s "$(pwd)/zsh/zshrc" ~/.zshrc 
        else
            echo '
            mklink "<1>/.zshrc" "<2>/zsh/zshrc"  
            ' | sed "s%<1>%$(cygpath -m "$HOME")%" | sed "s%<2>%$(cygpath -m $(pwd))%" >> "$HOME"/mklink.bat
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
        (echo "Error when download vim-plug, please check your proxy!" && rm -f ~/.vim/autoload/plug.vim && return 1)
        
        # curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
    if [[ ! ( -f ~/.vimrc ) ]] || ! diff ~/.vimrc vim/vimrc > /dev/null;then
        backup_if_exists ~/.vimrc
        if uname -a | grep -q Linux > /dev/null ; then
            # notice that source file path in symbol link base on 
            # where the symbol link located if use related path
            ln -s "$(pwd)/vim/vimrc" ~/.vimrc 
        else
            echo '
            mklink "<1>/.vimrc" "<2>/vim/vimrc"  
            ' | sed "s%<1>%$(cygpath -m $HOME)%" | sed "s%<2>%$(cygpath -m $(pwd))%" >> $HOME/mklink.bat
            
            read -r -p 'Do you want to remap <Esc - CapsLock> ?(y/N)' ans ;ans=${ans^^}

            if echo $ans | grep -P '^Y$' > /dev/null;then
                start '.\remap.reg'
                read -r -p 'Remap will make effect after log out and log in, want to log out after install all the dotfiles?(n/Y)' ans1
                ans1=${ans1^^}
            fi
        fi
    fi
}

function CONFIG_TMUX(){
    if [[ ! -f ~/.tmux.conf ]] || ! diff tmux/tmux.conf ~/.tmux.conf;then
        backup_if_exists ~/.tmux.conf
        if uname -a | grep -P '^Linux' > /dev/null;then
            ln -s "$(pwd)/tmux/tmux.conf" ~/.tmux.conf
        else
            echo '
            mklink "<1>/.tmux.conf" "<2>/tmux/tmux.conf"  
            ' | sed "s%<1>%$(cygpath -m $HOME)%" | sed "s%<2>%$(cygpath -m $(pwd))%" >> $HOME/mklink.bat
        fi
    fi
}

BACKUP_INIT
if SET_UP_APP;then
    CONFIG_ZSH
fi
CONFIG_VIM
git config --global --unset http.https://github.com.proxy
git config --global --unset https.https://github.com.proxy
if [[ -f $HOME/mklink.bat ]];then
    start $HOME/mklink.bat
fi
sleep 5

echo "Done"
rm $HOME/mklink.bat > /dev/null 2>&1

# echo $ans1
if [[ -n $ans1 && ${ans1:0:1} != $(echo -e "\n") && ${ans1:0:1} != "N" ]];then
    cmd <<< logoff
fi
