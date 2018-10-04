#!/usr/bin/bash
set -xeuo pipefail
# Set up runtime directories
mkdir -m 0700 -p /run/user/0
mkdir -m 0700 -p /run/user/1000 && chown 1000:1000 /run/user/1000
export XDG_RUNTIME_DIR=/run/user/1000
echo ${container} > /run/container
# Ensure we've unshared our mount namespace so
# the later umount doesn't affect the host potentially
if [ -e /sys/fs/selinux/status ]; then
    if [ -z "${hackaround_podman_selinux:-}" ]; then
        exec env hackaround_podman_selinux=1 unshare -m -- $0 "$@"
    else
        # Work around https://github.com/containers/libpod/issues/1448
        umount /sys/fs/selinux
    fi
fi
exec setpriv --reuid 1000 --regid 1000 --clear-groups -- env HOME=/home/walters chrt --idle 0 dumb-init /usr/bin/tmux -l
