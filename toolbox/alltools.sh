#!/bin/sh
set -xeuo pipefail

dn=$(cd $(dirname $0) && pwd)

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-*-primary
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-modularity
cat > /etc/yum.repos.d/fedora-coreos-pool.repo <<'EOF'
[fedora-coreos-pool]
name=Fedora coreos pool repository - $basearch
baseurl=https://kojipkgs.fedoraproject.org/repos-dist/coreos-pool/latest/$basearch/
enabled=0
repo_gpgcheck=0
type=rpm-md
gpgcheck=1
skip_if_unavailable=False
EOF
# VS code
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

yum_retry() {
    local err=0
    for x in $(seq 5); do 
        if yum "$@"; then
            break
        fi
        sleep 5
        err=1
    done
    if [ "${err}" = 1 ]; then
        exit 1
    fi
}

yum_install() {
    yum_retry -y install "$@"
}

pkg_builddep() {
    if test -x /usr/bin/dnf; then
        yum_retry builddep -y "$@"
    else
        yum-builddep -y "$@"
    fi
}

yum_install bash-completion tmux sudo \
     redhat-rpm-config make \
     libguestfs-tools strace libguestfs-xfs \
     virt-install curl git kernel rsync \
     gdb selinux-policy-targeted \
     createrepo_c libvirt-devel
# See repos above
yum_install code
# General development
yum_install {python3-,}dnf-plugins-core \
       jq gcc clang origin-clients standard-test-roles fedpkg mock awscli git-evtag cargo golang \
       parallel vagrant-libvirt ansible \
       ostree{,-grub2} rpm-ostree \
       awscli dnf-utils bind-utils bcc bpftrace bcc-tools perf \
       fish ripgrep fd-find xsel git-annex
# Some base fonts...TODO fix toolbox to pull fonts from the host like flatpak
yum_install dejavu-sans-mono-fonts dejavu-sans-fonts google-noto-emoji-color-fonts
# Dependencies for rr https://github.com/mozilla/rr/wiki/Building-And-Installing
yum_install ccache cmake make gcc gcc-c++ gdb libgcc libgcc.i686 \
           glibc-devel glibc-devel.i686 libstdc++-devel libstdc++-devel.i686 \
           python3-pexpect man-pages ninja-build capnproto capnproto-libs capnproto-devel
pkg_builddep -y ostree rpm-ostree podman buildah
# Stuff for cosa
yum_install $(curl https://raw.githubusercontent.com/coreos/coreos-assembler/master/src/deps.txt | grep -v '^#')
# Extra arch specific bits
yum_install shim-x64 grub2-efi-x64{,-modules}
yum_install bootupd
# Done in cosa build for supermin
chmod -R a+rX /boot/efi
pkg_builddep -y glib2 systemd kernel
