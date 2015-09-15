#!/bin/bash
set -e
source /bd_build/buildconfig
set -x

## Temporarily disable dpkg fsync to make building faster.
if [[ ! -e /etc/dpkg/dpkg.cfg.d/docker-apt-speedup ]]; then
	echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup
fi

## Prevent initramfs updates from trying to run grub and lilo.
## https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/
## http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=594189
export INITRD=no
mkdir -p /etc/container_environment
echo -n no > /etc/container_environment/INITRD

## Enable Ubuntu Universe and Multiverse.
sed -i 's/^#\s*\(deb.*universe\)$/\1/g' /etc/apt/sources.list
sed -i 's/^#\s*\(deb.*multiverse\)$/\1/g' /etc/apt/sources.list
apt-get update

## Fix some issues with APT packages.
## See https://github.com/dotcloud/docker/issues/1024
dpkg-divert --local --rename --add /sbin/initctl
ln -sf /bin/true /sbin/initctl

## Replace the 'ischroot' tool to make it always return true.
## Prevent initscripts updates from breaking /dev/shm.
## https://journal.paul.querna.org/articles/2013/10/15/docker-ubuntu-on-rackspace/
## https://bugs.launchpad.net/launchpad/+bug/974584
dpkg-divert --local --rename --add /usr/bin/ischroot
ln -sf /bin/true /usr/bin/ischroot

## Install HTTPS support for APT.
$minimal_apt_get_install apt-transport-https ca-certificates

## Install add-apt-repository
$minimal_apt_get_install software-properties-common

## Upgrade all packages.
apt-get dist-upgrade -y --no-install-recommends

## Fix locale.
$minimal_apt_get_install language-pack-en
locale-gen en_US
update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8
echo -n en_US.UTF-8 > /etc/container_environment/LANG
echo -n en_US.UTF-8 > /etc/container_environment/LC_CTYPE

## Install Chef
$minimal_apt_get_install wget
cd /tmp
wget https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/10.04/x86_64/chef_12.4.1-1_amd64.deb
dpkg -i chef_12.*_amd64.deb
rm chef_12.*_amd64.deb
cd

## Install ssh key
mkdir -p /root/.ssh
cat << EOF > /root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfAMwt9UREWVvdvhF/HV1aI4BKladErVIPogFUiznCbHskIDETozP/xi9eEgZZT4Ziv9Kme34MRNBLrVlsdG+pfqYyHgV7ibCEUD69twxSGxtqQYJOpVSMNLGA4sWicrkGGRWOIx4+BHsAb0J/cV3GBZ5Wq8/S++ALlQsSWWdNPpKZ9eUESM0UFpZCf5InBUxzc4vkP4Rl7R81fh1h/iF6EUSEh2LwJ0f3MEEikbw2sxkaEICx3u6upjYj2c3JLpTgoS2FXRsZFiixG68c3HSs9hTKlX2X+73Vb+0Vf0XesQGWogmyyJwTx4uvaDKsG8itrFNaoRz6Gi7QG6s+pBBf cluk@hoss
EOF
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

