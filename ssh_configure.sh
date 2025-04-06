#!/bin/bash

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

# 生成SSH密钥对（如果不存在）
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "正在生成SSH密钥对..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< $'\n' >/dev/null 2>&1
    if [ -f ~/.ssh/id_rsa ]; then
        echo "OpenSSH 密钥对生成成功。"
    else
        echo "密钥对生成失败，请手动检查权限。"
        exit 1
    fi
else
    echo "SSH密钥对已存在，跳过生成步骤。"
fi

# 配置公钥认证
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 验证公钥是否添加成功
if grep -q "$(cat ~/.ssh/id_rsa.pub)" ~/.ssh/authorized_keys; then
    echo "公钥已成功添加到 authorized_keys 文件中。"
else
    echo "公钥添加失败，请检查文件权限。"
    exit 1
fi



# 修改SSH服务端配置
echo "正在修改SSH服务端配置..."
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# 验证Root登录配置
if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
    echo "配置生效：PermitRootLogin yes 已启用"
else
    echo "警告：PermitRootLogin 配置未生效，请手动检查 /etc/ssh/sshd_config"
fi

sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
# 验证公钥认证配置
if grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config; then
    echo "配置生效：PubkeyAuthentication yes 已启用"
else
    echo "警告：PubkeyAuthentication 配置未生效，请手动检查 /etc/ssh/sshd_config"
fi






# 重启SSH服务生效
echo "正在重启SSH服务..."
sudo systemctl restart $SSH_SERVICE
if systemctl is-active --quiet $SSH_SERVICE; then
    echo "SSH 服务已成功重启并处于运行状态。"
else
    echo "SSH 服务重启失败，可能原因："
    systemctl status $SSH_SERVICE | grep -i "failed"
    exit 1
fi

# 添加最终的密钥文件内容输出
echo -e "\n\n=============================== 查看私钥文件内容 ==============================="
if [ -f ~/.ssh/id_rsa ]; then
    cat ~/.ssh/id_rsa
else
    echo "警告：私钥文件 ~/.ssh/id_rsa 不存在！"
fi

echo -e "\n=============================== 查看公钥文件内容 ==============================="
if [ -f ~/.ssh/id_rsa.pub ]; then
    cat ~/.ssh/id_rsa.pub
else
    echo "警告：公钥文件 ~/.ssh/id_rsa.pub 不存在！"
fi

echo -e "\n=============================== 查看是否追加成功 ==============================="
if [ -f ~/.ssh/authorized_keys ]; then
    echo "authorized_keys 文件内容（最后5行）："
    tail -n 5 ~/.ssh/authorized_keys
    echo -e "\n完整验证："
    grep -F "$(cat ~/.ssh/id_rsa.pub)" ~/.ssh/authorized_keys && echo ">>> 公钥已存在" || echo ">>> 公钥未找到"
else
    echo "警告：authorized_keys 文件不存在！"
fi

echo -e "\nSSH配置已完成！建议执行以下命令验证连接："
echo "ssh -o PubkeyAuthentication=yes -o PasswordAuthentication=no localhost"
