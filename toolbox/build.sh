#!/bin/sh
set -xeuo pipefail

dn=$(cd $(dirname $0) && pwd)

# First, install rust in /usr
# https://github.com/rust-lang/rustup/issues/2383
curl https://sh.rustup.rs -sSf | sudo env RUSTUP_HOME=/usr/rust/rustup CARGO_HOME=/usr/rust/cargo sh -s -- --default-toolchain stable --profile default --no-modify-path -y

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
fi

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

case "${OS_ID}-${OS_VER}" in
    rhel-7.*|centos-7) yum_install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm;;
    rhel-8.*) yum_install dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm ;;
esac
if [ "${OS_ID}" = rhel ]; then
    yum_install rhpkg
fi

yum_install passwd sudo bash-completion tmux sudo \
     redhat-rpm-config make \
     libguestfs-tools strace libguestfs-xfs \
     virt-install curl git kernel rsync \
     gdb selinux-policy-targeted \
     createrepo_c
if ! test -x /usr/bin/dnf; then
    yum_install yum-utils
fi

# pre-downloaded source
mkdir -p /container/src
git clone https://github.com/cgwalters/homegit
