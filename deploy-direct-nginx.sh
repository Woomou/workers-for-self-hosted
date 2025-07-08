#!/bin/bash

# Example Site - 直接Nginx部署脚本 (替代Proxy Manager)
# 使用方法: ./deploy-direct-nginx.sh

set -e  # 遇到错误时停止

echo "🚀 开始部署 Example Site 到直接 Nginx 配置..."

# 加载环境变量
if [ -f "self-hosted/.env" ]; then
    echo "📝 加载环境变量..."
    export $(cat self-hosted/.env | grep -v '^#' | xargs)
fi

# 检查环境变量
if [ -z "$SELFDEPLOYIP" ]; then
    echo "⚠️  错误: 未检测到 SELFDEPLOYIP 环境变量"
    echo "   请设置目标服务器的 IP 地址"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "⚠️  错误: 未检测到 CLOUDFLARE_API_TOKEN 环境变量"
    echo "   请在 self-hosted/.env 文件中设置"
    exit 1
fi

if [ ! -f "self-hosted/self-hosted-deploy.pem" ]; then
    echo "⚠️  错误: 未找到 self-hosted/self-hosted-deploy.pem 文件"
    echo "   自托管部署需要 PEM 文件进行认证"
    exit 1
fi

echo "📡 目标服务器: $SELFDEPLOYIP"

# 设置 SSH 密钥权限
chmod 600 self-hosted/self-hosted-deploy.pem

# 配置变量
SITE_DIR="/opt/example-site"
SSH_KEY="self-hosted/self-hosted-deploy.pem"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"

# # 2. 安装nginx和certbot
# echo "📦 安装nginx和certbot..."
# ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
#     "sudo apt update && sudo apt install -y nginx certbot python3-certbot-nginx"

# 3. 创建站点目录并设置权限
echo "📁 创建远程目录..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo rm -rf $SITE_DIR && sudo mkdir -p $SITE_DIR && sudo chown ubuntu:ubuntu $SITE_DIR"

# 4. 同步静态文件到远程服务器
echo "🔄 同步静态文件到远程服务器..."
if [ -d ".vercel/output/static" ]; then
    rsync -avz --delete \
        -e "ssh $SSH_OPTS" \
        .vercel/output/static/ \
        "ubuntu@$SELFDEPLOYIP:$SITE_DIR"
elif [ -d "out" ]; then
    rsync -avz --delete \
        -e "ssh $SSH_OPTS" \
        out/ \
        "ubuntu@$SELFDEPLOYIP:$SITE_DIR"
else
    echo "⚠️  错误: 未找到构建输出目录 (.vercel/output/static 或 out)"
    echo "   请先运行构建命令: npm run build"
    exit 1
fi

# 5. 设置静态文件权限
echo "🔒 设置文件权限..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo chown -R www-data:www-data $SITE_DIR && sudo chmod -R 755 $SITE_DIR"

# 6. 部署nginx配置文件
echo "⚙️  部署nginx配置..."

# 上传主配置文件
scp $SSH_OPTS self-hosted/nginx-main.conf "ubuntu@$SELFDEPLOYIP:/tmp/nginx-default"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/nginx-default /etc/nginx/sites-available/default"

# 上传临时站点配置文件
scp $SSH_OPTS self-hosted/example-site-temp.conf "ubuntu@$SELFDEPLOYIP:/tmp/example-site-temp"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/example-site-temp /etc/nginx/sites-available/example.com && \
     sudo ln -sf /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/"

# 上传SSL设置脚本
scp $SSH_OPTS self-hosted/setup-ssl.sh "ubuntu@$SELFDEPLOYIP:/tmp/setup-ssl.sh"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/setup-ssl.sh /root/setup-ssl.sh && sudo chmod +x /root/setup-ssl.sh"

# 7. 创建临时自签名证书
echo "🛡️  创建临时SSL证书..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mkdir -p /etc/ssl/private && \
     sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
         -keyout /etc/ssl/private/nginx-selfsigned.key \
         -out /etc/ssl/certs/nginx-selfsigned.crt \
         -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost'"

# 8. 测试nginx配置
echo "🧪 测试nginx配置..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" "sudo nginx -t"

# 9. 启动nginx服务
echo "🔄 启动nginx服务..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo systemctl enable nginx && sudo systemctl restart nginx"

# 10. 检查服务状态
echo "📊 检查服务状态..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo systemctl status nginx --no-pager"

# 11. 测试HTTP访问
echo "🧪 测试HTTP访问..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "curl -s -o /dev/null -w 'HTTP状态码: %{http_code}\n' http://localhost/"

# 12. 自动申请SSL证书
echo "🔒 设置SSL证书..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "export CLOUDFLARE_API_TOKEN='$CLOUDFLARE_API_TOKEN' && sudo -E /root/setup-ssl.sh"

# 13. 上传正式站点配置 (包含Let's Encrypt证书路径)
echo "🔄 更新nginx配置使用Let's Encrypt证书..."
scp $SSH_OPTS self-hosted/example-site.conf "ubuntu@$SELFDEPLOYIP:/tmp/example-site-final"
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo mv /tmp/example-site-final /etc/nginx/sites-available/example.com"

# 14. 测试配置并重启nginx
echo "🧪 测试nginx配置..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" "sudo nginx -t"

echo "🔄 重启nginx加载SSL证书..."
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "sudo systemctl restart nginx"

# 14. 测试HTTPS访问
echo "🧪 测试HTTPS访问..."
sleep 5
ssh $SSH_OPTS "ubuntu@$SELFDEPLOYIP" \
    "curl -s -o /dev/null -w 'HTTPS状态码: %{http_code}\n' https://www.example.com/ --insecure || echo 'HTTPS测试失败'"

echo ""
echo "✅ 直接 Nginx + SSL 部署完成！"
echo "🔗 访问地址:"
echo "   HTTP: http://$SELFDEPLOYIP"
echo "   HTTPS: https://www.example.com"
echo ""
echo "🧪 测试命令:"
echo "   HTTP: curl http://$SELFDEPLOYIP/"
echo "   HTTPS (SSL后): curl https://www.example.com/"
echo ""
echo "🔍 监控命令:"
echo "  查看访问日志: ssh $SSH_OPTS ubuntu@$SELFDEPLOYIP 'sudo tail -f /var/log/nginx/example_access.log'"
echo "  查看错误日志: ssh $SSH_OPTS ubuntu@$SELFDEPLOYIP 'sudo tail -f /var/log/nginx/example_error.log'"
echo "  检查服务状态: ssh $SSH_OPTS ubuntu@$SELFDEPLOYIP 'sudo systemctl status nginx'"