#!/bin/bash
# =============================================================================
# Script:    probe-baremetal.sh
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Probe rapido de SSH nos dois nos bare-metal:
#              - notebook-i5    192.168.1.65  (hostname K8s "ubuntu-neto")
#              - raspberry-pi   192.168.1.110 (hostname K8s "raspneto")
#            Varre portas comuns e testa combinacoes de chave x usuario.
# Contexto:  Util quando precisa saber rapidamente em qual porta/usuario
#            cada no bare-metal esta respondendo. Sem dependencias.
# Pre-req:   - bash no WSL/Linux
#            - Chaves em ~/.ssh/ (id_ed25519, id_ed25519_jump, lab_id_rsa)
# Uso:       ./probe-baremetal.sh
# =============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SSH_DIR="$HOME/.ssh"

echo '=== notebook-i5 (192.168.1.65): scan portas ==='
for port in 22 2222 22022 2200 8022; do
  if nc -z -w 2 192.168.1.65 "$port" 2>/dev/null; then
    echo "  porta $port: ABERTA"
  else
    echo "  porta $port: fechada"
  fi
done

echo ''
echo '=== notebook-i5: tentar SSH porta 22 com todas as chaves ==='
for key in id_ed25519 id_ed25519_jump lab_id_rsa; do
  for user in labadmin ubuntu jose netomussauer; do
    result=$(ssh -o ConnectTimeout=4 -o BatchMode=yes -o StrictHostKeyChecking=no \
      -i "${SSH_DIR}/${key}" "${user}@192.168.1.65" 'echo SSH_OK' 2>&1 | head -1)
    if echo "$result" | grep -q 'SSH_OK'; then
      echo "  SUCESSO: $user + $key"
    elif echo "$result" | grep -q 'refused\|timed out'; then
      echo "  $user + $key: conexao recusada/timeout"
      break 2
    fi
  done
done

echo ''
echo '=== raspberry-pi (192.168.1.110): tentar usuarios e chaves ==='
for key in id_ed25519 id_ed25519_jump lab_id_rsa; do
  for user in pi ubuntu labadmin; do
    result=$(ssh -o ConnectTimeout=4 -o BatchMode=yes -o StrictHostKeyChecking=no \
      -i "${SSH_DIR}/${key}" "${user}@192.168.1.110" 'echo SSH_OK; uname -a' 2>&1 | head -2)
    echo "  $user + $key: $(echo $result | head -c 80)"
  done
done
