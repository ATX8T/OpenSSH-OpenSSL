#!/bin/bash

# 安装检查模块
check_openssl_installation() {
if ! command -v openssl &> /dev/null; then
echo "检测到OpenSSL未安装，正在安装..."
sudo apt-get update -qq
sudo apt-get install -y openssl > /dev/null 2>&1
fi
}

# 通用名称验证模块
get_common_name() {
while true; do
read -p "请输入域名或服务器IP地址（通用名称）: " common_name
if [[ -z "$common_name" ]]; then
echo "错误：通用名称不能为空！"
else
break
fi
done
}

# 有效期选择模块
select_validity() {
echo -e "\n请选择证书有效期："
local options=("1年" "2年" "3年" "4年" "5年" "6年")
for i in "${!options[@]}"; do
printf "%d) %s\n" $((i+1)) "${options[$i]}"
done
read -p "请输入选项 (1-6): " choice

case $choice in
2) days=730 ;;
3) days=1095 ;;
4) days=1460 ;;
5) days=1825 ;;
6) days=2190 ;;
*) days=365 ;; # 默认1年
esac
}

# 证书生成模块
generate_certificate() {
echo -e "\n正在生成证书..."
openssl req -x509 \
-newkey rsa:2048 \
-nodes \
-keyout "$cert_dir/server.key" \
-out "$cert_dir/server.crt" \
-subj "/C=CN/ST=Beijing/L=Beijing/O=MyOrganization/OU=IT/CN=$common_name" \
-days "$days" \
-utf8 > /dev/null 2>&1

# 生成独立公钥文件
openssl rsa -in "$cert_dir/server.key" -pubout -out "$cert_dir/server.pub" 2>/dev/null

# 权限安全设置
chmod 600 "$cert_dir/server.key"
chmod 644 "$cert_dir/server.pub"
chmod 644 "$cert_dir/server.crt"
}

# 验证模块
verify_certificate() {
echo -e "\n\e[1;34m=== 证书验证报告 ===\e[0m"

# 文件路径输出
echo -e "\n\e[36m[文件路径]\e[0m"
echo "私钥文件：$(realpath "$cert_dir/server.key")"
echo "证书文件：$(realpath "$cert_dir/server.crt")"
echo "公钥文件：$(realpath "$cert_dir/server.pub")"

# 结构验证
echo -e "\n\e[36m[结构验证]\e[0m"
openssl rsa -in "$cert_dir/server.key" -check -noout 2>/dev/null &&
echo -e "\e[32m✓ 私钥结构有效\e[0m" || echo -e "\e[31m✗ 私钥损坏\e[0m"

openssl x509 -in "$cert_dir/server.crt" -noout 2>/dev/null &&
echo -e "\e[32m✓ 证书结构有效\e[0m" || echo -e "\e[31m✗ 证书损坏\e[0m"

openssl rsa -pubin -in "$cert_dir/server.pub" -noout 2>/dev/null &&
echo -e "\e[32m✓ 公钥结构有效\e[0m" || echo -e "\e[31m✗ 公钥损坏\e[0m"

# 密钥匹配验证
echo -e "\n\e[36m[密钥匹配]\e[0m"
key_mod=$(openssl rsa -modulus -noout -in "$cert_dir/server.key" 2>/dev/null | openssl sha256)
cert_mod=$(openssl x509 -modulus -noout -in "$cert_dir/server.crt" 2>/dev/null | openssl sha256)

if [ "$key_mod" == "$cert_mod" ]; then
echo -e "\e[32m✓ 私钥与证书匹配\e[0m"
else
echo -e "\e[31m✗ 密钥不匹配！差异值：${key_mod:0:16} vs ${cert_mod:0:16}\e[0m"
fi

# 证书有效性深度验证
echo -e "\n\e[36m[深度验证]\e[0m"
if openssl verify -CAfile "$cert_dir/server.crt" "$cert_dir/server.crt" &>/dev/null; then
echo -e "\e[32m✓ 证书链验证通过（自签名）\e[0m"
else
echo -e "\e[31m✗ 证书链验证失败\e[0m"
fi

# 交互式SSL测试
ssl_handshake_test() {
read -p "是否需要进行SSL握手模拟测试？(y/N): " test_choice
if [[ ! "$test_choice" =~ [yY] ]]; then
return
fi

# 端口选择逻辑
local port=1503
echo -e "\n\e[36m[端口设置]\e[0m"
echo "1) 使用默认端口1503"
echo "2) 手动指定端口"
while true; do
read -p "请选择端口设置 (1-2): " port_choice
case $port_choice in
1)
echo -e "使用\e[33m默认端口1503\e[0m"
break
;;
2)
while true; do
read -p "请输入端口号 (1-65535): " port
if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
break
else
echo -e "\e[31m错误：端口号必须为1-65535的数字\e[0m"
fi
done
break
;;
*)
echo -e "\e[31m无效选项，请重新输入\e[0m"
;;
esac
done

# 执行测试
echo -e "\n\e[36m[握手测试]\e[0m"
openssl s_server -cert "$cert_dir/server.crt" -key "$cert_dir/server.key" \
-quiet -accept $port &>/dev/null &
local server_pid=$!

# 确保服务器启动
sleep 1

if openssl s_client -connect localhost:$port -no_ign_eof 2>/dev/null | grep -q "Verify return code"; then
echo -e "\e[32m✓ SSL握手测试成功\e[0m"
else
echo -e "\e[31m✗ SSL握手测试失败\e[0m"
fi

# 清理进程
kill -9 $server_pid 2>/dev/null
}

ssl_handshake_test

# 有效期验证
echo -e "\n\e[36m[有效期信息]\e[0m"
openssl x509 -in "$cert_dir/server.crt" -noout -dates |
awk -F= '{printf "%-11s: %s\n", $1, $2}' |
sed 's/GMT//;s/^/ /'
}

# 目录冲突处理模块
handle_directory_conflict() {
local conflict_dir="$1"
local subdir="OpenSSLkeymiyao"

echo -e "\n\e[33m目录 [$conflict_dir] 已存在证书文件！\e[0m"
echo "请选择处理方式："
echo "1) 覆盖现有文件（危险操作）"
echo "2) 创建子目录保存 [$subdir]"

while true; do
read -p "请输入选项 (1-2): " choice
case $choice in
1)
echo -e "\e[31m警告：将覆盖以下文件！\e[0m"
ls -lh "$conflict_dir"/server.* 2>/dev/null
read -p "确认覆盖操作？(y/N): " confirm
if [[ "$confirm" =~ [yY] ]]; then
rm -f "$conflict_dir"/server.{key,crt,pub}
cert_dir="$conflict_dir"
break
else
echo "操作已取消"
exit 1
fi
;;
2)
cert_dir="$conflict_dir/$subdir"
mkdir -p "$cert_dir"
echo -e "\e[32m新证书将保存至：$cert_dir\e[0m"
break
;;
*)
echo "无效选项，请重新输入"
;;
esac
done
}

# 路径设置模块
setup_directory() {
read -p "请输入证书保存目录（默认：~/OpenSSLKey）: " cert_dir
cert_dir=${cert_dir:-"$HOME/OpenSSLKey"}
cert_dir=$(realpath -m "$cert_dir")

# 检查目录冲突
if [ -f "$cert_dir/server.key" ] || [ -f "$cert_dir/server.crt" ]; then
handle_directory_conflict "$cert_dir"
else
mkdir -p "$cert_dir"
echo -e "\e[32m证书保存路径：$cert_dir\e[0m"
fi
}

# 主程序流程
main() {
check_openssl_installation
setup_directory
get_common_name
select_validity
generate_certificate
verify_certificate

# 最终输出
echo -e "\n\e[1;35m=== 生成结果汇总 ===\e[0m"
echo -e "私钥路径：\e[33m$(realpath "$cert_dir/server.key")\e[0m"
echo -e "证书路径：\e[33m$(realpath "$cert_dir/server.crt")\e[0m"
echo -e "公钥路径：\e[33m$(realpath "$cert_dir/server.pub")\e[0m"

# 可用性验证总结
echo -e "\n\e[1;32m证书状态验证：\e[0m"
if openssl x509 -checkend 3600 -noout -in "$cert_dir/server.crt"; then
echo -e "\e[32m✓ 证书已生效且未过期\e[0m"
else
echo -e "\e[31m✗ 证书未生效或已过期\e[0m"
fi
}

# 执行主程序
main