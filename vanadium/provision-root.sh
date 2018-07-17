#!/usr/bin/bash
set -xeuo pipefail

# https://bugzilla.redhat.com/show_bug.cgi?id=1248916
rm -f /etc/xdg/autostart/gnome-keyring-ssh.desktop

cat >/etc/polkit-1/rules.d/polkit-libvirt.rules <<EOF
// From https://goldmann.pl/blog/2012/12/03/configuring-polkit-in-fedora-18-to-access-virt-manager/
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" && subject.isInGroup("wheel")) {
    return polkit.Result.YES;
  }
});
EOF

cat >/etc/krb5.conf.d/redhat <<EOF
[libdefaults]
 default_realm = REDHAT.COM

[realms]
REDHAT.COM = {
 kdc = kerberos.corp.redhat.com
 admin_server = kerberos.corp.redhat.com
}
EOF

# https://pagure.io/atomic-wg/issue/505
chcon system_u:object_r:container_file_t:s0 /var/srv

# Store "large" data in basically a secondary home directory
mkdir -p /var/srv/${USER}
chown ${USER}:${USER} /var/srv/${USER}
chcon --reference /home/${USER} /var/srv/${USER}

pkgs="emacs fuse-sshfs git-evtag krb5-workstation libvirt-client opensc origin-clients pcsc-lite-ccid strace tmux vagrant-libvirt virt-manager xsel ykclient ykpers"
status=$(rpm-ostree status)
for pkg in $pkgs; do
    if ! grep -qF "$pkg" <<< "${status}"; then
        rpm-ostree install $pkgs
        break
    fi
done