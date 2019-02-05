#!/bin/sh
# activate the dashboard
# this script WILL BE RUN ONLY ONCE, after the installation
# this script WILL NOT RUN during/after upgrades

DIDRUNFILE=/var/lib/misc/caasp-admin-node-init-did-run

# Don't run this script a second time
test -f ${DIDRUNFILE}  && exit 0

# Make sure that the controller node looks for the local pause image
# TODO: remove this as soon as possible. As an idea, we could use a systemd drop-in unit.
if ! grep "pod-infra-container-image" /etc/kubernetes/kubelet &> /dev/null; then
  CAASP_VERSION="$(cat /etc/os-release  | grep PRETTY_NAME | cut -d'=' -f2 | sed 's/[^0-9]//g')"
  # If caasp is 40 we need to use registry images
  if [ "$CAASP_VERSION" -eq "40" ]; then
    sed -i 's|^KUBELET_ARGS="|KUBELET_ARGS="--pod-infra-container-image=registry.suse.de/devel/casp/head/containers/sle-12-sp3/container/caasp/v4/pause:0.1 |' /etc/kubernetes/kubelet
  else
  # for caasp < 40 we don't use registry
    sed -i 's|^KUBELET_ARGS="|KUBELET_ARGS="--pod-infra-container-image=sles12/pause:1.0.0 |' /etc/kubernetes/kubelet
  fi
fi

# Make sure etcd listens on 0.0.0.0
sed -i 's@#\?ETCD_LISTEN_CLIENT_URLS.*@ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379@' /etc/sysconfig/etcd

# Generate root ssh key and share it with velum
# https://bugzilla.suse.com/show_bug.cgi?id=1030876
if ! [ -f /root/.ssh/id_rsa ]; then
  ssh-keygen -b 4096 -f /root/.ssh/id_rsa -t rsa -N ""
fi
[ -d /var/lib/misc/ssh-public-key  ] || mkdir -p /var/lib/misc/ssh-public-key
cp /root/.ssh/id_rsa.pub /var/lib/misc/ssh-public-key

# Connect the salt-minion running in the administration controller node to the local salt-master
# instance that is running in a container
cat <<EOF > /etc/salt/grains
roles:
- admin
EOF
echo "master: localhost" > /etc/salt/minion.d/minion.conf
echo "id: admin" > /etc/salt/minion.d/minion_id.conf

# Disable swap
# On ISO-based installs the script runs in a chroot and then the system is rebooted
sed -i '/^#/! {/ swap / s/^/#/}' /etc/fstab

# Mark that the script did run
touch ${DIDRUNFILE}
