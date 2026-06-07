#!/bin/bash

# 0. 权限检查
[[ $EUID -ne 0 ]] && echo "❌ 必须使用 root 权限" && exit 1

# 1. 人机输入
read -p "请输入你的域名: " DOMAIN
read -p "请输入你的邮箱: " EMAIL

# 2. 彻底清理与环境归零
echo "🧹 正在彻底清理系统..."
systemctl stop xray caddy 2>/dev/null
killall -9 xray caddy sing-box 2>/dev/null
rm -rf /usr/local/etc/xray /etc/caddy /usr/local/bin/xray /usr/local/bin/caddy /var/www/html/* 2>/dev/null

# 3. 安装依赖
apt-get update -y && apt-get install -y curl socat jq

# 4. 安装核心组件
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
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
    respond "Caddy is running"
}
EOF

# 7. 强制修复权限 (核心环节)
chown -R nobody:nogroup /usr/local/etc/xray
chmod -R 755 /usr/local/etc/xray
chmod 644 /usr/local/etc/xray/xray.crt /usr/local/etc/xray/xray.key

# 8. 服务联动重启
systemctl daemon-reload
systemctl enable --now xray caddy
systemctl restart xray caddy

# 9. 最终输出
echo -e "\n========================================="
echo -e "✅ 部署完成！"
echo -e "UUID : $UUID"
echo -e "链接 : vless://$UUID@$DOMAIN:443?encryption=none&security=tls&flow=xtls-rprx-vision&sni=$DOMAIN#XTLS-Vision-Auto"
echo -e "-----------------------------------------"
echo -e "检查状态命令："
echo -e "ss -tlnp | grep -E '443|8080'"
echo -e "========================================="
