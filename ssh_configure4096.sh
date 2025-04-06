#!/bin/bash 
 
# 颜色定义 
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color 
 
# 根据系统类型设置SSH服务名称 
if [[ -f /etc/debian_version ]]; then 
    SSH_SERVICE="ssh"
    PKG_MANAGER="apt-get"
elif [[ -f /etc/redhat-release ]]; then 
    SSH_SERVICE="sshd"
    PKG_MANAGER="yum"
else 
    echo "不支持的系统，无法安装 SSH。"
    exit 1 
fi 
 
# 安装SSH服务 
install_ssh() {
    # 检查SSH客户端是否安装 
    if command -v ssh >/dev/null 2>&1; then 
        echo "SSH 客户端已安装"
        # 检查SSH服务端是否已安装 
        if ! systemctl list-units --full --all | grep -Fq "${SSH_SERVICE}.service"; then 
            echo "SSH 服务端未安装，正在安装..."
            if [[ "$PKG_MANAGER" == "apt-get" ]]; then 
                sudo $PKG_MANAGER update 
                sudo $PKG_MANAGER install -y openssh-server 
            elif [[ "$PKG_MANAGER" == "yum" ]]; then 
                sudo $PKG_MANAGER install -y openssh-server 
            fi 
        fi 
    else 
        echo "SSH 客户端未安装，正在安装..."
        if [[ "$PKG_MANAGER" == "apt-get" ]]; then 
            sudo $PKG_MANAGER update 
            sudo $PKG_MANAGER install -y openssh-client openssh-server 
        elif [[ "$PKG_MANAGER" == "yum" ]]; then 
            sudo $PKG_MANAGER install -y openssh-clients openssh-server 
        fi 
    fi 
 
    # 检查SSH服务是否启用 
    if systemctl is-active --quiet $SSH_SERVICE; then 
        echo "SSH 服务已启用"
    else 
        echo "SSH 服务未启用，现在启用..."
        sudo systemctl start $SSH_SERVICE 
        if systemctl is-active --quiet $SSH_SERVICE; then 
            echo "SSH 服务启用成功"
            sudo systemctl enable $SSH_SERVICE 
        else 
            echo "SSH 服务启用失败，可能原因："
            systemctl status $SSH_SERVICE | grep -i "failed"
            exit 1 
        fi 
    fi 
}
 
# 管理SSH密钥 
manage_ssh_keys() {
    # 检查并处理SSH密钥对 
    if [ -f ~/.ssh/id_rsa ]; then 
        echo -e "\n${YELLOW}检测到已存在的SSH密钥对。${NC}"
        
        # 显示现有密钥信息 
        echo -e "\n当前密钥信息："
        if grep -q "BEGIN RSA PRIVATE KEY" ~/.ssh/id_rsa; then 
            key_length=$(openssl rsa -in ~/.ssh/id_rsa -text -noout | grep "Private-Key" | awk '{print $2}')
            fingerprint=$(ssh-keygen -lf ~/.ssh/id_rsa | awk '{print $2}')
            echo -e "密钥长度: ${key_length}位\n指纹: ${fingerprint}"
        fi 
        
        # 询问是否重新生成 
        while true; do 
            read -p "$(echo -e '是否要重新生成4096位密钥对？(原有密钥将被覆盖) [y/n]: ')" regen_choice 
            case $regen_choice in 
                [Yy]* )
                    # 备份旧密钥（时间戳格式）
                    timestamp=$(date +%Y%m%d%H%M%S)
                    mkdir -p ~/.ssh/backup 
                    mv ~/.ssh/id_rsa ~/.ssh/backup/id_rsa.bak.$timestamp  
                    mv ~/.ssh/id_rsa.pub  ~/.ssh/backup/id_rsa.pub.bak.$timestamp  
                    mv ~/.ssh/authorized_keys ~/.ssh/backup/authorized_keys.bak.$timestamp  2>/dev/null 
                    echo -e "\n${GREEN}原有密钥已备份到 ~/.ssh/backup 目录${NC}"
                    
                    # 生成新密钥 
                    echo "正在生成新的4096位SSH密钥对..."
                    ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa <<< $'\n' >/dev/null 2>&1 
                    
                    # 更新授权密钥 
                    cat ~/.ssh/id_rsa.pub  >> ~/.ssh/authorized_keys 
                    chmod 600 ~/.ssh/authorized_keys 
                    echo -e "${GREEN}新的4096位密钥对已生成并配置完成。${NC}"
                    break;;
                [Nn]* )
                    echo "保留现有密钥对。"
                    break;;
                * ) echo "请输入 y 或 n";;
            esac 
        done 
    else 
        # 不存在密钥时直接生成 
        echo "正在生成4096位SSH密钥对..."
        ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa <<< $'\n' >/dev/null 2>&1 
        cat ~/.ssh/id_rsa.pub  >> ~/.ssh/authorized_keys 
        chmod 600 ~/.ssh/authorized_keys 
        echo -e "${GREEN}OpenSSH 4096位密钥对生成成功。${NC}"
    fi 
}
 
# 配置SSH服务 
configure_ssh() {
    # 配置公钥认证 
    mkdir -p ~/.ssh 
    chmod 700 ~/.ssh 
    cat ~/.ssh/id_rsa.pub  >> ~/.ssh/authorized_keys 
    chmod 600 ~/.ssh/authorized_keys 
 
    # 验证公钥是否添加成功 
    if grep -q "$(cat ~/.ssh/id_rsa.pub)"  ~/.ssh/authorized_keys; then 
        echo -e "${GREEN}公钥已成功添加到 authorized_keys 文件中。${NC}"
    else 
        echo -e "${RED}公钥添加失败，请检查文件权限。${NC}"
        exit 1 
    fi 
 
    # 修改SSH服务端配置 
    echo "正在修改SSH服务端配置..."
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 
    # 验证Root登录配置 
    if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then 
        echo -e "${GREEN}配置生效：PermitRootLogin yes 已启用${NC}"
    else 
        echo -e "${YELLOW}警告：PermitRootLogin 配置未生效，请手动检查 /etc/ssh/sshd_config${NC}"
    fi 
 
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config 
    # 验证公钥认证配置 
    if grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then 
        echo -e "${GREEN}配置生效：PubkeyAuthentication yes 已启用${NC}"
    else 
        echo -e "${YELLOW}警告：PubkeyAuthentication 配置未生效，请手动检查 /etc/ssh/sshd_config${NC}"
    fi 
 
    # 重启SSH服务生效 
    echo "正在重启SSH服务..."
    sudo systemctl restart $SSH_SERVICE 
    if systemctl is-active --quiet $SSH_SERVICE; then 
        echo -e "${GREEN}SSH 服务已成功重启并处于运行状态。${NC}"
    else 
        echo -e "${RED}SSH 服务重启失败，可能原因：${NC}"
        systemctl status $SSH_SERVICE | grep -i "failed"
        exit 1 
    fi 
}
 
# 显示密钥信息 
show_key_info() {
    echo -e "\n\n${YELLOW}=============================== 查看私钥文件内容 ===============================${NC}"
    if [ -f ~/.ssh/id_rsa ]; then 
        cat ~/.ssh/id_rsa 
    else 
        echo -e "${RED}警告：私钥文件 ~/.ssh/id_rsa 不存在！${NC}"
    fi 
 
    echo -e "\n${YELLOW}=============================== 查看公钥文件内容 ===============================${NC}"
    if [ -f ~/.ssh/id_rsa.pub  ]; then 
        cat ~/.ssh/id_rsa.pub  
    else 
        echo -e "${RED}警告：公钥文件 ~/.ssh/id_rsa.pub  不存在！${NC}"
    fi 
 
    echo -e "\n${YELLOW}=============================== 查看是否追加成功 ===============================${NC}"
    if [ -f ~/.ssh/authorized_keys ]; then 
        echo "authorized_keys 文件内容（最后5行）："
        tail -n 5 ~/.ssh/authorized_keys 
        echo -e "\n完整验证："
        grep -F "$(cat ~/.ssh/id_rsa.pub)"  ~/.ssh/authorized_keys && echo -e "${GREEN}>>> 公钥已存在${NC}" || echo -e "${RED}>>> 公钥未找到${NC}"
    else 
        echo -e "${RED}警告：authorized_keys 文件不存在！${NC}"
    fi 
 
    echo -e "\n${GREEN}SSH配置已完成！建议执行以下命令验证连接：${NC}"
    echo "ssh -o PubkeyAuthentication=yes -o PasswordAuthentication=no localhost"
}
 
# 密钥安全提示 
key_security_warning() {
    echo -e "\n\n${RED}=============================== 重要安全提示 ===============================${NC}"
    echo -e "${RED}请立即将上面的私钥内容(~/.ssh/id_rsa)保存到安全的地方！${NC}"
    echo -e "这是您访问服务器的唯一凭证，一旦丢失将无法恢复！"
    echo -e "建议："
    echo -e "1. 复制上面的私钥内容"
    echo -e "2. 保存到本地安全的密码管理器中"
    echo -e "3. 或者下载私钥文件到安全位置"
 
    # 询问是否删除服务器上的私钥 
    while true; do 
        echo -e "\n是否要从服务器删除私钥文件？(强烈建议在保存后删除)"
        read -p "请输入 [y/n] (默认n): " choice 
        choice=${choice:-n}  # 默认值为n 
        
        case $choice in 
            [Yy]* )
                if [ -f ~/.ssh/id_rsa ]; then 
                    # 再次确认 
                    read -p "您确定已经保存了私钥吗？删除后将无法恢复！(y/n) " confirm 
                    if [[ $confirm =~ ^[Yy]$ ]]; then 
                        rm -f ~/.ssh/id_rsa 
                        rm -f ~/.ssh/id_rsa.pub  
                        echo -e "${GREEN}私钥文件已从服务器删除。${NC}"
                        echo -e "${RED}请确保您已经保存了私钥内容！${NC}"
                    else 
                        echo "取消删除操作。"
                    fi 
                else 
                    echo "没有找到私钥文件，无需删除。"
                fi 
                break;;
            [Nn]* )
                echo -e "${YELLOW}保留私钥文件在服务器上。${NC}"
                echo -e "${RED}警告：私钥保留在服务器上存在安全风险！${NC}"
                break;;
            * ) echo "请输入 y 或 n";;
        esac 
    done 
 
    echo -e "\n${GREEN}配置完成！请妥善保管您的私钥。${NC}"
}
 
# 主执行流程 
main() {
    install_ssh 
    manage_ssh_keys 
    configure_ssh 
    show_key_info 
    key_security_warning 
}
 
main 