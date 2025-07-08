#!/bin/bash

# Example Site - SSL Certificate Setup Script
# This script sets up SSL certificates using Cloudflare DNS challenge

set -e

echo "🔒 Starting SSL certificate setup..."

# Check environment variables
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "⚠️  Error: CLOUDFLARE_API_TOKEN environment variable not set"
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    echo "⚠️  Error: DOMAIN environment variable not set"
    exit 1
fi

# Derive domain variables
DOMAIN_CLEAN=$(echo "$DOMAIN" | sed 's/www\.//')  # Remove www. prefix if present
WWW_DOMAIN="www.$DOMAIN_CLEAN"

echo "🌐 Setting up SSL for domain: $DOMAIN_CLEAN (and $WWW_DOMAIN)"

# Install Cloudflare DNS plugin
echo "📦 Installing Cloudflare DNS plugin..."
apt update
apt install -y python3-certbot-dns-cloudflare

# Create Cloudflare credentials file
echo "🔑 Creating Cloudflare credentials file..."
mkdir -p /etc/letsencrypt
cat > /etc/letsencrypt/cloudflare.ini << EOF
dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN
EOF

# Set credentials file permissions
chmod 600 /etc/letsencrypt/cloudflare.ini

# Request SSL certificate
echo "📜 Requesting SSL certificate..."
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 \
    -d $DOMAIN_CLEAN \
    -d $WWW_DOMAIN \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN_CLEAN

# Setup automatic renewal
echo "⏰ Setting up automatic renewal..."
crontab -l > /tmp/crontab.bak 2>/dev/null || true
echo "0 2 * * * certbot renew --quiet && systemctl reload nginx" >> /tmp/crontab.bak
crontab /tmp/crontab.bak
rm /tmp/crontab.bak

echo "✅ SSL certificate setup completed!"
echo "📜 Certificate location: /etc/letsencrypt/live/$DOMAIN_CLEAN/"
echo "⏰ Automatic renewal set up (checks daily at 2 AM)"