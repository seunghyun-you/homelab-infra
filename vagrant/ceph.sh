#!/usr/bin/env bash

# ENV SETTING
NODES=$1      # 3

echo ">>>> Initial Config Start <<<<"

echo "[TASK 1] Setting Profile & Bashrc"
echo 'alias vi=vim' >> /etc/profile
echo "sudo su -" >> /home/vagrant/.bashrc
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime # Change Timezone



echo "[TASK 2] Disable AppArmor"
systemctl stop ufw && systemctl disable ufw >/dev/null 2>&1
systemctl stop apparmor && systemctl disable apparmor >/dev/null 2>&1



echo "[TASK 3] Domain Setting"
for (( i=1; i<=${NODES}; i++  )); do echo "192.168.50.20$i ceph-0$i" >> /etc/hosts; done
for (( i=1; i<=${NODES}; i++  )); do echo "192.168.50.20$i ceph-0$i-cluster" >> /etc/hosts; done



echo "[TASK 4] Install Packages"
sudo apt update >/dev/null 2>&1
sudo apt install -y chrony docker.io >/dev/null 2>&1
# sudo apt install -y chrony podman >/dev/null 2>&1
sudo systemctl enable --now chrony >/dev/null 2>&1
sudo systemctl enable --now docker >/dev/null 2>&1
# sudo systemctl enable --now podman.socket >/dev/null 2>&1


echo "[TASK 5] Install Cephadm and Settings"
apt install cephadm -y >/dev/null 2>&1

# add reef storage
./cephadm add-repo --release reef >/dev/null 2>&1
apt update -qq >/dev/null 2>&1
./cephadm install >/dev/null 2>&1



echo "[TASK 6] Configure SSH for Root"
# Generate SSH key if not exists
if [ ! -f "/root/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa >/dev/null 2>&1
fi

# Enable password authentication for initial setup
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i '/^#*PermitRootLogin /c\PermitRootLogin yes' /etc/ssh/sshd_config
systemctl restart ssh

# Set root password (optional, for manual SSH copy-id)
echo "root:vagrant" | chpasswd

echo ">>>> Initial Config Completed <<<<"