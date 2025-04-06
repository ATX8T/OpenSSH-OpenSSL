#!/bin/bash 
 
# ...（保持原有安装和输入部分不变）...
 
# 设置保存目录（添加路径标准化处理）
read -p "请输入证书保存目录（默认：~/OpenSSLKey）: " cert_dir 
cert_dir=${cert_dir:-"$HOME/OpenSSLKey"}
cert_dir=$(realpath -m "$cert_dir")  # 转换为绝对路径 
mkdir -p "$cert_dir"
 
# ...（保持原有通用名称和有效期处理部分不变）...
 
# 生成私钥和证书后添加以下内容 
 
# 验证文件生成及路径输出 
echo -e "\n生成结果验证："
for file in "server.key"  "server.crt";  do 
    full_path="$cert_dir/$file"
    if [ -f "$full_path" ]; then 
        echo "[√] $file 生成成功"
        echo "完整路径：$full_path"
    else 
        echo "[×] $file 生成失败"
    fi 
done 
 
# 证书有效性验证模块 
echo -e "\n证书有效性验证："
verify_cert() {
    # 私钥有效性检查 
    if openssl rsa -in "$cert_dir/server.key"  -check -noout >/dev/null 2>&1; then 
        echo "[√] 私钥结构验证通过"
    else 
        echo "[×] 私钥文件损坏或格式错误"
    fi 
 
    # 证书有效性检查 
    if openssl x509 -in "$cert_dir/server.crt"  -noout >/dev/null 2>&1; then 
        echo "[√] 证书结构验证通过"
    else 
        echo "[×] 证书文件损坏或格式错误"
    fi 
 
    # 密钥匹配性检查 
    key_hash=$(openssl rsa -modulus -in "$cert_dir/server.key"  -noout 2>/dev/null | openssl sha256)
    cert_hash=$(openssl x509 -modulus -in "$cert_dir/server.crt"  -noout 2>/dev/null | openssl sha256)
    if [ "$key_hash" = "$cert_hash" ]; then 
        echo "[√] 密钥与证书匹配验证通过"
    else 
        echo "[×] 密钥与证书不匹配"
    fi 
}
 
# 执行验证 
verify_cert 
 
# ...（保持原有输出部分不变）...