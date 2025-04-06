# OpenSSH-OpenSSL
OpenSSL 与 OpenSSH 生成脚本

## OpenSSL
- OpenSSLkey3.sh  主要用于OpenSSL自签证书生成
  - 有ssl验证功能


## OpenSSH
- 为服务器创建root用户，避免编辑文件的麻烦，以及没有宝塔面板作文件权限问题
- **文件功能描述**：
    - ssh_configure.sh为服务器创建root用户
    - delete_and_regenerate_ssh.sh基于ssh_configure.sh删除并重新生成密钥
    - 
- ssh_configure.sh功能描述
    - 判断是否安装ssh
    - 启动ssh
    - 生成openssh密钥
    - **添加到authorized_keys中**
    - **修改ssh配置文件，允许root和密钥登录**
    - 在命令行输出密钥，
    - 系统检测 → 安装SSH → 启动服务 → 生成密钥 → 配置公钥 → 修改SSH配置 → 重启服务 → 输出验证

