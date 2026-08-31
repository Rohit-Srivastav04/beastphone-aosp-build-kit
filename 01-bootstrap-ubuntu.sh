#!/usr/bin/env bash
# BeastPhone AOSP guest — Ubuntu bootstrap (run inside WSL Ubuntu)
set -euo pipefail

echo "=== $(date) bootstrap start ==="
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git-core gnupg flex bison build-essential zip curl zlib1g-dev \
  gcc-multilib g++-multilib libc6-dev-i386 libncurses5 lib32ncurses-dev \
  x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils \
  xsltproc unzip fontconfig python3 python3-pip python3-setuptools \
  openjdk-17-jdk libssl-dev libffi-dev rsync ccache libncurses6 \
  libtinfo6 libncurses-dev

mkdir -p "$HOME/bin"
curl -fsSL -o "$HOME/bin/repo" https://storage.googleapis.com/git-repo-downloads/repo
chmod a+x "$HOME/bin/repo"

# PATH for this user
if ! grep -q 'export PATH=$HOME/bin:$PATH' "$HOME/.bashrc"; then
  echo 'export PATH=$HOME/bin:$PATH' >> "$HOME/.bashrc"
fi
export PATH="$HOME/bin:$PATH"

git config --global user.email "beastphone-build@localhost"
git config --global user.name "BeastPhone Builder"
git config --global color.ui true

# 16G swap if RAM pressure during soong/java
if ! swapon --show | grep -q swapfile; then
  if [ ! -f /swapfile ]; then
    sudo fallocate -l 16G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=16384
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
  fi
  sudo swapon /swapfile || true
fi

repo --version
java -version
echo "=== $(date) bootstrap done ==="
echo "Next: bash ~/beastphone-build/02-aosp-sync.sh"
