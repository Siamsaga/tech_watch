#!/bin/bash

###############################################################################
# Basic VPS Hardening Script
#
# Target:
#   Ubuntu 24.04 LTS / Ubuntu 26.04 LTS
#
# Purpose:
#   - Apply basic security hardening
#   - Secure SSH access
#   - Enable firewall
#   - Install Fail2ban
#   - Configure automatic security updates
#   - Apply kernel network protections
#
# WARNING:
#   Before running this script:
#
#   1. Create a non-root sudo user
#   2. Install your SSH public key
#   3. Verify SSH key authentication works
#
# Example:
#
#   adduser matthieu
#   usermod -aG sudo matthieu
#
#   ssh-copy-id matthieu@server-ip
#
###############################################################################

set -e

echo "=================================================="
echo "VPS HARDENING STARTED"
echo "=================================================="

###############################################################################
# STEP 1 - SYSTEM UPDATE
#
# Keep the operating system packages up to date.
# Most successful attacks target unpatched systems.
###############################################################################

echo ""
echo "[1/8] Updating system packages..."

apt update
apt upgrade -y

###############################################################################
# STEP 2 - SECURITY PACKAGES
#
# UFW                  -> firewall management
# Fail2ban             -> brute force protection
# Auditd               -> security auditing
# Unattended Upgrades  -> automatic security updates
# Apt Listchanges      -> package change notifications
###############################################################################

echo ""
echo "[2/8] Installing security packages..."

apt install -y \
    ufw \
    fail2ban \
    auditd \
    unattended-upgrades \
    apt-listchanges

###############################################################################
# STEP 3 - AUTOMATIC SECURITY UPDATES
#
# Automatically installs security patches.
#
# Benefits:
# - Reduces exposure time
# - Protects against known vulnerabilities
# - Reduces maintenance effort
###############################################################################

echo ""
echo "[3/8] Configuring automatic security updates..."

dpkg-reconfigure -f noninteractive unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

###############################################################################
# STEP 4 - SSH HARDENING
#
# Security controls:
#
# - Disable root login
# - Disable password authentication
# - Enable public key authentication
#
# This dramatically reduces brute-force attacks.
#
# IMPORTANT:
# Test your SSH key BEFORE running this script.
###############################################################################

echo ""
echo "[4/8] Hardening SSH configuration..."

cp /etc/ssh/sshd_config \
   /etc/ssh/sshd_config.backup.$(date +%F)

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' \
    /etc/ssh/sshd_config

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' \
    /etc/ssh/sshd_config

sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' \
    /etc/ssh/sshd_config

systemctl restart ssh

###############################################################################
# STEP 5 - FIREWALL CONFIGURATION
#
# Default policy:
#
# - Deny incoming traffic
# - Allow outgoing traffic
#
# Allowed services:
#
# 22  -> SSH
# 80  -> HTTP
# 443 -> HTTPS
#
# Everything else is blocked.
###############################################################################

echo ""
echo "[5/8] Configuring firewall..."

ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

###############################################################################
# STEP 6 - FAIL2BAN
#
# Detects repeated failed login attempts.
#
# Example:
#
# Five failed SSH login attempts
# -> IP address automatically blocked
#
# Current settings:
#
# - 5 attempts
# - During 10 minutes
# - Ban duration: 1 hour
###############################################################################

echo ""
echo "[6/8] Configuring Fail2ban..."

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]

bantime = 1h
findtime = 10m
maxretry = 5

[sshd]

enabled = true
EOF

systemctl enable fail2ban
systemctl restart fail2ban

###############################################################################
# STEP 7 - KERNEL HARDENING
#
# Network protections:
#
# ICMP broadcast protection
# Redirect protection
# Source routing protection
# SYN flood protection
#
# Filesystem protections:
#
# Hardlink protection
# Symlink protection
#
# Information disclosure reduction:
#
# Restrict kernel pointer visibility
# Restrict dmesg access
###############################################################################

echo ""
echo "[7/8] Applying kernel hardening..."

cat > /etc/sysctl.d/99-hardening.conf <<EOF

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Disable sending redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Filesystem hardlink protection
fs.protected_hardlinks = 1

# Filesystem symlink protection
fs.protected_symlinks = 1

EOF

sysctl --system

###############################################################################
# STEP 8 - AUDITING SERVICES
#
# Auditd records important security events.
#
# Useful for:
#
# - Incident investigation
# - Compliance
# - Detecting suspicious activity
###############################################################################

echo ""
echo "[8/8] Starting auditing services..."

systemctl enable auditd
systemctl start auditd

###############################################################################
# FINAL STATUS
###############################################################################

echo ""
echo "=================================================="
echo "HARDENING COMPLETED SUCCESSFULLY"
echo "=================================================="

echo ""
echo "Security Summary"
echo "----------------"

echo "✓ Root SSH login disabled"
echo "✓ Password authentication disabled"
echo "✓ SSH key authentication enabled"
echo "✓ Firewall enabled"
echo "✓ Fail2ban enabled"
echo "✓ Automatic updates enabled"
echo "✓ Kernel hardening applied"
echo "✓ Auditd enabled"

echo ""
echo "Verification Commands"
echo "---------------------"

echo ""
echo "Check SSH status:"
echo "  sshd -T | grep permitrootlogin"

echo ""
echo "Check firewall:"
echo "  ufw status verbose"

echo ""
echo "Check Fail2ban:"
echo "  fail2ban-client status sshd"

echo ""
echo "Check automatic updates:"
echo "  systemctl status unattended-upgrades"

echo ""
echo "Check Auditd:"
echo "  systemctl status auditd"

echo ""
echo "Recommended next steps:"
echo ""
echo "1. Install CrowdSec"
echo "2. Configure Docker security"
echo "3. Enable MFA where possible"
echo "4. Configure backups"
echo "5. Set up monitoring (Uptime Kuma)"
echo "6. Protect admin applications behind authentication"
echo ""