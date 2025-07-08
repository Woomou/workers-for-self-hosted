# Workers for Self-Hosted

> 🌍 **Language / 语言**: [English](#english) | [中文](#中文)

---

## English

### Overview
Self-hosting deployment for static sites using direct Nginx configuration. Supports Next.js SSG frameworks and Cloudflare Workers scenarios.

### 🚀 One-Command Deployment

**That's it! Just run this single script:**

```bash
SELFDEPLOYIP=your.server.ip DOMAIN=example.com ./self-hosted/deploy-direct-nginx.sh
```

**What it does:**
- ✅ Deploys static files to your server
- ✅ Configures Nginx with SSL
- ✅ Sets up automatic certificate renewal
- ✅ Ready to serve traffic

**Prerequisites:**
- `self-hosted/.env` file with `CLOUDFLARE_API_TOKEN`
- `self-hosted/self-hosted-deploy.pem` SSH key
- Built static files (`npm run build`)

---

## 中文

### 概述
使用直接 Nginx 配置的静态站点自托管部署方案。支持 Next.js SSG 框架和 Cloudflare Workers 场景。

### 🚀 一键部署

**就这么简单！只需运行这个脚本：**

```bash
SELFDEPLOYIP=your.server.ip DOMAIN=example.com ./self-hosted/deploy-direct-nginx.sh
```

**脚本功能：**
- ✅ 部署静态文件到服务器
- ✅ 配置带SSL的Nginx
- ✅ 设置自动证书续期
- ✅ 准备好提供服务

**前置条件：**
- `self-hosted/.env` 文件包含 `CLOUDFLARE_API_TOKEN`
- `self-hosted/self-hosted-deploy.pem` SSH密钥
- 构建的静态文件 (`npm run build`)

---

## Variables / 变量

| Variable | Description | 描述 |
|----------|------------|------|
| `SELFDEPLOYIP` | Target server IP | 目标服务器IP |
| `DOMAIN` | Your domain name | 你的域名 |
| `CLOUDFLARE_API_TOKEN` | In .env file | 在.env文件中设置 |