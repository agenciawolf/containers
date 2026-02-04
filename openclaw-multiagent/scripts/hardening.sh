#!/bin/bash
# Hardening script - Restrições adicionais de segurança

set -euo pipefail

WORKSPACE="/workspace"

# Limitar recursos do agente hacker via cgroups (se disponível)
setup_cgroups() {
    if [ -d /sys/fs/cgroup ]; then
        # Limitar CPU do hacker a 50% quando em stress
        mkdir -p /sys/fs/cgroup/hacker 2>/dev/null || true
        echo "100000" > /sys/fs/cgroup/hacker/cpu.cfs_quota_us 2>/dev/null || true
        echo "200000" > /sys/fs/cgroup/hacker/cpu.cfs_period_us 2>/dev/null || true
    fi
}

# Configurar audit logging para o agente hacker
setup_audit() {
    mkdir -p /workspace/audit
    # Log todos os comandos sudo do hacker
    echo 'Defaults logfile="/workspace/audit/hacker-sudo.log"' > /etc/sudoers.d/hacker-log
}

# Restrições de shell para agentes planner e coder
restrict_shell() {
    # Planner e coder não precisam de sudo
    rm -f /etc/sudoers.d/planner /etc/sudoers.d/coder 2>/dev/null || true
}

setup_cgroups
setup_audit
restrict_shell

echo "[HARDENING] Configurações de segurança aplicadas"
