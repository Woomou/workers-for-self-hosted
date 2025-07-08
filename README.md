# Workers for Self-Hosted

When you need to route traffic for a specific subdomain to a designated cloud host, you can configure this self-hosting method. Currently, this approach is limited to Next.js SSG frameworks and Cloudflare Workers scenarios.

## 🎯 部署架构

```
外部域名 → 直接Nginx (80/443) → 静态文件服务
```

**优势**：
- ✅ 不依赖Docker Proxy Manager
- ✅ 原生nginx性能更好  
- ✅ 支持多域名配置
- ✅ 自动SSL证书管理
- ✅ 更简单的配置和维护

## 📁 配置文件结构

```
/etc/nginx/sites-available/
├── default          # 主配置 (80/443端口处理)
└── example.com       # www.example.com 站点配置

/opt/example-site/    # 静态文件目录
└── [Next.js输出文件]

/etc/letsencrypt/     # SSL证书目录
└── live/example.com/
```

## 🚀 部署步骤

### 1. 环境准备

```bash
# 设置服务器IP
export SELFDEPLOYIP="your.server.ip"

# 确保SSH密钥存在
ls self-hosted/self-hosted-deploy.pem

# 构建项目
npm run build  # 或 npm run pages:build
```

### 2. 一键部署

```bash
SELFDEPLOYIP=your.server.ip ./self-hosted/deploy-direct-nginx.sh
```

部署脚本会自动：
- 📦 安装nginx和certbot
- 📁 同步静态文件
- ⚙️ 配置nginx
- 🛡️ 创建临时SSL证书
- 🔄 启动nginx服务

### 3. 设置SSL证书

部署完成后，在服务器上运行：

```bash
ssh -i self-hosted/self-hosted-deploy.pem ubuntu@$SELFDEPLOYIP
sudo /root/setup-ssl.sh
```

**SSL验证方式选择**：
- **HTTP验证** - 域名已指向服务器时使用
- **DNS验证** - 手动添加TXT记录
- **Cloudflare DNS** - 自动验证（需要API Token）

## 🌐 域名配置

确保DNS记录正确：
```
www.example.com  A  your.server.ip
example.com      A  your.server.ip
```

## 🔧 nginx配置说明

### 主配置 (`/etc/nginx/sites-available/default`)
- 监听80端口，HTTP→HTTPS重定向
- 监听443端口，处理未配置域名
- 支持Let's Encrypt ACME挑战

### 站点配置 (`/etc/nginx/sites-available/example.com`)
- 处理www.example.com和example.com
- HTML路由重写（/path → /path.html）
- 静态资源缓存和压缩
- 安全头配置

## 🧪 测试访问

```bash
# HTTP访问 (会自动重定向到HTTPS)
curl http://your.server.ip/

# HTTPS访问 (SSL证书配置后)
curl https://www.example.com/

# 检查重定向
curl -I http://www.example.com/
```

## 📊 监控和维护

### 查看日志
```bash
# 访问日志
sudo tail -f /var/log/nginx/example_access.log

# 错误日志  
sudo tail -f /var/log/nginx/example_error.log
```

### 管理服务
```bash
# 检查nginx状态
sudo systemctl status nginx

# 重载配置
sudo nginx -t && sudo systemctl reload nginx

# 查看SSL证书
sudo certbot certificates
```

### 证书续期
证书会自动续期，也可手动检查：
```bash
sudo certbot renew --dry-run
```

## 🔄 添加新域名

要添加新项目/域名，只需：

1. **创建新的站点配置**：
```bash
sudo cp /etc/nginx/sites-available/example.com /etc/nginx/sites-available/newsite.com
sudo nano /etc/nginx/sites-available/newsite.com
```

2. **启用站点**：
```bash
sudo ln -s /etc/nginx/sites-available/newsite.com /etc/nginx/sites-enabled/
```

3. **申请SSL证书**：
```bash
sudo certbot --nginx -d newsite.com -d www.newsite.com
```

## 🚨 故障排除

### 常见问题

1. **nginx启动失败**
   - 检查配置：`sudo nginx -t`
   - 查看错误日志：`sudo journalctl -u nginx`

2. **SSL证书申请失败**  
   - 确认DNS解析正确
   - 检查防火墙端口80/443
   - 使用DNS验证方式

3. **404错误**
   - 检查文件权限：`ls -la /opt/example-site/`
   - 确认路由配置正确

## 📋 系统要求

### 服务器环境
- Ubuntu/Debian系统
- 2GB+ RAM  
- 20GB+ 存储空间
- 端口80/443开放

### 本地环境
- SSH访问权限
- rsync工具
- 构建输出目录 (out/ 或 .vercel/output/static/)

## 🎉 部署完成

部署成功后，你将拥有：
- ✅ 高性能原生nginx服务
- ✅ 自动HTTPS和证书续期
- ✅ 完整的路由重写支持
- ✅ 多域名支持能力
- ✅ 专业的缓存和安全配置