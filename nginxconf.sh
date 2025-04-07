#!/bin/bash

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "请以 root 用户运行此脚本。"
    exit 1
fi

# 定义 Nginx 配置文件路径
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
CONF_FILE="$NGINX_CONF_DIR/nginx_ssl.conf"

# 安装 Nginx
echo "正在安装 Nginx..."
if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y nginx
elif command -v yum &> /dev/null; then
    yum install -y nginx
else
    echo "不支持的包管理器，请手动安装 Nginx。"
    exit 1
fi

# 生成 Nginx 配置文件
echo "正在生成 Nginx 配置文件..."
cat << EOF > "$CONF_FILE"
server {
    # 监听 443 端口，使用 HTTPS 协议
    listen 443 ssl;
    # 这里替换为你实际要使用的域名或 IP 地址
    server_name example.com; 

    # SSL 证书和私钥的路径，根据实际情况修改
    ssl_certificate /opt/SSL/ServerCertificate.crt;
    ssl_certificate_key /opt/SSL/ServerPrivateKey.key;

    # SSL 协议和加密套件配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 开启 SSL 会话缓存
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # # 根目录设置，根据实际情况修改
    # root /var/www/html;
    # index index.html index.htm;
    # 
    # location / {
    #     try_files $uri $uri/ /index.html;
    # }
    # 
    # # 错误页面配置
    # error_page 500 502 503 504 /50x.html;
    # location = /50x.html {
    #     root /var/www/html;
    # }
}

# 重定向 HTTP 请求到 HTTPS
server {
    listen 80;
    server_name example.com;
    return 301 https://\$server_name\$request_uri;
}
EOF

# 创建软链接到 sites-enabled 目录
ln -s "$CONF_FILE" "$NGINX_ENABLED_DIR/"

# 检查 Nginx 配置是否正确
echo "正在检查 Nginx 配置..."
if nginx -t; then
    # 重新加载 Nginx 服务
    echo "Nginx 配置检查通过，正在重新加载 Nginx 服务..."
    systemctl reload nginx
    echo "Nginx 服务已重新加载。"
else
    echo "Nginx 配置检查失败，请检查配置文件。"
    exit 1
fi

echo "Nginx 安装并配置完成。"
    