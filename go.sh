#!/bin/bash

# 检查权限
[[ $EUID -ne 0 ]] && echo "❌ 必须使用 root 权限运行" && exit 1

# 1. 人机互动输入
read -p "请输入你的域名 (如 video.yourdomain.com): " DOMAIN
read -p "请输入你的电子邮箱: " EMAIL

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
    echo "❌ 域名和邮箱不能为空，脚本退出。"
    exit 1
fi

echo "🚀 开始一键部署，请稍候..."

# 2. 环境清理与基础依赖
systemctl stop xray caddy 2>/dev/null
apt-get update -y && apt-get install -y curl socat jq

# 3. 安装 Xray (官方安装脚本)
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 4. 安装 Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y && apt-get install caddy -y

# 5. 申请证书
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --ecc
mkdir -p /usr/local/etc/xray
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
    --key-file /usr/local/etc/xray/xray.key \
    --fullchain-file /usr/local/etc/xray/xray.crt

# 6. 生成配置文件
UUID=$(xray uuid)

cat << EOF > /usr/local/etc/xray/config.json
{
    "inbounds": [{
        "port": 443,
        "protocol": "vless",
        "settings": {
            "clients": [{"id": "$UUID", "flow": "xtls-rprx-vision"}],
            "decryption": "none",
            "fallbacks": [{"dest": "8080"}]
        },
        "streamSettings": {
            "network": "tcp",
            "security": "tls",
            "tlsSettings": {
                "certificates": [{"certificateFile": "/usr/local/etc/xray/xray.crt", "keyFile": "/usr/local/etc/xray/xray.key"}]
            }
        }
    }],
    "outbounds": [{"protocol": "freedom"}]
}
EOF

cat << EOF > /etc/caddy/Caddyfile
:8080 {
    root * /var/www/html
    file_server browse
}
EOF

# 7. 启动服务
systemctl enable --now xray caddy
systemctl restart xray caddy

echo "========================================="
echo "✅ 部署完成！"
echo "UUID: $UUID"
echo "链接: vless://$UUID@$DOMAIN:443?encryption=none&security=tls&flow=xtls-rprx-vision&sni=$DOMAIN#XTLS-Vision"
