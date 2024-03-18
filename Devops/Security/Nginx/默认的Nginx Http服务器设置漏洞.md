# 默认的Nginx http服务器设置漏洞

## 漏洞信息

- 编号：93529
- 风险级别：中级风险
- 解决办法：禁用服务器令牌，查看文件并根据需要进行替换或删除

## 具体修复

修改Nginx的配置文件，在http域中添加如下配置

```bash
cd /etc/nginx/

vim nginx.conf
```

```nginx configuration
# 添加如下文件
http {
    server_token off;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options nosniff;
}
```

```bash
# 测试语法是否正确
nginx -t

# 热重载Nginx
nginx -s reload

# 查看nginx服务
ps -ef | grep nginx
```
