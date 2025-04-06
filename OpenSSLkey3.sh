#!/bin/bash 
 
# 安装检查模块 
check_openssl_installation() {
    if ! command -v openssl &> /dev/null; then 
        echo "检测到OpenSSL未安装，正在安装..."
        sudo apt-get update -qq 
        sudo apt-get install -y openssl > /dev/null 2>&1 || {
            echo -e "\e[31mOpenSSL安装失败，请检查网络连接\e[0m"
            exit 1 
        }
    fi 
}
 
# 通用名称验证模块 
get_common_name() {
    while true; do 
        read -p "请输入域名或服务器IP地址（通用名称）: " common_name 
        if [[ -z "$common_name" ]]; then 
            echo -e "\e[31m错误：通用名称不能为空！\e[0m"
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
 
# 证书生成模块（4096位版本）
generate_certificate() {
    echo -e "\n\e[33m正在生成4096位密钥，可能需要1-3分钟...\e[0m"
    local retries=0 
    while [ $retries -lt 3 ]; do 
        openssl req -x509 \
            -newkey rsa:4096 \
            -nodes \
            -keyout "$cert_dir/server.key"  \
            -out "$cert_dir/server.crt"  \
            -subj "/C=CN/ST=Beijing/L=Beijing/O=MyOrganization/OU=IT/CN=$common_name" \
            -days "$days" \
            -sha256 > /dev/null 2>&1 
        
        if [ $? -eq 0 ]; then 
            break 
        else 
            ((retries++))
            echo -e "\e[31m第${retries}次生成失败，正在重试...\e[0m"
            rm -f "$cert_dir/server.key"  "$cert_dir/server.crt" 
        fi 
    done 
 
    if [ $retries -eq 3 ]; then 
        echo -e "\e[31m错误：密钥生成失败，请检查系统资源\e[0m"
        exit 1 
    fi 
 
    # 生成独立公钥文件 
    openssl rsa -in "$cert_dir/server.key"  -pubout -out "$cert_dir/server.pub"  2>/dev/null 
 
    # 权限安全设置 
    chmod 600 "$cert_dir/server.key" 
    chmod 644 "$cert_dir/server.pub" 
    chmod 644 "$cert_dir/server.crt" 
}
 
# 增强验证模块 
verify_certificate() {
    echo -e "\n\e[1;34m=== 证书验证报告 ===\e[0m"
    
    # 路径输出 
    echo -e "\n\e[36m[文件路径]\e[0m"
    echo "私钥文件：$(realpath "$cert_dir/server.key")" 
    echo "证书文件：$(realpath "$cert_dir/server.crt")" 
    echo "公钥文件：$(realpath "$cert_dir/server.pub")" 
 
    # 密钥强度验证 
    echo -e "\n\e[36m[密钥强度]\e[0m"
    key_length=$(openssl rsa -in "$cert_dir/server.key"  -noout -text | 
        grep "Private-Key" | 
        awk '{print $2}' | 
        sed 's/(//')
    
    if [ "$key_length" -ge 4096 ]; then 
        echo -e "\e[32m✓ 密钥强度达标（${key_length}位）\e[0m"
    else 
        echo -e "\e[31m✗ 密钥强度不足（当前：${key_length}位）\e[0m"
    fi 
 
    # 结构验证 
    echo -e "\n\e[36m[结构验证]\e[0m"
    openssl rsa -in "$cert_dir/server.key"  -check -noout 2>/dev/null &&
        echo -e "\e[32m✓ 私钥结构有效\e[0m" || echo -e "\e[31m✗ 私钥损坏\e[0m"
    
    openssl x509 -in "$cert_dir/server.crt"  -noout 2>/dev/null &&
        echo -e "\e[32m✓ 证书结构有效\e[0m" || echo -e "\e[31m✗ 证书损坏\e[0m"
 
    # 有效期验证 
    echo -e "\n\e[36m[有效期]\e[0m"
    openssl x509 -in "$cert_dir/server.crt"  -noout -dates |
        awk -F= '{
            gsub(/ /, "", $2);
            printf "%-11s: %s\n", $1, $2 
        }' |
        sed 's/notBefore=/生效时间 /;s/notAfter=/过期时间 /'
 
    # 证书链验证 
    echo -e "\n\e[36m[证书链]\e[0m"
    if openssl verify -CAfile "$cert_dir/server.crt"  "$cert_dir/server.crt"  &>/dev/null; then 
        echo -e "\e[32m✓ 自签名证书验证通过\e[0m"
    else 
        echo -e "\e[31m✗ 证书链验证失败\e[0m"
    fi 
 
    # SSL握手测试 
    ssl_handshake_test() {
        read -p "是否进行SSL握手测试？(y/N): " choice 
        [[ ! "$choice" =~ [yY] ]] && return 
 
        local port=28443 
        echo -e "\n\e[36m[SSL测试] 使用端口${port}\e[0m"
        
        openssl s_server -cert "$cert_dir/server.crt"  -key "$cert_dir/server.key"  \
            -quiet -accept $port >/dev/null 2>&1 &
        local pid=$!
        
        sleep 1 # 等待服务启动 
        
        if openssl s_client -connect localhost:$port -no_ign_eof 2>/dev/null | 
            grep -q "Verify return code"; 
        then 
            echo -e "\e[32m✓ SSL握手成功\e[0m"
        else 
            echo -e "\e[31m✗ SSL握手失败\e[0m"
        fi 
        
        kill -9 $pid 2>/dev/null 
    }
    ssl_handshake_test 
}
 
# 目录冲突处理 
handle_directory_conflict() {
    local conflict_dir="$1"
    echo -e "\n\e[33m目录已存在证书文件！\e[0m"
    echo "1) 覆盖现有文件"
    echo "2) 创建子目录保存"
    
    while true; do 
        read -p "请选择 (1-2): " choice 
        case $choice in 
            1)
                rm -f "$conflict_dir"/server.* 
                cert_dir="$conflict_dir"
                break 
                ;;
            2)
                cert_dir="$conflict_dir/SSL_$(date +%s)"
                mkdir -p "$cert_dir"
                break 
                ;;
            *)
                echo "无效选项"
                ;;
        esac 
    done 
}
 
# 路径设置模块 
setup_directory() {
    read -p "请输入保存目录（默认：~/SSL_Certs）: " cert_dir 
    cert_dir=${cert_dir:-"$HOME/SSL_Certs"}
    cert_dir=$(realpath -m "$cert_dir")
 
    if [ -f "$cert_dir/server.key"  ] || [ -f "$cert_dir/server.crt"  ]; then 
        handle_directory_conflict "$cert_dir"
    else 
        mkdir -p "$cert_dir"
    fi 
    
    echo -e "\e[32m保存路径：\e[33m$cert_dir\e[0m"
}
 
# 主流程 
main() {
    check_openssl_installation 
    setup_directory 
    get_common_name 
    select_validity 
    generate_certificate 
    verify_certificate 
 
    # 最终输出 
    echo -e "\n\e[1;35m=== 生成结果 ===\e[0m"
    echo -e "私钥路径：\e[33m$(realpath "$cert_dir/server.key")\e[0m" 
    echo -e "证书路径：\e[33m$(realpath "$cert_dir/server.crt")\e[0m" 
    echo -e "有效期：\e[33m$((days/365))年\e[0m"
 
    # 最终有效性验证 
    echo -e "\n\e[36m[最终验证]\e[0m"
    if openssl x509 -checkend 3600 -noout -in "$cert_dir/server.crt";  then 
        echo -e "\e[32m✓ 证书已生效且有效\e[0m"
    else 
        echo -e "\e[31m✗ 证书未生效或已过期\e[0m"
    fi 
}
 
main 