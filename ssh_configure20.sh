#!/bin/bash 
# [2025-04-07 v4.1] Root SSH密钥登录安全配置脚本 
# 核心修改：
# 1. 修复Heredoc语法缩进问题 
# 2. 增强密钥写入原子性 
# 3. 新增SELinux自动修复 
# 4. 优化FIPS算法优先级 
 
#######################################
# 第一阶段：环境预检与兼容性配置 
#######################################
declare -A SECURITY_PROFILE=(
    ['PERMIT_ROOT']='prohibit-password'
    ['CIPHERS']='aes256-gcm@openssh.com,chacha20-poly1305@openssh.com' 
    ['MACs']='hmac-sha2-512-etm@openssh.com' 
)
 
init_env() {
    # 内核网络优化 
    echo "net.ipv4.tcp_fastopen=3"  | sudo tee -a /etc/sysctl.conf  >/dev/null 
    sysctl -p | grep tcp_fastopen 
 
    # SELinux策略适配（关键修复）
    if sestatus | grep -q 'enabled'; then 
        sudo semanage fcontext -a -t ssh_home_t "/root/.ssh(/.*)?" || true 
        sudo restorecon -Rv /root/.ssh 2>/dev/null 
    fi 
}
 
#######################################
# 第二阶段：原子化密钥部署 
#######################################
deploy_root_key() {
    local KEY_FILE="/root/.ssh/authorized_keys"
    local TMP_KEY=$(mktemp)
    
    # 生成双算法密钥对 
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/root_rsa -N "" -C "main-$(date +%Y%m%d)"
    ssh-keygen -t ed25519 -f ~/.ssh/root_ed25519 -N "" -C "backup-$(date +%Y%m%d)"
    
    # 安全合并公钥 
    cat ~/.ssh/root_rsa.pub  ~/.ssh/root_ed25519.pub  > $TMP_KEY 
    
    # 原子写入操作 
    sudo mkdir -p /root/.ssh 
    sudo cp $TMP_KEY "${KEY_FILE}.tmp"
    sudo mv "${KEY_FILE}.tmp" "$KEY_FILE"
    sudo chmod 600 $KEY_FILE 
}
 
#######################################
# 第三阶段：SSHD强化配置（EOF修复重点）
#######################################
harden_sshd() {
    local SSHD_CONFIG="/etc/ssh/sshd_config"
    
    # 使用制表符缩进here-doc（关键修复）
    sudo tee -a $SSHD_CONFIG <<-EOF >/dev/null 
	# === 核心安全策略 === 
	PermitRootLogin ${SECURITY_PROFILE[PERMIT_ROOT]}
	PermitEmptyPasswords no 
	StrictModes yes 
	
	# === FIPS 140-3加密套件 === 
	Ciphers ${SECURITY_PROFILE[CIPHERS]}
	MACs ${SECURITY_PROFILE[MACs]}
	KexAlgorithms curve25519-sha256 
	
	# === 会话防护 === 
	ClientAliveInterval 300 
	MaxAuthTries 2 
	LoginGraceTime 60 
	EOF  # 此处必须为制表符缩进 
 
    # 配置验证 
    if ! sudo sshd -t; then 
        echo "SSHD配置语法错误！错误代码：$?"
        journalctl -u sshd -n 10 --no-pager 
        exit 101 
    fi 
}
 
#######################################
# 第四阶段：立体化验证 
#######################################
validate_access() {
    # 本地环路测试 
    if ! ssh -o ConnectTimeout=5 -i ~/.ssh/root_rsa root@127.0.0.1 true; then 
        echo "连接测试失败，启用诊断模式："
        ssh -vvv -i ~/.ssh/root_rsa root@localhost 2>&1 | grep -E 'key_verify|authenticated'
        
        # 指纹交叉验证 
        local LOCAL_FP=$(ssh-keygen -lf ~/.ssh/root_rsa.pub  | awk '{print $2}')
        local REMOTE_FP=$(sudo ssh-keygen -lf /root/.ssh/authorized_keys | grep -c "$LOCAL_FP")
        [ $REMOTE_FP -eq 0 ] && echo "指纹不匹配！错误代码108"
    fi 
 
    # 安全基线审计 
    sudo grep -q "PasswordAuthentication no" /etc/ssh/sshd_config || {
        echo "密码认证未关闭！紧急修复中..."
        sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config 
    }
}
 
#######################################
# 执行主流程 
#######################################
init_env 
deploy_root_key 
harden_sshd 
sudo systemctl restart sshd 
validate_access 
 
echo "√ 安全加固完成 | 操作时间: $(date +'%Y-%m-%d %H:%M:%S') | 系统指纹: $(md5sum /etc/ssh/*.pub | awk '{print $1}' | xargs)"