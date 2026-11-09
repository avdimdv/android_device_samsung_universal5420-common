#!/bin/bash
# Run once in WSL Ubuntu 20.04 as root:  wsl -d Ubuntu -u root -- bash 01-setup-host.sh
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs \
  gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev libelf-dev liblz4-tool \
  libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync \
  schedtool squashfs-tools xsltproc zip unzip zlib1g-dev python2 python-is-python2 python3
curl -s https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
chmod a+x /usr/local/bin/repo
