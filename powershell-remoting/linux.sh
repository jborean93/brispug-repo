#!/bin/bash

set -e

# I hate doing this but it's a demo and it stops OMI from starting up
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0

# Install PowerShell Core
# https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6#installation-via-package-repository-preferred---fedora-27-fedora-28
rpm --import https://packages.microsoft.com/keys/microsoft.asc
curl https://packages.microsoft.com/config/rhel/7/prod.repo | tee /etc/yum.repos.d/microsoft.repo
dnf install -y compat-openssl10
dnf install -y powershell

# Install OMI and PSI OML Provider
wget https://github.com/Microsoft/omi/releases/download/v1.6.0/omi-1.6.0-0.ssl_110.ulinux.x64.rpm
rpm -Uvh ./omi-1.6.0-0.ssl_110.ulinux.x64.rpm
dnf install -y omi-psrp-server

# Setup NTLM authentication for vagrant:vagrant
dnf install -y gssntlmssp krb5-workstation
echo 'linux-host:vagrant:vagrant' > /etc/opt/omi/creds/ntlm
chmod 700 -R /etc/opt/omi/creds
chmod 600 /etc/opt/omi/creds/ntlm
chown omi:omi /etc/opt/omi/creds/ntlm
sed -i 's%#NtlmCredsFile=/etc/opt/omi/.creds/ntlm%NtlmCredsFile=/etc/opt/omi/creds/ntlm%' /etc/opt/omi/conf/omiserver.conf
systemctl restart omid

# Setup HTTP listener and Firewall rules
sed -i 's/httpport=0/httpport=0,5985/' /etc/opt/omi/conf/omiserver.conf
firewall-cmd --permanent --zone=public --add-port=5985/tcp
firewall-cmd --permanent --zone=public --add-port=5986/tcp
firewall-cmd --reload

# Add pwsh subsystem to SSH config
echo 'Subsystem powershell /usr/bin/pwsh -sshs -NoLogo -NoProfile' >> /etc/ssh/sshd_config
