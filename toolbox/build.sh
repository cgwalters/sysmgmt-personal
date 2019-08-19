#!/bin/sh
set -xeuo pipefail

dn=$(cd $(dirname $0) && pwd)

# https://pagure.io/fedora-kickstarts/blob/a8e3bf46817ca30f0253b025fcd829a99b1eb708/f/fedora-docker-base.ks#_22
for f in /etc/dnf/dnf.conf /etc/yum.conf; do
    if test -f ${f}; then
        pkgconf=${f}
    fi
done
if test -n "${pkgconf:-}"; then
    sed -i '/tsflags=nodocs/d' ${pkgconf}
fi

OS_ID=$(. /etc/os-release && echo ${ID})
OS_VER=$(. /etc/os-release && echo ${VERSION_ID})

override_repo="/usr/lib/container/repos/${OS_ID}-${OS_VER}.repo"
if test -f "${override_repo}"; then
    cp --reflink=auto "${override_repo}" /etc/yum.repos.d
fi
if test "${OS_ID}" = fedora; then
    cat > /etc/yum.repos.d/fedora-coreos-pool.repo <<'EOF'
[fedora-coreos-pool]
name=Fedora coreos pool repository - $basearch
baseurl=https://kojipkgs.fedoraproject.org/repos-dist/coreos-pool/latest/$basearch/
enabled=1
repo_gpgcheck=0
type=rpm-md
gpgcheck=1
skip_if_unavailable=False
EOF
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-29-primary
    # VS code
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
fi

yum -y update

if test -x /usr/bin/dnf; then
    pkg_builddep="dnf builddep"
else
    pkg_builddep="yum-builddep"
fi

case "${OS_ID}-${OS_VER}" in
    rhel-7.*|centos-7) yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm;;
esac
if [ "${OS_ID}" = rhel ]; then
    yum -y install rhpkg
fi

yum -y install bash-completion tmux sudo \
     redhat-rpm-config make \
     libguestfs-tools strace libguestfs-xfs \
     virt-install curl git kernel rsync \
     gdb selinux-policy-targeted \
     createrepo_c libvirt-devel
if test "${OS_ID}" = fedora; then
    # See repos above
    yum -y install code
    # General development
    yum -y install {python3-,}dnf-plugins-core \
           jq gcc clang origin-clients standard-test-roles fedpkg mock awscli git-evtag cargo golang \
           parallel vagrant-libvirt ansible \
           ostree{,-grub2} rpm-ostree \
           awscli dnf-utils bind-utils bcc bpftrace bcc-tools perf \
           fish ripgrep fd-find xsel git-annex
    # Some base fonts...TODO fix toolbox to pull fonts from the host like flatpak
    yum -y install dejavu-sans-mono-fonts dejavu-sans-fonts google-noto-emoji-color-fonts

    # Dependencies for rr https://github.com/mozilla/rr/wiki/Building-And-Installing
    yum -y install ccache cmake make gcc gcc-c++ gdb libgcc libgcc.i686 \
               glibc-devel glibc-devel.i686 libstdc++-devel libstdc++-devel.i686 \
               python3-pexpect man-pages ninja-build capnproto capnproto-libs capnproto-devel

    ${pkg_builddep} -y ostree origin rpm-ostree libdnf
    # Stuff for cosa
    curl https://raw.githubusercontent.com/coreos/coreos-assembler/master/src/deps.txt | \
        grep -v '^#' | xargs yum -y install
    # Extra arch specific bits
    yum -y install shim-x64 grub2-efi-x64{,-modules}
    # Done in cosa build for supermin
    chmod -R a+rX /boot/efi
fi
if ! test -x /usr/bin/dnf; then
    yum -y install yum-utils
fi
${pkg_builddep} -y glib2 systemd kernel

yum clean all && rm /var/cache/{dnf,yum} -rf

if [ -f /etc/mock/site-defaults.cfg ]; then
    echo "config_opts['use_nspawn'] = False" >> /etc/mock/site-defaults.cfg
fi