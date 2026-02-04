#!/bin/bash
# Security hardening completo para OpenClaw Multi-Agent
# Aplica: cgroups, limits, audit, capabilities

set -euo pipefail

WORKSPACE="/workspace"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[HARDENING]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[HARDENING]${NC} $1"; }
log_error() { echo -e "${RED}[HARDENING]${NC} $1"; }

# Cgroups v2 para limitação de recursos
setup_cgroups() {
    log_info "Configurando cgroups..."
    
    if [[ -d /sys/fs/cgroup ]]; then
        # Hacker: limites mais restritivos
        mkdir -p /sys/fs/cgroup/hacker 2>/dev/null || true
        echo "50000" > /sys/fs/cgroup/hacker/cpu.max 2>/dev/null || true  # 50% CPU
        echo "8G" > /sys/fs/cgroup/hacker/memory.max 2>/dev/null || true  # 8GB RAM
        echo "1G" > /sys/fs/cgroup/hacker/memory.swap.max 2>/dev/null || true
        
        # Planner e Coder: limites moderados
        for agent in planner coder; do
            mkdir -p "/sys/fs/cgroup/${agent}" 2>/dev/null || true
            echo "40000" > "/sys/fs/cgroup/${agent}/cpu.max" 2>/dev/null || true  # 40% CPU
            echo "4G" > "/sys/fs/cgroup/${agent}/memory.max" 2>/dev/null || true   # 4GB RAM
            echo "512M" > "/sys/fs/cgroup/${agent}/memory.swap.max" 2>/dev/null || true
        done
        
        log_info "Cgroups configurados"
    else
        log_warn "Cgroups não disponível"
    fi
}

# Audit logging completo
setup_audit() {
    log_info "Configurando audit logging..."
    
    mkdir -p /workspace/audit
    
    # Sudo audit para hacker
    cat > /etc/sudoers.d/hacker-audit << 'EOF'
Defaults logfile="/workspace/audit/hacker-sudo.log"
Defaults log_input, log_output
Defaults iolog_dir="/workspace/audit/sudo-io"
EOF
    
    mkdir -p /workspace/audit/sudo-io
    chmod 700 /workspace/audit/sudo-io
    
    # Log de comandos shell
    cat > /etc/profile.d/audit.sh << 'EOF'
# Audit logging para todos os usuários
export PROMPT_COMMAND='RETRN_VAL=$?;logger -p local6.debug "$(whoami) [$$]: $(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//" ) [$RETRN_VAL]"'
EOF
    
    log_info "Audit logging configurado"
}

# Security limits (ulimit)
setup_limits() {
    log_info "Configurando security limits..."
    
    cat > /etc/security/limits.d/openclaw.conf << EOF
# Limites para agentes OpenClaw
@planner soft nproc 100
@planner hard nproc 200
@planner soft nofile 4096
@planner hard nofile 8192

@coder soft nproc 100
@coder hard nproc 200
@coder soft nofile 4096
@coder hard nofile 8192

@hacker soft nproc 50
@hacker hard nproc 100
@hacker soft nofile 2048
@hacker hard nofile 4096
EOF
    
    log_info "Security limits configurados"
}

# Remover shells desnecessários
restrict_shells() {
    log_info "Restringindo shells..."
    
    # Planner e coder não precisam de shell interativo
    usermod -s /usr/sbin/nologin planner 2>/dev/null || true
    usermod -s /usr/sbin/nologin coder 2>/dev/null || true
    
    log_info "Shells restritos"
}

# Kernel hardening
setup_kernel_hardening() {
    log_info "Aplicando kernel hardening..."
    
    # Sysctl settings para containers
    cat > /etc/sysctl.d/99-openclaw.conf << EOF
# Kernel hardening
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1

# Network hardening
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.tcp_syncookies=1

# Memory
vm.swappiness=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
EOF
    
    # Aplicar settings (pode falhar em container, ignorar erro)
    sysctl --system 2>/dev/null || log_warn "Não foi possível aplicar sysctl (container)"
    
    log_info "Kernel hardening aplicado"
}

# Remover ferramentas perigosas do hacker (whitelist approach)
restrict_hacker_tools() {
    log_info "Restringindo ferramentas do hacker..."
    
    # Criar wrapper para sudo que apenas permite ferramentas específicas
    cat > /usr/local/bin/sudo-restricted << 'EOF'
#!/bin/bash
# Sudo restrito para agente hacker
ALLOWED_CMDS=("nmap" "nikto" "masscan" "ping" "traceroute" "dig")

for allowed in "${ALLOWED_CMDS[@]}"; do
    if [[ "$*" == *"$allowed"* ]]; then
        exec /usr/bin/sudo "$@"
    fi
done

echo "Comando não permitido. Ferramentas permitidas: ${ALLOWED_CMDS[*]}"
exit 1
EOF
    
    chmod 755 /usr/local/bin/sudo-restricted
    
    log_info "Ferramentas do hacker restritas"
}

# Main
main() {
    log_info "Iniciando security hardening..."
    
    setup_cgroups
    setup_audit
    setup_limits
    restrict_shells
    setup_kernel_hardening
    restrict_hacker_tools
    
    log_info "Security hardening completo!"
}

main "$@"
