#!/bin/bash
# =============================================================================
# Script:    diagnose-i5.sh
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Diagnosticar acesso SSH ao notebook-i5 (192.168.1.65 /
#            inventario Ansible = "notebook-i5", hostname K8s = "ubuntu-neto",
#            label workload=monitoring). Testa portas, captura fingerprint,
#            banner, e cruza chaves x usuarios.
# Contexto:  Usado quando o no perdeu acesso SSH apos um cycle de power
#            ou apos mudanca de chaves. Mostra quais metodos de auth o
#            servidor aceita.
# Pre-req:   - bash no WSL/Linux
#            - Chaves em ~/.ssh/ (lab_id_rsa, id_ed25519, id_ed25519_jump)
# Uso:       ./diagnose-i5.sh
# =============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOST=192.168.1.65
KEY_DIR="$HOME/.ssh"

echo "=== Portas abertas ==="
for port in 22 2222 2200; do
  nc -z -w 2 "$HOST" "$port" 2>/dev/null && echo "  $port: ABERTA" || echo "  $port: fechada"
done

echo ""
echo "=== Fingerprint do servidor ==="
ssh-keyscan -T 3 "$HOST" 2>/dev/null | ssh-keygen -lf - 2>/dev/null || echo "  keyscan falhou"

echo ""
echo "=== Banner SSH (mostra possiveis pistas) ==="
timeout 3 ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
  -v tmpuser@"$HOST" 'echo ok' 2>&1 | grep -E "banner|Banner|motd|MOTD|Ubuntu|Debian|Raspbian|version|OS" || true

echo ""
echo "=== Testar cada chave x cada usuario ==="
for key in lab_id_rsa id_ed25519 id_ed25519_jump; do
  [ -f "$KEY_DIR/$key" ] || continue
  for user in labadmin ubuntu pi jose netomussauer; do
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
      -i "$KEY_DIR/$key" "${user}@${HOST}" 'echo OK' 2>&1)
    if echo "$out" | grep -q '^OK$'; then
      echo "  SUCESSO: $user + $key"
    elif echo "$out" | grep -q 'denied.*publickey,password\|denied.*password,publickey'; then
      # publickey falhou mas senha possivel - usuario pode existir
      echo "  $user + $key: publickey negada (senha possivel)"
    elif echo "$out" | grep -q 'denied.*publickey$'; then
      # apenas publickey permitida - usuario pode existir mas chave errada
      echo "  $user + $key: publickey negada (so publickey permitida)"
    elif echo "$out" | grep -q 'refused\|timed out\|No route'; then
      echo "  $user + $key: host inacessivel"
      break 2
    fi
  done
done

echo ""
echo "=== Auth methods aceitos pelo servidor ==="
# ssh com usuario ficticio para ver quais metodos o servidor anuncia
timeout 5 ssh -v -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=no \
  probe_user@"$HOST" 'x' 2>&1 | grep -E 'Authentications that can continue' | head -3
