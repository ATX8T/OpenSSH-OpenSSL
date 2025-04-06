# 为服务器创建root用户，避免编辑文件的麻烦，以及没有宝塔面板作文件权限问题

## 文件功能描述：

   - ssh_configure.sh为服务器创建root用户
   - delete_and_regenerate_ssh.sh基于ssh_configure.sh删除并重新生成密钥

## ssh_configure.sh功能描述

- 判断是否安装ssh
- 启动ssh
- 生成openssh密钥
- 添加到authorized_keys中
- 修改ssh配置文件，允许root和密钥登录
- 在命令行输出密钥，
- 系统检测 → 安装SSH → 启动服务 → 生成密钥 → 配置公钥 → 修改SSH配置 → 重启服务 → 输出验证


8. 输出密钥文件内容并进行验证

## delete_and_regenerate_ssh.sh 描述

1. 删除旧密钥文件。
2. 从authorized_keys中移除旧公钥。
3. 生成新的RSA密钥对。
4. 追加新公钥到authorized_keys。
5. 设置正确的文件和目录权限。
6. 验证新公钥是否成功添加。
7. 检查SSH服务配置中的公钥认证设置。
8. 重启SSH服务使配置生效。
9. 执行SSH连接测试验证公钥认证是否成功。


## 输出密钥后需要复制保存密钥到本地，重命名为id_rsa

- 在本地创建id_rsa 并且放入命令行的私钥
- 或者在本地使用openssh生成一样的id_rsa文件，然后打开替换密钥

## 使用密钥连接

- Windows使用Windows PowerShell连接出现读取密钥的权限异常问题，推荐使用FinalShell与id_rsa密钥连接

  ```
  F:\IM\ls\id_rsa 本地存放路径
   ssh -i "F:\IM\ls\id_rsa" root@170.106.110.14
  ```

- 使用FinalShell➕密钥登录
- ![使用FinalShell➕密钥登录](./img/image.png)
- ![使用FinalShell➕密钥登录](./img/image (1).png)




## FinalShell内root连接命令

```
bash <(curl -s https://raw.githubusercontent.com/ATX8T/SSH/main/ssh_configure.sh)

原地址  直接在浏览器中查看github的ssh_configure.sh文件获取地址然后修改

https://github.com/ATX8T/SSH/blob/main/ssh_configure.sh
```

## 连接成功后删除服务器私钥

```
删除命令
rm ~/.ssh/id_rsa
rm ~/.ssh/id_rsa.pub
删除这两个文件
rm ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
```

- 👌👌👌👌👌👌👌👌👌👌
- 👌👌👌👌👌👌👌👌👌👌
- 👌👌👌👌👌👌👌👌👌👌
- 👌👌👌👌👌👌👌👌👌👌


## 如果连接失败：

    1. 本地.ssh下面 known_hosts 文件中仍保留着之前远程主机的密钥记录，当再次连接时，客户端会先检查该文件中的记录，发现与新密钥不一致就报错。
    2. 从 known_hosts 文件中删除指定主机的密钥记录，然后重新连接。
    3. Windows位于C:\Users\ai861\.ssh下面







# README.md 中显示图片操作
- 使用相对路径实现，需要注意相对路径写法规则。
- 使用相对路径方便在移动或者迁移到其他仓库中或者是本地都可以正常显示

