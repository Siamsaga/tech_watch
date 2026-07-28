#!/bin/bash

# Configuration
LOG_FILE="/var/log/security_audit_$(date +%Y%m%d).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Fonctions utilitaires
print_section() { echo -e "\n\033[1;34m=== $1 ===\033[0m"; }
print_warning() { echo -e "\033[1;31m[!] $1\033[0m"; }
print_ok() { echo -e "\033[1;32m[+] $1\033[0m"; }

# 1. Informations système
print_section "INFORMATIONS SYSTÈME"
{
  echo "Date: $(date)"
  echo "Hostname: $(hostname)"
  echo "OS: $(lsb_release -d | cut -f2-)"
  echo "Noyau: $(uname -r)"
  echo "Uptime: $(uptime -p)"
} | column -t

# 2. Utilisateurs et accès
print_section "UTILISATEURS ET ACCÈS"
{
  echo -e "\n[+] Utilisateurs avec shell actif:"
  grep -vE '/nologin|/false' /etc/passwd | cut -d: -f1,7

  echo -e "\n[+] Utilisateurs avec droits sudo:"
  grep -Po '^sudo.+:\K.*$' /etc/group

  echo -e "\n[+] Sessions SSH actives:"
  who

  echo -e "\n[+] Connexions récentes:"
  last -n 10

  echo -e "\n[!] Comptes sans mot de passe:"
  awk -F: '($2 == "") {print $1}' /etc/shadow
} | column -t -s $'\t'

# 3. Services et ports ouverts
print_section "SERVICES ET PORTS OUVERTS"
{
  echo -e "\n[+] Services actifs:"
  systemctl list-units --type=service --state=running --no-pager | grep -vE '^UNIT|^●'

  echo -e "\n[+] Ports ouverts:"
  ss -tulnp | grep -vE '^Netid|127.0.0.1'

  echo -e "\n[!] Services vulnérables (version obsolète):"
  apt list --installed 2>/dev/null | grep -E 'apache|nginx|mysql|postgresql|openssh' | while read -r pkg; do
    version=$(echo "$pkg" | cut -d' ' -f2)
    echo "$pkg | $(apt-cache policy $(echo "$pkg" | cut -d'/' -f1) | grep -E 'Candidate|Installed' | tr '\n' ' ')"
  done
} | column -t

# 4. Configuration SSH
print_section "CONFIGURATION SSH"
{
  echo -e "\n[+] Fichier de config SSH:"
  grep -E '^PermitRootLogin|^PasswordAuthentication|^Port' /etc/ssh/sshd_config

  echo -e "\n[!] Clés SSH autorisées (vérifier les clés inconnues):"
  find /home -name "authorized_keys" -exec ls -la {} \; 2>/dev/null
  cat /root/.ssh/authorized_keys 2>/dev/null
} | column -t

# 5. Pare-feu et règles réseau
print_section "PARE-FEU ET RÈGLES RÉSEAU"
{
  echo -e "\n[+] Statut UFW:"
  ufw status verbose

  echo -e "\n[+] Règles iptables:"
  iptables -L -n -v

  echo -e "\n[!] Interfaces réseau exposées:"
  ip a | grep -E 'inet (eth|ens|enp)' | grep -v '127.0.0.1'
} | column -t

# 6. Fichiers sensibles et permissions
print_section "FICHIERS SENSIBLES ET PERMISSIONS"
{
  echo -e "\n[!] Fichiers avec permissions 777:"
  find / -type f -perm 0777 -exec ls -la {} \; 2>/dev/null

  echo -e "\n[!] Fichiers sensibles accessibles en écriture:"
  find /etc -type f -writable -exec ls -la {} \; 2>/dev/null

  echo -e "\n[+] Fichiers SUID/SGID:"
  find / -type f -perm -4000 -o -perm -2000 -exec ls -la {} \; 2>/dev/null
} | column -t

# 7. Mises à jour et vulnérabilités
print_section "MISES À JOUR ET VULNÉRABILITÉS"
{
  echo -e "\n[+] Paquets obsolètes:"
  apt list --upgradable 2>/dev/null

  echo -e "\n[!] Vulnérabilités connues (CVE):"
  apt-get update >/dev/null 2>&1
  apt-get --just-print upgrade | grep -E 'Inst.*security' | awk '{print $2}'
} | column -t

# 8. Journaux et anomalies
print_section "JOURNAUX ET ANOMALIES"
{
  echo -e "\n[!] Tentatives de connexion SSH échouées:"
  grep "Failed password" /var/log/auth.log | tail -n 20

  echo -e "\n[!] Connexions SSH suspectes:"
  grep "Accepted password" /var/log/auth.log | tail -n 20

  echo -e "\n[+] Processus suspects:"
  ps aux --sort=-%mem | head -n 10
} | column -t

# 9. Recommandations
print_section "RECOMMANDATIONS"
{
  echo -e "\n1. CORRECTIONS CRITIQUES:"
  echo "   - Désactiver l'accès root SSH: sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config"
  echo "   - Désactiver l'authentification par mot de passe SSH: sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
  echo "   - Mettre à jour tous les paquets: apt update && apt upgrade -y"

  echo -e "\n2. AMÉLIORATIONS RECOMMANDÉES:"
  echo "   - Installer et configurer fail2ban: apt install fail2ban && systemctl enable fail2ban"
  echo "   - Configurer UFW: ufw allow 22/tcp && ufw enable"
  echo "   - Installer lynis pour un audit approfondi: apt install lynis && lynis audit system"
} | column -t

print_ok "Audit terminé. Rapport sauvegardé dans $LOG_FILE"
