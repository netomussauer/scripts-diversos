#!/bin/bash
# =============================================================================
# Script:    fix-labadmin.sh
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Diagnosticar usuario labadmin no notebook-i5 (192.168.1.65):
#            existencia do usuario, authorized_keys, sudoers, sshd_config.
# Contexto:  Usado quando o cloud-init / Ansible nao terminou de provisionar
#            o usuario labadmin no notebook bare-metal, ou apos um update
#            de SO que pode ter reescrito sshd_config.
# Pre-req:   - bash no WSL/Linux
#            - SSH ja funciona como netomussauer com $HOME/.ssh/lab_id_rsa
#            - netomussauer tem sudo NOPASSWD
# Uso:       ./fix-labadmin.sh
# =============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOST=192.168.1.65
KEY="$HOME/.ssh/lab_id_rsa"
LAB_PUBKEY=$(cat "$HOME/.ssh/lab_id_rsa.pub")

echo "=== Conectando como netomussauer para diagnosticar ==="
ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
  -i "$KEY" "netomussauer@$HOST" "
echo '--- Sistema ---'
cat /etc/os-release | head -3
echo ''
echo '--- usuario netomussauer ---'
id
echo ''
echo '--- labadmin existe? ---'
id labadmin 2>&1 || echo 'NAO EXISTE'
echo ''
echo '--- /home/labadmin/.ssh/ ---'
sudo ls -la /home/labadmin/.ssh/ 2>&1 || echo 'pasta nao existe'
echo ''
echo '--- authorized_keys labadmin ---'
sudo cat /home/labadmin/.ssh/authorized_keys 2>&1 || echo 'arquivo nao existe'
echo ''
echo '--- sudoers labadmin ---'
sudo cat /etc/sudoers.d/labadmin 2>&1 || echo 'sudoers nao configurado'
echo ''
echo '--- sudoers do netomussauer ---'
sudo cat /etc/sudoers.d/netomussauer 2>&1 || sudo grep netomussauer /etc/sudoers 2>&1 || echo 'nao encontrado'
echo ''
echo '--- PasswordAuthentication no sshd_config ---'
sudo grep -E 'PasswordAuthentication|PubkeyAuthentication|PermitRootLogin' /etc/ssh/sshd_config
" 2>&1
