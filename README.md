# Workers for Self-Hosted

> 🌍 **Language / 语言**: [English](#english) | [中文](#中文)

---

## English

### Overview
When you need to route traffic for a specific subdomain to a designated cloud host, you can configure this self-hosting method. Currently, this approach is limited to Next.js SSG frameworks and Cloudflare Workers scenarios.

### 🎯 Deployment Architecture
```
External Domain → Direct Nginx (80/443) → Static File Service
```

**Advantages:**
- ✅ No dependency on Docker Proxy Manager
- ✅ Better native nginx performance
- ✅ Multi-domain configuration support
- ✅ Automatic SSL certificate management

### 🚀 Quick Deployment

1. **Environment Setup**
```bash
# Set server IP
export SELFDEPLOYIP="your.server.ip"

# Ensure SSH key exists
ls self-hosted/self-hosted-deploy.pem

# Build project
npm run build
```

2. **One-Click Deploy**
```bash
SELFDEPLOYIP=your.server.ip ./self-hosted/deploy-direct-nginx.sh
```

3. **SSL Setup**
```bash
ssh -i self-hosted/self-hosted-deploy.pem ubuntu@$SELFDEPLOYIP
sudo /root/setup-ssl.sh
```

### 🔧 Configuration Files
- `nginx-main.conf` - Main nginx configuration
- `example-site.conf` - Site-specific configuration with SSL
- `example-site-temp.conf` - Temporary configuration (before SSL)

### 🧪 Testing
```bash
# HTTP access
curl http://your.server.ip/

# HTTPS access (after SSL setup)
curl https://www.example.com/
```

### 📊 Monitoring
```bash
# View logs
sudo tail -f /var/log/nginx/example_access.log

# Check service status
sudo systemctl status nginx
```

---

## 中文

### 概述
当您需要将特定子域的流量路由到指定的云主机时，可以配置此自托管方法。目前此方法仅限于 Next.js SSG 框架和 Cloudflare Workers 场景。

### 🎯 部署架构
```
外部域名 → 直接Nginx (80/443) → 静态文件服务
```

**优势：**
- ✅ 不依赖Docker Proxy Manager
- ✅ 原生nginx性能更好
- ✅ 支持多域名配置
- ✅ 自动SSL证书管理

### 🚀 快速部署

1. **环境准备**
```bash
# 设置服务器IP
export SELFDEPLOYIP="your.server.ip"

# 确保SSH密钥存在
ls self-hosted/self-hosted-deploy.pem

# 构建项目
npm run build
```

2. **一键部署**
```bash
SELFDEPLOYIP=your.server.ip ./self-hosted/deploy-direct-nginx.sh
```

3. **SSL设置**
```bash
ssh -i self-hosted/self-hosted-deploy.pem ubuntu@$SELFDEPLOYIP
sudo /root/setup-ssl.sh
```

### 🔧 配置文件
- `nginx-main.conf` - 主nginx配置
- `example-site.conf` - 带SSL的站点配置
- `example-site-temp.conf` - 临时配置（SSL前）

### 🧪 测试
```bash
# HTTP访问
curl http://your.server.ip/

# HTTPS访问（SSL配置后）
curl https://www.example.com/
```

### 📊 监控
```bash
# 查看日志
sudo tail -f /var/log/nginx/example_access.log

# 检查服务状态
sudo systemctl status nginx
```

---

## System Requirements

### Server Environment
- Ubuntu/Debian system
- 2GB+ RAM
- 20GB+ storage space
- Ports 80/443 open

### Local Environment
- SSH access permissions
- rsync tool
- Build output directory (out/ or .vercel/output/static/)

## 系统要求

### 服务器环境
- Ubuntu/Debian系统
- 2GB+ RAM
- 20GB+ 存储空间
- 端口80/443开放

### 本地环境
- SSH访问权限
- rsync工具
- 构建输出目录 (out/ 或 .vercel/output/static/)