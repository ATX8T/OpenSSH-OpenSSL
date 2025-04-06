#!/bin/bash 
 
# ===================================================== 
# OpenSSL 自签名证书生成脚本（PEM/CRT双格式增强版）
# 生成时间：2025-04-07 05:16 
# 版本：v4.0.4096 
# ===================================================== 
 
# 安装检查模块 
check_openssl_installation() {
    if ! command -v openssl &> /dev/null; then 
        echo -e "\e[31m[系统检测] OpenSSL未安装，正在自动安装...\e[0m"
        sudo apt-get update -qq 
        sudo apt-get install -y openssl > /dev/null 2>&1 
        echo -e "\e[32m[系统检测] OpenSSL安装完成！\e[0m"
    fi 
}
 
# 通用名称验证模块 
get_common_name() {
    while true; do 
        echo -en "\n\e[36m[域名输入] \e[0m"
        read -p "请输入域名或服务器IP地址（通用名称）：" common_name 
        if [[ "$common_name" =~ ^[a-zA-Z0-9\.\-]+$ ]]; then 
            break 
        else 
            echo -e "\e[31m[错误] 名称包含非法字符，请使用字母、数字、.和-的组合\e[0m"
        fi 
    done 
}
 
# 有效期选择模块 
select_validity() {
    echo -e "\n\e[36m[有效期设置]\e[0m"
    local menu=(
        "1) 1年   (365天)"
        "2) 2年   (730天)"
        "3) 3年   (1095天)"
        "4) 5年   (1825天)"
        "5) 10年  (3650天)"
    )
    printf "%s\n" "${menu[@]}"
    
    while true; do 
        echo -en "\e[36m[选择] \e[0m"
        read -p "请选择有效期 (1-5): " choice 
        case $choice in 
        1) days=365 ;;
        2) days=730 ;;
        3) days=1095 ;;
        4) days=1825 ;;
        5) days=3650 ;;
        *) echo -e "\e[31m[错误] 无效选项，请重新输入\e[0m"; continue ;;
        esac 
        break 
    done 
}
 
# 证书生成核心模块 
generate_certificate() {
    echo -e "\n\e[36m[证书生成]\e[0m 正在生成4096位RSA密钥..."
    local start_time=$(date +%s)
    
    # 动态文件名定义 
    private_key="$cert_dir/${common_name}_private_key.pem" 
    public_key="$cert_dir/${common_name}_public_key.pem" 
    certificate_crt="$cert_dir/${common_name}_certificate.crt" 
    certificate_pem="$cert_dir/${common_name}_certificate.pem" 
 
    # 生成密钥和证书 
    openssl req -x509 \
        -newkey rsa:4096 \
        -nodes \
        -keyout "$private_key" \
        -out "$certificate_crt" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=MyOrganization/OU=IT/CN=$common_name" \
        -days "$days" \
        -utf8 > /dev/null 2>&1 
 
    # 生成PEM格式证书副本 
    cp "$certificate_crt" "$certificate_pem"
 
    # 提取公钥 
    openssl rsa -in "$private_key" -pubout -out "$public_key" 2>/dev/null 
 
    # 安全权限设置 
    chmod 600 "$private_key"
    chmod 644 "$public_key" "$certificate_crt" "$certificate_pem"
    
    echo -e "\e[32m[成功] 生成耗时$(( $(date +%s) - start_time ))秒\e[0m"
}
 
# 证书验证模块 
verify_certificate() {
    echo -e "\n\e[1;35m=== 证书验证报告 ===\e[0m"
    
    # 密钥强度验证 
    echo -e "\n\e[36m[强度检测]\e[0m"
    local key_info=$(openssl rsa -in "$private_key" -text -noout 2>/dev/null)
    if grep -q "4096 bit" <<< "$key_info"; then 
        echo -e "\e[32m✓ 密钥强度：4096位RSA（符合PCI DSS v4.0标准）\e[0m"
    else 
        echo -e "\e[31m✗ 密钥强度异常！检测到：$(grep 'Private-Key' <<< "$key_info" | awk '{print $3}')\e[0m"
    fi 
 
    # 有效期验证 
    echo -e "\n\e[36m[有效期]\e[0m"
    openssl x509 -in "$certificate_crt" -noout -dates | awk -F= '
    BEGIN { printf "\e[33m%-12s: \e[0m", "生效时间" }
    /notBefore/ { printf "%s\n", $2; printf "\e[33m%-12s: \e[0m", "到期时间" }
    /notAfter/ { print $2 }'
}
 
# 目录冲突处理 
handle_directory_conflict() {
    echo -e "\n\e[33m[警告] 目录中存在同名证书文件！\e[0m"
    ls -lh "$1"/${common_name}_* 2>/dev/null 
    
    local menu=(
        "1) 覆盖现有文件（危险操作）"
        "2) 创建子目录保存 (OpenSSL_Certs)"
        "3) 退出脚本"
    )
    printf "\n%s\n" "${menu[@]}"
    
    while true; do 
        echo -en "\e[36m[选择] \e[0m"
        read -p "请选择处理方式 (1-3): " choice 
        case $choice in 
        1)
            rm -f "$1"/${common_name}_*
            cert_dir="$1"
            echo -e "\e[31m已清除旧证书文件！\e[0m"
            break ;;
        2)
            cert_dir="$1/OpenSSL_Certs"
            mkdir -p "$cert_dir"
            echo -e "\e[32m新证书将保存至：$cert_dir\e[0m"
            break ;;
        3)
            exit 0 ;;
        *)
            echo -e "\e[31m无效选项，请重新输入\e[0m" ;;
        esac 
    done 
}
 
# 主程序流程 
main() {
    clear 
    echo -e "\e[1;34m\n=== OpenSSL 自签名证书生成器 ===\e[0m"
    
    check_openssl_installation 
    
    # 设置保存路径 
    echo -en "\n\e[36m[路径设置] \e[0m"
    read -p "请输入证书保存目录（默认：~/SSL_Certs）：" cert_dir 
    cert_dir=${cert_dir:-"$HOME/SSL_Certs"}
    cert_dir=$(realpath -m "$cert_dir")
    
    get_common_name 
    
    # 冲突检测（基于通用名称）
    if ls "$cert_dir"/${common_name}_* >/dev/null 2>&1; then 
        handle_directory_conflict "$cert_dir"
    else 
        mkdir -p "$cert_dir"
    fi 
    
    select_validity 
    generate_certificate 
    verify_certificate 
    
    # 最终报告 
    echo -e "\n\e[1;35m=== 生成结果 ===\e[0m"
    echo -e "\e[33m私钥路径：\e[0m$(realpath "$private_key")" 
    echo -e "\e[33m公钥路径：\e[0m$(realpath "$public_key")" 
    echo -e "\e[33m证书CRT：\e[0m$(realpath "$certificate_crt")" 
    echo -e "\e[33m证书PEM：\e[0m$(realpath "$certificate_pem")" 
    
    echo -e "\n\e[1;32m[完成] 证书生成流程已全部完成！\e[0m"
}
 
# 执行主程序 
main 