#!/bin/bash

# 删除现有的SSH密钥文件
echo "正在删除现有SSH密钥..."
rm -f ~/.ssh/id_rsa ~/.ssh/id_rsa.pub

# 从authorized_keys中移除旧公钥（如果存在）
if [ -f ~/.ssh/authorized_keys ] && [ -f ~/.ssh/id_rsa.pub ]; then
    echo "正在从authorized_keys中移除旧公钥..."
    sed -i "\#$(cat ~/.ssh/id_rsa.pub | sed 's/\//\\\//g')#d" ~/.ssh/authorized_keys
fi

# 生成新的SSH密钥对
echo "正在生成新的SSH密钥对..."
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <<< $'\n' >/dev/null 2>&1

# 确保.ssh目录权限正确
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 将新公钥添加到authorized_keys
echo "添加新公钥到authorized_keys..."
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 验证新公钥是否添加成功
if grep -q "$(cat ~/.ssh/id_rsa.pub)" ~/.ssh/authorized_keys; then
    echo "新公钥已成功添加到authorized_keys"
else
    echo "错误：新公钥添加失败！"
    exit 1
fi

# 输出新密钥信息
echo -e "\n=============================== 新私钥内容 ==============================="
cat ~/.ssh/id_rsa

echo -e "\n=============================== 新公钥内容 ==============================="
cat ~/.ssh/id_rsa.pub

echo -e "\nSSH密钥已重置完成！建议使用以下命令测试连接："
echo "ssh -o PubkeyAuthentication=yes -o PasswordAuthentication=no localhost"