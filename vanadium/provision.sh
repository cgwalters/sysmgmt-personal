#!/usr/bin/bash
set -xeuo pipefail

dn=$(dirname $0)

if ! test -f /run/ostree-booted; then
    echo "Not booted via ostree"
fi

sudo ${dn}/provision-root.sh

cd /var/srv/${USER}
mkdir -p public/src
ln -sfr public/src ~/src

cd ~/src
mkdir -p github/cgwalters
cd github/cgwalters
if ! test -d homegit; then
    git clone https://github.com/cgwalters/homegit
fi
cd homegit
rm -f ~/.bashrc
make install install-config install-dotfiles

sudo rm -f /root/.bashrc
sudo cp --reflink=auto ~/.bash* /root/

flatpak_install() {
    remote=$1
    app=$2

    if ! flatpak list | grep -q "${app}"; then
        flatpak install -y "${remote}" "${app}"
    fi
}

flatpak_install flathub com.visualstudio.code.oss
flatpak_install flathub io.github.Hexchat
flatpak_install flathub org.inkscape.Inkscape
flatpak_install flathub org.gnome.Characters
flatpak_install flathub org.gnome.Fractal