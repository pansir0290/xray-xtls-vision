#!/bin/bash

# 1. 彻底暴力清理
systemctl stop xray sing-box caddy 2>/dev/null
killall -9 xray sing-box caddy 2>/dev/null
rm -rf /usr/local/etc/xray /etc/caddy /usr/local/bin/xray /usr/local/bin/sing-box /var/www/html/* 2>/dev/null

# 2. 基础安装
apt-get update -y && apt-get install -y curl socat jq

# 3. 安装 Xray & Caddy
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y && apt-get install caddy -y

# 4. 获取域名邮箱
read -p "请输入域名: " DOMAIN
read -p "请输入邮箱: " EMAIL

# 5. 申请证书
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --ecc
mkdir -p /usr/local/etc/xray
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
    --key-file /usr/local/etc/xray/xray.key \
    --fullchain-file /usr/local/etc/xray/xray.crt

# 6. 配置生成
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

# 7. 最终启动与权限修复
chown -R nobody:nogroup /usr/local/etc/xray
chmod 644 /usr/local/etc/xray/xray.crt /usr/local/etc/xray/xray.key
systemctl restart xray caddy

# 8. 强力输出节点链接
clear
echo -e "\n========================================="
echo -e "✅ 部署完成！以下是你的节点信息："
echo -e "-----------------------------------------"
echo -e "UUID : $UUID"
echo -e "链接 : vless://$UUID@$DOMAIN:443?encryption=none&security=tls&flow=xtls-rprx-vision&sni=$DOMAIN#XTLS-Vision-Final"
echo -e "-----------------------------------------"
echo -e "提示: 如果不通，请确认 Cloudflare 已关闭小黄云(仅DNS)"
echo -e "========================================="
