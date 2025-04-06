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
 
# 交互式SSL测试（保留原有实现）
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
    openssl s_server -cert "$cert_dir/server.crt"  -key "$cert_dir/server.key"  \
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
 
# 新增功能：证书路径输出 
output_cert_paths() {
    echo -e "\n\e[1;35m=== 证书文件路径 ===\e[0m"
    echo -e "私钥文件：\e[33m$(realpath "$cert_dir/server.key")\e[0m" 
    echo -e "证书文件：\e[33m$(realpath "$cert_dir/server.crt")\e[0m" 
    echo -e "公钥文件：\e[33m$(realpath "$cert_dir/server.pub")\e[0m" 
}
 
# 新增功能：证书可用性验证 
check_cert_validity() {
    echo -e "\n\e[1;35m=== 证书有效性验证 ===\e[0m"
    
    # 基础验证 
    openssl x509 -in "$cert_dir/server.crt"  -noout 2>/dev/null 
    if [ $? -ne 0 ]; then 
        echo -e "\e[31m✗ 证书文件不可读或已损坏\e[0m"
        return 1 
    fi 
 
    # 有效期验证（检查未来1小时是否有效）
    openssl x509 -checkend 3600 -noout -in "$cert_dir/server.crt" 
    if [ $? -eq 0 ]; then 
        echo -e "\e[32m✓ 证书在1小时内有效\e[0m"
    else 
        echo -e "\e[31m✗ 证书即将过期或已过期\e[0m"
    fi 
 
    # 密钥匹配验证 
    key_mod=$(openssl rsa -modulus -noout -in "$cert_dir/server.key"  2>/dev/null | openssl sha256)
    cert_mod=$(openssl x509 -modulus -noout -in "$cert_dir/server.crt"  2>/dev/null | openssl sha256)
    if [ "$key_mod" == "$cert_mod" ]; then 
        echo -e "\e[32m✓ 私钥与证书匹配\e[0m"
    else 
        echo -e "\e[31m✗ 密钥不匹配！差异值：${key_mod:0:16} vs ${cert_mod:0:16}\e[0m"
    fi 
}
 
# 主程序流程 
main() {
    check_openssl_installation 
    get_common_name 
    select_validity 
    generate_certificate 
    
    # 新增功能调用 
    output_cert_paths 
    check_cert_validity 
    
    # 保留原有交互测试 
    ssl_handshake_test 
}
 
main 