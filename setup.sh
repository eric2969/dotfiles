#!/bin/bash

# remove below line if you want to setup
#exit
# DEBUG: echo command before execute
# set -x

YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $1 == "-n" ]]; then
    printf "${RED}Ignoring dependencies install\n${NC}"
else
    printf "${YELLOW}Installing dependencies\n${NC}"
    if [ -x "$(command -v brew)" ]; then # macOS
        brew install curl git gcc gdb grep;
        brew update;brew upgrade;
    elif [ -x "$(command -v apt)" ]; then # Ubuntu
        sudo apt install curl git zsh
    elif [ -x "$(command -v dnf)" ]; then # Fedora
        sudo dnf install curl git util-linux-user zsh
    elif [ -x "$(command -v pacman)" ];then #Arch
        sudo pacman -S curl git zsh
    else
        printf "${RED}Unknown os, exiting...${NC}"
        exit
    fi
fi

# install zsh
if [ ! -x "$(command -v zsh)" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && chsh -s $(which zsh)
fi

chsh -s $(which zsh)

# download Sauce Code Pro Nerd font and build link
mkdir -p ~/.local/share/fonts
curl -LO https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/SourceCodePro/Regular/complete/Sauce%20Code%20Pro%20Nerd%20Font%20Complete%20Mono.ttf
old_filename=`ls | grep ttf`
new_filename=`echo $old_filename | sed "s/%20/ /g"`
mv "$old_filename" "$new_filename"
mv "$new_filename" ~/.local/share/fonts

# build link
printf "${YELLOW}Building link to dotfiles${NC}\n"
filepath=$(realpath "$0")
dir=$(dirname "$filepath")
cp $dir/.zshrc ~/.zshrc
cp $dir/.vimrc ~/.vimrc
cp $dir/.p10k.zsh ~/.p10k.zsh
cat $dir/.bash_profile >> ~/.bash_profile

# setup antigen
printf "${YELLOW}Setting up antigen for zsh package management\n${NC}"
curl -sL git.io/antigen > ~/antigen.zsh

# setup Vundle
printf "${YELLOW}Setting up Vundle for vim package management\n${NC}"
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall

# Yay!
printf "${YELLOW}Finished\nPlease restart your device to apply\n${NC}"

