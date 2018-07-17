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

if test -x /usr/bin/dnf; then
    pkg_builddep="dnf builddep"
else
    pkg_builddep="yum-builddep"
fi

case "${OS_ID}-${OS_VER}" in
    rhel-7.*|centos-7) yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm;;
esac
case "${OS_ID}-${OS_VER}" in
    rhel-*|centos-*)
        # for dumb-init
        (cd /etc/yum.repos.d && curl -L -O https://copr.fedorainfracloud.org/coprs/walters/walters-ws-misc/repo/epel-7/walters-walters-ws-misc-epel-7.repo)
        ;;
esac
case "${OS_ID}-${OS_VER}" in
    rhel-7.*) yum -y install rhpkg;;
esac

pkgs="dumb-init bash-completion yum-utils tmux sudo \
     redhat-rpm-config make \
     libguestfs-tools strace libguestfs-xfs \
     virt-install curl git kernel rsync \
     gdb selinux-policy-targeted
     createrepo_c"
if test "${OS_ID}" = fedora; then
    pkgs="$pkgs "$(echo {python3-,}dnf-plugins-core)
    pkgs="$pkgs jq gcc origin-clients standard-test-roles fedpkg mock awscli git-evtag cargo golang"
    pkgs="$pkgs parallel vagrant-libvirt ansible"
    pkgs="$pkgs "$(echo ostree{,-grub2} rpm-ostree)
    pkgs="$pkgs awscli"
fi
yum -y install $pkgs
${pkg_builddep} -y glib2 systemd
if test "${OS_ID}" = fedora; then
    ${pkg_builddep} -y ostree rpm-ostree origin
fi
yum clean all

useradd walters -G wheel
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/wheel-nopasswd
if rpm -q mock 2>/dev/null; then
    usermod -a -G mock walters
fi
runuser -u walters /usr/lib/container/user.sh
cp -f /home/walters/.bashrc /root
