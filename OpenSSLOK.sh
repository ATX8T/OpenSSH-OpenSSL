#!/bin/bash

# 检查 /opt/SSL 目录下是否有已生成的证书文件
SSL_DIR="/opt/SSL"
CERT_FILES=(
    "$SSL_DIR/RootCaPrivateKey.key"
    "$SSL_DIR/RootCaCertificate.crt"
    "$SSL_DIR/RootCaCertificate.pem"
    "$SSL_DIR/ServerPrivateKey.key"
    "$SSL_DIR/ServerCsrConfig.cnf"
    "$SSL_DIR/ServerCsr.csr"
    "$SSL_DIR/ServerCertExtConfig.cnf"
    "$SSL_DIR/ServerCertificate.crt"
    "$SSL_DIR/ServerCertificate.pem"
)

EXISTING_FILES=()
for file in "${CERT_FILES[@]}"; do
    if [ -e "$file" ]; then
        EXISTING_FILES+=("$file")
    fi
done

if [ ${#EXISTING_FILES[@]} -gt 0 ]; then
    echo "以下文件已存在于 $SSL_DIR 目录下："
    for file in "${EXISTING_FILES[@]}"; do
        echo "$file"
    done
    read -p "请选择操作：(1) 退出脚本 (2) 清空 $SSL_DIR 目录并重新生成证书: " choice
    case $choice in
        1)
            echo "脚本退出。"
            exit 0
            ;;
        2)
            echo "正在清空 $SSL_DIR 目录..."
            rm -rf "$SSL_DIR"/*
            ;;
        *)
            echo "无效的选择，脚本退出。"
            exit 1
            ;;
    esac
fi

# 创建工作目录
mkdir -p "$SSL_DIR"
cd "$SSL_DIR"

# 提示用户输入域名或 IP 地址，以逗号分隔
read -p "请输入域名或 IP 地址（以逗号分隔，例如: example.com,www.example.com,192.168.1.1）: " DOMAINS

# 将输入的域名或 IP 地址分割成数组
IFS=',' read -ra DOMAIN_ARRAY <<< "$DOMAINS"

# 生成根证书私钥
openssl genrsa -out "RootCaPrivateKey.key" 2048

# 生成根证书
openssl req -x509 -new -nodes -key "RootCaPrivateKey.key" -sha256 -days 3650 -out "RootCaCertificate.crt" -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit"

# 复制根证书为 PEM 格式
cp "RootCaCertificate.crt" "RootCaCertificate.pem"

# 生成服务器私钥
openssl genrsa -out "ServerPrivateKey.key" 2048

# 创建证书签名请求（CSR）配置文件
cat > "ServerCsrConfig.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = US
ST = State
L = City
O = Organization
OU = Unit

[req_ext]
subjectAltName = @alt_names

[alt_names]
EOF

# 添加 SAN 条目
count=1
for domain in "${DOMAIN_ARRAY[@]}"; do
    if [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP.$count = $domain" >> "ServerCsrConfig.cnf"
    else
        echo "DNS.$count = $domain" >> "ServerCsrConfig.cnf"
    fi
    ((count++))
done

# 生成证书签名请求（CSR）
openssl req -new -key "ServerPrivateKey.key" -out "ServerCsr.csr" -config "ServerCsrConfig.cnf"

# 创建证书扩展配置文件
cat > "ServerCertExtConfig.cnf" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
EOF

# 添加 SAN 条目到证书扩展配置文件
count=1
for domain in "${DOMAIN_ARRAY[@]}"; do
    if [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP.$count = $domain" >> "ServerCertExtConfig.cnf"
    else
        echo "DNS.$count = $domain" >> "ServerCertExtConfig.cnf"
    fi
    ((count++))
done

# 使用根证书签署服务器证书
openssl x509 -req -in "ServerCsr.csr" -CA "RootCaCertificate.crt" -CAkey "RootCaPrivateKey.key" -CAcreateserial -out "ServerCertificate.crt" -days 3650 -sha256 -extfile "ServerCertExtConfig.cnf"

# 复制服务器证书为 PEM 格式
cp "ServerCertificate.crt" "ServerCertificate.pem"

# 验证证书
openssl verify -CAfile "RootCaCertificate.crt" "ServerCertificate.crt"

echo ""
echo ""
echo ""
echo ""

# 输出文件信息
echo "====================以下是生成的证书文件信息：==================="
echo ""
echo ""
echo "根证书私钥: $SSL_DIR/RootCaPrivateKey.key"
echo ""
echo "根证书 (CRT 格式): $SSL_DIR/RootCaCertificate.crt"
echo "根证书 (PEM 格式): $SSL_DIR/RootCaCertificate.pem"
echo ""
echo "服务器私钥: $SSL_DIR/ServerPrivateKey.key"
echo ""
echo "服务器证书签名请求配置文件: $SSL_DIR/ServerCsrConfig.cnf"
echo ""
echo "服务器证书签名请求: $SSL_DIR/ServerCsr.csr"
echo ""
echo "服务器证书扩展配置文件: $SSL_DIR/ServerCertExtConfig.cnf"
echo ""
echo "服务器证书 (CRT 格式): $SSL_DIR/ServerCertificate.crt"
echo "服务器证书 (PEM 格式): $SSL_DIR/ServerCertificate.pem"

# 再次输出用于生产测试的自签证书文件，标红显示
RED='\033[0;31m'
NC='\033[0m'
echo -e "\n${RED}用于生产测试的自签证书文件 (CRT 格式): $SSL_DIR/ServerCertificate.crt${NC}"
echo -e "${RED}用于生产测试的自签证书文件 (PEM 格式): $SSL_DIR/ServerCertificate.pem${NC}"
echo -e "${RED}用于生产测试的自签证书私钥: $SSL_DIR/ServerPrivateKey.key${NC}"

# 删除无用的文件
USELESS_FILES=(
    "ServerCsrConfig.cnf"
    "ServerCsr.csr"
    "ServerCertExtConfig.cnf"
)
for file in "${USELESS_FILES[@]}"; do
    if [ -e "$file" ]; then
        rm "$file"
        echo "已删除无用文件: $SSL_DIR/$file"
    fi
done

# 提示用户重要文件的保管方式
echo -e "\n重要文件保管提示："
echo -e "1. ${RED}根证书私钥 ($SSL_DIR/RootCaPrivateKey.key)${NC}：这是整个证书体系的核心安全要素，一旦泄露，攻击者可以签发任意有效证书，破坏信任体系。请将其备份到离线、安全的存储设备（如加密的外部硬盘或磁带库），并设置严格的访问控制，仅授权少数人员访问。"
echo -e "2. ${RED}服务器私钥 ($SSL_DIR/ServerPrivateKey.key)${NC}：用于对服务器数据进行签名和解密，若泄露，攻击者可伪装服务器窃取信息。请备份到安全存储设备，并确保生产环境中只有运行服务器进程的用户可以读取。"
echo -e "3. ${RED}根证书 ($SSL_DIR/RootCaCertificate.crt 和 $SSL_DIR/RootCaCertificate.pem)${NC}：是证书信任链的起点，客户端用其验证服务器证书合法性。请备份到安全位置，并在服务器上保留副本用于证书验证。"
echo -e "4. ${RED}服务器证书 ($SSL_DIR/ServerCertificate.crt 和 $SSL_DIR/ServerCertificate.pem)${NC}：用于向客户端证明服务器身份。请备份到安全位置，并在服务器上保留副本供配置使用。"
    