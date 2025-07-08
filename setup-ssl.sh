#!/bin/bash

# Example Site - SSL Certificate Setup Script
# This script sets up SSL certificates using Cloudflare DNS challenge

set -e

echo "🔒 开始设置 SSL 证书..."

# 检查环境变量
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "⚠️  错误: 未设置 CLOUDFLARE_API_TOKEN 环境变量"
    exit 1
fi

# 安装 Cloudflare DNS 插件
echo "📦 安装 Cloudflare DNS 插件..."
apt update
apt install -y python3-certbot-dns-cloudflare

# 创建 Cloudflare 凭据文件
echo "🔑 创建 Cloudflare 凭据文件..."
mkdir -p /etc/letsencrypt
cat > /etc/letsencrypt/cloudflare.ini << EOF
dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN
EOF

# 设置凭据文件权限
chmod 600 /etc/letsencrypt/cloudflare.ini

# 申请 SSL 证书
echo "📜 申请 SSL 证书..."
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 \
    -d example.com \
    -d www.example.com \
    --non-interactive \
    --agree-tos \
    --email admin@example.com

# 设置自动续期
echo "⏰ 设置自动续期..."
crontab -l > /tmp/crontab.bak 2>/dev/null || true
echo "0 2 * * * certbot renew --quiet && systemctl reload nginx" >> /tmp/crontab.bak
crontab /tmp/crontab.bak
rm /tmp/crontab.bak

echo "✅ SSL 证书设置完成！"
echo "📜 证书位置: /etc/letsencrypt/live/example.com/"
echo "⏰ 自动续期已设置 (每天凌晨2点检查)"