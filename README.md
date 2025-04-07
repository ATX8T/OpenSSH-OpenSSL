# OpenSSH-OpenSSL
OpenSSL 与 OpenSSH 生成脚本

## 拉取地址
- ⚠️需要注意服务器能不能连接到GitHub
- ⚠️登录执行前检查当前登录的用户是否有权限
- 下载到本地使用 chmod +x 赋予权限
  
### SSH生成
```
ssh_configure.sh
创建root用户
bash <(curl -s https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/ssh_configure.sh)
4096位
bash <(curl -s https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/ssh_configure4096.sh)

删除并创建root用户
bash <(curl -s https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/delete_and_regenerate_ssh.sh)

```
### 生成OpenSSL ok版本 自签证书调试----实现浏览器信任
- 多种格式生成，根证书，证书，密钥公钥等，后续再nginx中配置ssl 下载证书安装后测试，浏览器信任
- ⚠️注意：如果生成的证书是自签名的，浏览器可能会提示证书不安全，需要手动信任证书。客户端安装根证书与证书两个。
- nginx配置记得改ip
```
去除CN，使用SAN 
bash <(curl -s https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/OpenSSLOK.sh)

使用宝塔安装nginx  添加下列配置块  
    # 新增的 HTTPS server 块
    server {
        listen 443 ssl;
        server_name 170.106.98.243; # 请替换为你的实际域名

        ssl_certificate /opt/SSL/ServerCertificate.crt;
        ssl_certificate_key /opt/SSL/ServerPrivateKey.key;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        root /www/wwwroot/your_site_root; # 请替换为你的网站根目录
        index index.html index.htm index.php;

        access_log /www/wwwlogs/https_access.log;
        error_log /www/wwwlogs/https_error.log;

        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ \.php$ {
            fastcgi_pass 127.0.0.1:9000; # 请根据实际情况修改
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }

        location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$ {
            expires 30d;
        }

        location ~ .*\.(js|css)?$ {
            expires 12h;
        }

        location ~ /\. {
            deny all;
        }
    }

```


### 生成OpenSSL 测试用
```
SSL
bash <(curl -s https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/openssl2048.sh)

4096位ssl
bash <(curl -s https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/openssl4096.sh)


4096位ssl，PEM/CRT双格式
bash <(curl -s https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/openssl4096X2.sh)

浏览器默认不信任自签名证书，即便安装到本地，仍会标记不安全。因为自签名证书没有权威证书颁发机构（CA）背书。

```

## OpenSSL
- OpenSSLkey3.sh  主要用于OpenSSL自签证书生成
  - 有ssl验证功能


## OpenSSH
- 为服务器创建root用户，避免编辑文件的麻烦，以及没有宝塔面板作文件权限问题
- [详细](./SSH/README.md)
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
## 远程拉取并且执行方法
- 直接在GitHub中编辑ssh_configure.sh，在浏览器顶部获取https://github.com/ATX8T/OpenSSH-OpenSSL/blob/main/ssh_configure.sh 源地址
- 源地址：https://github.com/ATX8T/OpenSSH-OpenSSL/blob/main/ssh_configure.sh
- **去掉源连接里面的 blob与https://github.com**
- 组合到：https://raw.githubusercontent.com 里面
- 最终:https://raw.githubusercontent.com/ATX8T/OpenSSH-OpenSSL/main/ssh_configure.sh




- 空行测试
<br></br>
<br></br>
<br></br>
<br></br>
<br></br>
<br></br>
# 测试一下显示图片
![测试一下显示图片](./SSH/img/haha/niuh1.png)

