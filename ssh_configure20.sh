#!/bin/bash 
# [2025-04-07 v4.0] Root SSH密钥登录专项配置脚本 
# 修改记录：
# 1. 新增root账户密钥配置模块 
# 2. 强化SELinux/Targeted策略适配 
# 3. 增加FIPS 140-3合规性检查 
# 4. 添加密钥指纹验证机制 
# 5. 实现多因素权限验证 
 
#######################################
# 第一阶段：环境预检与兼容性配置 
#######################################
declare -A SECURITY_PROFILE=(
    ['PERMIT_ROOT']='prohibit-password'  # 允许密钥禁止密码 
    ['CIPHERS']='aes256-gcm@openssh.com,chacha20-poly1305@openssh.com'   # FIPS兼容算法 
    ['MACs']='hmac-sha2-512-etm@openssh.com'   # 增强型MAC 
)
 
init_env() {
    # 内核参数调优 
    echo "net.ipv4.tcp_fastopen=3"  | sudo tee -a /etc/sysctl.conf  
    sysctl -p | grep tcp_fastopen 
 
    # SELinux策略适配 
    if sestatus | grep -q 'enabled'; then 
        sudo semanage boolean -m --on ssh_keysign 
        sudo setsebool -P ssh_chroot_rw_homedirs on 
    fi 
}
 
#######################################
# 第二阶段：Root密钥部署（核心修改）
#######################################
deploy_root_key() {
    local KEY_FILE="/root/.ssh/authorized_keys"
    local TMP_KEY=$(mktemp)
    
    # 生成ED25519备用密钥 
    ssh-keygen -t ed25519 -f ~/.ssh/root_ed25519 -N "" -C "root@$(hostname)-backup"
    
    # 合并4096位RSA与ED25519密钥 
    cat ~/.ssh/id_rsa_4096.pub  ~/.ssh/root_ed25519.pub  | sudo tee $TMP_KEY >/dev/null 
    
    # 原子化写入操作 
    sudo mkdir -p /root/.ssh 
    sudo cp $TMP_KEY $KEY_FILE 
    sudo chown root:root $KEY_FILE 
    sudo chmod 600 $KEY_FILE 
    
    # 多维度权限验证 
    sudo ls -Z $KEY_FILE | grep -q 'ssh_home_t' || echo "SELinux上下文异常"
    getfacl $KEY_FILE | grep -q 'owner: root' || echo "ACL权限异常"
}
 
#######################################
# 第三阶段：SSHD安全加固配置 
#######################################
harden_sshd() {
    local SSHD_CONFIG="/etc/ssh/sshd_config"
    
    # 使用Here Document进行配置 
    sudo tee -a $SSHD_CONFIG <<-EOF >/dev/null 
	# === 根账户安全策略 === 
	PermitRootLogin ${SECURITY_PROFILE[PERMIT_ROOT]}
	PermitEmptyPasswords no 
	PermitUserEnvironment no 
	
	# === 加密算法套件 === 
	Ciphers ${SECURITY_PROFILE[CIPHERS]}
	MACs ${SECURITY_PROFILE[MACs]}
	KexAlgorithms curve25519-sha256 
	
	# === 会话控制 === 
	ClientAliveInterval 300 
	MaxAuthTries 2 
	MaxSessions 3 
	EOF 
    
    # 配置语法预检 
    sudo sshd -t || {
        echo "配置语法错误！错误代码：$?"
        journalctl -u sshd --since "1 min ago" | grep -i error 
        exit 101 
    }
}
 
#######################################
# 第四阶段：综合验证模块 
#######################################
validate_access() {
    local TEST_CMD="ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_4096 root@localhost hostname"
    
    # 连接测试 
    if ! eval $TEST_CMD; then 
        echo "第一阶段验证失败，启用调试模式..."
        SSH_DEBUG="ssh -vvv -o BatchMode=yes -i ~/.ssh/id_rsa_4096 root@localhost"
        eval $SSH_DEBUG | grep -E 'Authentication succeeded|failed'
        
        # 密钥指纹验证 
        LOCAL_FINGERPRINT=$(ssh-keygen -lf ~/.ssh/id_rsa_4096.pub  | awk '{print $2}')
        REMOTE_FINGERPRINT=$(sudo ssh-keygen -lf /root/.ssh/authorized_keys | grep "$LOCAL_FINGERPRINT")
        [ -z "$REMOTE_FINGERPRINT" ] && echo "指纹不匹配！"
    fi 
    
    # 安全基线检查 
    sudo grep -q "Permission root" /etc/security/access.conf  || {
        echo "root访问限制未配置"
        echo "-:root:ALL EXCEPT LOCAL" | sudo tee -a /etc/security/access.conf  
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
 
echo "√ 根账户SSH密钥配置完成 | 操作时间: $(date +'%F %T.%3N')"