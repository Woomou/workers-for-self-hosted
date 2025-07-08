#!/bin/bash

# Direct Nginx Deployment Script for Static Sites
# Usage: SELFDEPLOYIP=your.server.ip DOMAIN=example.com ./deploy-direct-nginx.sh

set -e  # Exit on error

# Load environment variables
if [ -f ".env" ]; then
    echo "📝 Loading environment variables..."
    export $(cat .env | grep -v '^#' | xargs)
elif [ -f "self-hosted/.env" ]; then
    echo "📝 Loading environment variables..."
    export $(cat self-hosted/.env | grep -v '^#' | xargs)
fi

# Check required variables
if [ -z "$SELFDEPLOYIP" ]; then
    echo "⚠️  Error: SELFDEPLOYIP environment variable not set"
    echo "   Usage: SELFDEPLOYIP=your.server.ip DOMAIN=example.com ./deploy-direct-nginx.sh"
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    echo "⚠️  Error: DOMAIN environment variable not set"
    echo "   Usage: SELFDEPLOYIP=your.server.ip DOMAIN=example.com ./deploy-direct-nginx.sh"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "⚠️  Error: CLOUDFLARE_API_TOKEN environment variable not detected"
    echo "   Please set it in self-hosted/.env file"
    exit 1
fi

if [ ! -f "self-hosted-deploy.pem" ] && [ ! -f "self-hosted/self-hosted-deploy.pem" ]; then
    echo "⚠️  Error: self-hosted-deploy.pem file not found"
    echo "   Self-hosted deployment requires PEM file for authentication"
    exit 1
fi

echo "🚀 Starting deployment for domain: $DOMAIN"
echo "📡 Target server: $SELFDEPLOYIP"

# Determine SSH key path
if [ -f "self-hosted-deploy.pem" ]; then
    SSH_KEY="self-hosted-deploy.pem"
else
    SSH_KEY="self-hosted/self-hosted-deploy.pem"
fi

# Set SSH key permissions
chmod 600 "$SSH_KEY"

# Derive configuration variables from domain
DOMAIN_CLEAN=$(echo "$DOMAIN" | sed 's/www\.//')  # Remove www. prefix if present
SITE_DIR="/opt/${DOMAIN_CLEAN//./-}-site"  # Convert dots to dashes for directory
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"

echo "🚀 Starting deployment for domain: $DOMAIN"
echo "📡 Target server: $SELFDEPLOYIP"
echo "📁 Site directory: $SITE_DIR"
echo "🔧 Config will be named: $DOMAIN"

# # 2. Install nginx and certbot
# echo "📦 Installing nginx and certbot..."
# ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
#     "sudo apt update && sudo apt install -y nginx certbot python3-certbot-nginx"

# 3. Create site directory and set permissions
echo "📁 Creating remote directory..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo rm -rf $SITE_DIR && sudo mkdir -p $SITE_DIR && sudo chown ubuntu:ubuntu $SITE_DIR"

# 4. Sync static files to remote server
echo "🔄 Syncing static files to remote server..."
if [ -d ".vercel/output/static" ]; then
    BUILD_DIR=".vercel/output/static"
elif [ -d "out" ]; then
    BUILD_DIR="out"
elif [ -d "build" ]; then
    BUILD_DIR="build"
elif [ -d "../.vercel/output/static" ]; then
    BUILD_DIR="../.vercel/output/static"
elif [ -d "../out" ]; then
    BUILD_DIR="../out"
elif [ -d "../svelte-blog/build" ]; then
    BUILD_DIR="../svelte-blog/build"
else
    echo "⚠️  Error: Build output directory not found (.vercel/output/static, out, or build)"
    echo "   Please run build command first: npm run build"
    exit 1
fi

rsync -avz --delete \
    -e "ssh $SSH_OPTS" \
    "$BUILD_DIR/" \
    "ubuntu@$SELFDEPLOYIP:$SITE_DIR"

# 5. Set static file permissions
echo "🔒 Setting file permissions..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo chown -R www-data:www-data $SITE_DIR && sudo chmod -R 755 $SITE_DIR"

# 6. Deploy nginx configuration files
echo "⚙️  Deploying nginx configuration..."

# Upload main configuration file
if [ -f "nginx-main.conf" ]; then
    NGINX_CONF="nginx-main.conf"
else
    NGINX_CONF="self-hosted/nginx-main.conf"
fi
scp $SSH_OPTS "$NGINX_CONF" "ubuntu@$SELFDEPLOYIP:/tmp/nginx-default"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/nginx-default /etc/nginx/sites-available/default"

# Generate and upload temporary site configuration file
echo "⚙️  Generating temporary site configuration..."
if [ -f "example-site-temp.conf" ]; then
    TEMP_CONF="example-site-temp.conf"
else
    TEMP_CONF="self-hosted/example-site-temp.conf"
fi

sed -e "s/example\.com/$DOMAIN_CLEAN/g" \
    -e "s/www\.example\.com/www.$DOMAIN_CLEAN/g" \
    -e "s/example_access\.log/${DOMAIN_CLEAN//./_}_access.log/g" \
    -e "s/example_error\.log/${DOMAIN_CLEAN//./_}_error.log/g" \
    -e "s/\/opt\/example-site/${SITE_DIR//\//\\/}/g" \
    "$TEMP_CONF" > "/tmp/${DOMAIN}-temp.conf"

scp $SSH_OPTS "/tmp/${DOMAIN}-temp.conf" "ubuntu@$SELFDEPLOYIP:/tmp/${DOMAIN}-temp"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/${DOMAIN}-temp /etc/nginx/sites-available/$DOMAIN && \
     sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/"

# Upload SSL setup script
if [ -f "setup-ssl.sh" ]; then
    SSL_SCRIPT="setup-ssl.sh"
else
    SSL_SCRIPT="self-hosted/setup-ssl.sh"
fi
scp $SSH_OPTS "$SSL_SCRIPT" "ubuntu@$SELFDEPLOYIP:/tmp/setup-ssl.sh"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/setup-ssl.sh /root/setup-ssl.sh && sudo chmod +x /root/setup-ssl.sh"

# 7. Create temporary self-signed certificate
echo "🛡️  Creating temporary SSL certificate..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mkdir -p /etc/ssl/private && \
     sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
         -keyout /etc/ssl/private/nginx-selfsigned.key \
         -out /etc/ssl/certs/nginx-selfsigned.crt \
         -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost'"

# 8. Test nginx configuration
echo "🧪 Testing nginx configuration..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" "sudo nginx -t"

# 9. Start nginx service
echo "🔄 Starting nginx service..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo systemctl enable nginx && sudo systemctl restart nginx"

# 10. Check service status
echo "📊 Checking service status..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo systemctl status nginx --no-pager"

# 11. Test HTTP access
echo "🧪 Testing HTTP access..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' http://localhost/"

# 12. Automatically request SSL certificate
echo "🔒 Setting up SSL certificate..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "export CLOUDFLARE_API_TOKEN='$CLOUDFLARE_API_TOKEN' && export DOMAIN='$DOMAIN' && sudo -E /root/setup-ssl.sh"

# 13. Generate and upload final site configuration (with Let's Encrypt certificate paths)
echo "🔄 Generating final nginx configuration to use Let's Encrypt certificates..."
if [ -f "example-site.conf" ]; then
    FINAL_CONF="example-site.conf"
else
    FINAL_CONF="self-hosted/example-site.conf"
fi

sed -e "s/\/etc\/letsencrypt\/live\/example\.com/\/etc\/letsencrypt\/live\/$DOMAIN/g" \
    -e "s/example\.com/$DOMAIN_CLEAN/g" \
    -e "s/www\.example\.com/www.$DOMAIN_CLEAN/g" \
    -e "s/example_access\.log/${DOMAIN_CLEAN//./_}_access.log/g" \
    -e "s/example_error\.log/${DOMAIN_CLEAN//./_}_error.log/g" \
    -e "s/\/opt\/example-site/${SITE_DIR//\//\\/}/g" \
    "$FINAL_CONF" > "/tmp/${DOMAIN}-final.conf"

scp $SSH_OPTS "/tmp/${DOMAIN}-final.conf" "ubuntu@$SELFDEPLOYIP:/tmp/${DOMAIN}-final"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/${DOMAIN}-final /etc/nginx/sites-available/$DOMAIN"

# 14. Test configuration and restart nginx
echo "🧪 Testing nginx configuration..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" "sudo nginx -t"

echo "🔄 Restarting nginx to load SSL certificates..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo systemctl restart nginx"

# 14. Test HTTPS access
echo "🧪 Testing HTTPS access..."
sleep 5
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "curl -s -o /dev/null -w 'HTTPS Status: %{http_code}\n' https://$DOMAIN/ --insecure || echo 'HTTPS test failed'"

echo ""
echo "✅ Direct Nginx + SSL deployment completed!"
echo "🔗 Access URLs:"
echo "   HTTP: http://$SELFDEPLOYIP"
echo "   HTTPS: https://$DOMAIN"
echo ""
echo "🧪 Test commands:"
echo "   HTTP: curl http://$SELFDEPLOYIP/"
echo "   HTTPS (after SSL): curl https://$DOMAIN/"
echo ""
echo "🔍 Monitoring commands:"
echo "  View access logs: ssh $SSH_OPTS ubuntu@$SELFDEPLOYIP 'sudo tail -f /var/log/nginx/${DOMAIN_CLEAN//./_}_access.log'"
echo "  View error logs: ssh $SSH_OPTS ubuntu@$SELFDEPLOYIP 'sudo tail -f /var/log/nginx/${DOMAIN_CLEAN//./_}_error.log'"
echo "  Check service status: ssh $SSH_OPTS ubuntu@$SELFDEPLOYIP 'sudo systemctl status nginx'"

# Clean up temporary files
echo "🧹 Cleaning up temporary files..."
rm -f "/tmp/${DOMAIN}-temp.conf" "/tmp/${DOMAIN}-final.conf"