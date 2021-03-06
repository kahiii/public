#!/usr/bin/env bash

# Configure Z01 Ubuntu

# Log stdout & stderr
exec > >(tee -i /tmp/install_ubuntu.log) 2>&1

script_dir="$(cd -P "$(dirname "$BASH_SOURCE")" && pwd)"
cd $script_dir
. set.sh

disk=$(lsblk -o tran,kname,hotplug,type,fstype -pr |
	grep '0 disk' |
	cut -d' ' -f2 |
	sort |
	head -n1)

systemctl stop unattended-upgrades.service

apt-get update
apt-get -y upgrade
apt-get -y autoremove --purge

apt-get -y install curl

# Remove outdated kernels
# old_kernels=$(ls -1 /boot/config-* | sed '$d' | xargs -n1 basename | cut -d- -f2,3)

# for old_kernel in $old_kernels; do
# 	dpkg -P $(dpkg-query -f '${binary:Package}\n' -W *"$old_kernel"*)
# done

apt-get -yf install

# Configure Terminal

# Makes bash case-insensitive
cat <<EOF>> /etc/inputrc
set completion-ignore-case
set show-all-if-ambiguous On
set show-all-if-unmodified On
EOF

# Enhance Linux prompt
cat <<EOF> /etc/issue
Kernel build: \v
Kernel package: \r
Date: \d \t
IP address: \4
Terminal: \l@\n.\O

EOF

# Enable Bash completion
apt-get -y install bash-completion

cat <<EOF>> /etc/bash.bashrc
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF

# Set-up all users
for dir in $(ls -1d /root /home/* 2>/dev/null ||:)
do
	# Hide login informations
	touch $dir/.hushlogin

	# Add convenient aliases & behaviors
	cat <<-'EOF'>> $dir/.bashrc
	export LS_OPTIONS="--color=auto"
	eval "`dircolors`"

	alias df="df --si"
	alias du="du -cs --si"
	alias free="free -h --si"
	alias l="ls $LS_OPTIONS -al --si --group-directories-first"
	alias less="less -i"
	alias nano="nano -clDOST4"
	alias pstree="pstree -palU"

	GOPATH=$HOME/go
	HISTCONTROL=ignoreboth
	HISTFILESIZE=
	HISTSIZE=
	HISTTIMEFORMAT="%F %T "
	EOF

	# Fix rights
	usr=$(echo "$dir" | rev | cut -d/ -f1 | rev)
	chown -R $usr:$usr $dir ||:
done

# Install OpenSSH

ssh_port=512

# Install dependencies
apt-get -y install ssh

cat <<EOF>> /etc/ssh/sshd_config
Port $ssh_port
PasswordAuthentication no
AllowUsers root
EOF

# Install firewall

apt-get -y install ufw

ufw logging off
ufw allow in "$ssh_port"/tcp
ufw allow in 27960:27969/tcp
ufw allow in 27960:27969/udp
ufw --force enable

# Install Grub

sed -i -e 's/message=/message_null=/g' /etc/grub.d/10_linux

cat <<EOF>> /etc/default/grub
GRUB_TIMEOUT=0
GRUB_RECORDFAIL_TIMEOUT=0
GRUB_TERMINAL=console
GRUB_DISTRIBUTOR=``
GRUB_DISABLE_OS_PROBER=true
GRUB_DISABLE_SUBMENU=y
EOF

update-grub
grub-install "$disk"

# Install Go

wget https://dl.google.com/go/go1.15.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.15.2.linux-amd64.tar.gz
rm go1.15.2.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile

# Set-up all users
for dir in $(ls -1d /root /home/* 2>/dev/null ||:)
do
	# Add convenient aliases & behaviors
	cat <<-'EOF'>> $dir/.bashrc
	GOPATH=$HOME/go
	PATH=$PATH:$GOPATH/bin
	alias gobuild='CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w"'
	EOF
	echo 'GOPATH=$HOME/go' >> $dir/.profile

	# Fix rights
	usr=$(echo "$dir" | rev | cut -d/ -f1 | rev)
	chown -R $usr:$usr $dir ||:
done

# Install Node.js

curl -sL https://deb.nodesource.com/setup_12.x | bash -
apt-get -y install nodejs

# Install FX: command-line JSON processing tool (https://github.com/antonmedv/fx)

npm install -g fx

# Install Sublime Text & Sublime Merge

wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
apt-get install -y apt-transport-https

cat <<EOF> /etc/apt/sources.list.d/sublime-text.list
deb https://download.sublimetext.com/ apt/stable/
EOF

apt-get update
apt-get install -y sublime-text sublime-merge libgtk2.0-0

# Install VSCode

wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | apt-key add -
echo 'deb https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main' >> /etc/apt/sources.list.d/vscodium.list

apt-get update
apt-get install -y codium

ln -s /usr/bin/codium /usr/local/bin/code ||:

# Set-up all users
for dir in $(ls -1d /home/* 2>/dev/null ||:)
do
	# Disable most of the telemetry and auto-updates
	mkdir -p $dir/.config/VSCodium/User
	cat <<-'EOF'> $dir/.config/VSCodium/User/settings.json
	{
	    "telemetry.enableCrashReporter": false,
	    "telemetry.enableTelemetry": false,
	    "update.enableWindowsBackgroundUpdates": false,
	    "update.mode": "none",
	    "update.showReleaseNotes": false,
	    "extensions.autoCheckUpdates": false,
	    "extensions.autoUpdate": false,
	    "workbench.enableExperiments": false,
	    "workbench.settings.enableNaturalLanguageSearch": false,
	    "npm.fetchOnlinePackageInfo": false
	}
	EOF

	# Fix rights
	usr=$(echo "$dir" | rev | cut -d/ -f1 | rev)
	chown -R $usr:$usr $dir ||:
done

# Install LibreOffice

apt-get -y install libreoffice

# Install Exam app

wget https://01.alem.school/assets/files/exam.AppImage -O /usr/local/bin/exam.AppImage
chmod +x /usr/local/bin/exam.AppImage

cat <<EOF> /home/student/.local/share/applications/appimagekit-exam.desktop
[Desktop Entry]
Name=exam
Comment=the exam client
Exec="/usr/local/bin/exam.AppImage" %U
Terminal=false
Type=Application
Icon=appimagekit-exam
StartupWMClass=exam
X-AppImage-Version=1.0.0
MimeType=x-scheme-handler/exam;
Categories=Utility;
X-AppImage-BuildId=1RHp8aPhkSgD1PXGL1NW5QDsbFF
X-Desktop-File-Install-Version=0.23
X-AppImage-Comment=Generated by /tmp/.mount_exam.1PqfsDP/AppRun
TryExec=/usr/local/bin/exam.AppImage
EOF
chown student:student /home/student/.local/share/applications/appimagekit-exam.desktop

sudo -iu student xdg-mime default appimagekit-exam.desktop x-scheme-handler/exam

# Install Go library

sudo -iu student go get github.com/01-edu/z01

# Install Docker

apt-get -y install docker.io
adduser student docker

# Purge unused Ubuntu packages
pkgs="
apparmor
apport
bind9
bolt
cups*
exim*
fprintd
friendly-recovery
gnome-initial-setup
gnome-online-accounts
gnome-power-manager
gnome-software
gnome-software-common
memtest86+
orca
popularity-contest
python3-update-manager
secureboot-db
snapd
speech-dispatcher*
spice-vdagent
ubuntu-report
ubuntu-software
unattended-upgrades
update-inetd
update-manager-core
update-notifier
update-notifier-common
whoopsie
xdg-desktop-portal
"

apt-get -y purge $pkgs
apt-get -y autoremove --purge

# Install packages
pkgs="$(cat common_packages.txt)
baobab
blender
dconf-editor
emacs
f2fs-tools
firefox
gimp
gnome-calculator
gnome-system-monitor
gnome-tweaks
golang-mode
i3lock
imagemagick
mpv
vim
virtualbox
xfsprogs
zenity
"
apt-get -y install $pkgs

# Disable services
services="
apt-daily-upgrade.timer
apt-daily.timer
console-setup.service
e2scrub_reap.service
keyboard-setup.service
motd-news.timer
remote-fs.target
"
systemctl disable $services

services="
grub-common.service
plymouth-quit-wait.service
"
systemctl mask $services

# Disable GTK hidden scroll bars
echo GTK_OVERLAY_SCROLLING=0 >> /etc/environment

# Reveal boot messages
sed -i -e 's/TTYVTDisallocate=yes/TTYVTDisallocate=no/g' /etc/systemd/system/getty.target.wants/getty@tty1.service

# Speedup boot
sed -i 's/MODULES=most/MODULES=dep/g' /etc/initramfs-tools/initramfs.conf
sed -i 's/COMPRESS=gzip/COMPRESS=lz4/g' /etc/initramfs-tools/initramfs.conf

# Reveal autostart services
sed -i 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/*.desktop

# Remove password complexity constraints
sed -i 's/ obscure / minlen=1 /g' /etc/pam.d/common-password

# Remove splash screen (plymouth)
sed -i 's/quiet splash/quiet/g' /etc/default/grub

update-initramfs -u
update-grub

# Change ext4 default mount options
sed -i -e 's/ errors=remount-ro/ noatime,nodelalloc,errors=remount-ro/g' /etc/fstab

# Disable swapfile
swapoff /swapfile ||:
rm -f /swapfile
sed -i '/swapfile/d' /etc/fstab

# Put temporary and cache folders as tmpfs
echo 'tmpfs /tmp tmpfs defaults,noatime,rw,nosuid,nodev,mode=1777,size=1G 0 0' >> /etc/fstab

# Install additional drivers
ubuntu-drivers install ||:

# Copy system files

cp -r system /tmp
cd /tmp/system

test -v PERSISTENT && rm -rf etc/gdm3 usr/share/initramfs-tools

# Overwrite with custom files from Git repository
if test -v OVERWRITE; then
	folder=$(echo "$OVERWRITE" | cut -d';' -f1)
	url=$(echo "$OVERWRITE" | cut -d';' -f2)
	if git ls-remote -q "$url" &>/dev/null; then
		tmp=$(mktemp -d)
		git clone --depth 1 "$url" "$tmp"
		rm -rf "$tmp"/.git
		cp -aT "$tmp" "$folder"
		rm -rf "$tmp"
	fi
fi

# Fix permissions
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;
find . -type f -exec /bin/sh -c "file {} | grep -q 'shell script' && chmod +x {}" \;
find . -type f -exec /bin/sh -c "file {} | grep -q 'public key' && chmod 400 {}" \;

sed -i -e "s|::DISK::|$disk|g" etc/udev/rules.d/10-local.rules

# Generate wallpaper
cd usr/share/backgrounds/01
test ! -e wallpaper.png && composite logo.png background.png wallpaper.png
cd /tmp/system

cp --preserve=mode -RT . /

cd $script_dir
rm -rf /tmp/system

if ! test -v PERSISTENT; then
	sgdisk -n0:0:+32G "$disk"
	sgdisk -N0 "$disk"
	sgdisk -c3:01-tmp-home "$disk"
	sgdisk -c4:01-tmp-system "$disk"

	# Remove fsck because the system partition will be read-only (overlayroot)
	rm /usr/share/initramfs-tools/hooks/fsck

	apt-get -y install overlayroot
	echo 'overlayroot="device:dev=/dev/disk/by-partlabel/01-tmp-system,recurse=0"' >> /etc/overlayroot.conf

	update-initramfs -u

	# Lock root password
	passwd -l root

	# Disable user password
	passwd -d student

	# Enable docker relocation
	systemctl enable mount-docker

	# Remove tty
	cat <<-EOF>> /etc/systemd/logind.conf
	NAutoVTs=0
	ReserveVT=N
	EOF

	# Remove user abilities
	gpasswd -d student sudo
	gpasswd -d student lpadmin
	gpasswd -d student sambashare

	cp /etc/shadow /etc/shadow-
fi

# Clean system

# Purge useless packages
apt-get -y autoremove --purge
apt-get autoclean
apt-get clean
apt-get install

rm -rf /root/.local

# Remove connection logs
> /var/log/lastlog
> /var/log/wtmp
> /var/log/btmp

# Remove machine ID
> /etc/machine-id

# Remove logs
cd /var/log
rm -rf alternatives.log*
rm -rf apt/*
rm -rf auth.log
rm -rf dpkg.log*
rm -rf gpu-manager.log
rm -rf installer
rm -rf journal/d6e982aa8c9d4c1dbcbdcff195642300
rm -rf kern.log
rm -rf syslog
rm -rf sysstat

# Remove random seeds
rm -rf /var/lib/systemd/random-seed
rm -rf /var/lib/NetworkManager/secret_key

# Remove network configs
rm -rf /etc/NetworkManager/system-connections/*
rm -rf /var/lib/bluetooth/*
rm -rf /var/lib/NetworkManager/*

# Remove caches
rm -rf /var/lib/gdm3/.cache/*
rm -rf /root/.cache
rm -rf /home/student/.cache

rm -rf /home/student/.sudo_as_admin_successful /home/student/.bash_logout

rm -rf /tmp/*
rm -rf /tmp/.* ||:
