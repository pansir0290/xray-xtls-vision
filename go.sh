#!/bin/bash

# 颜色控制
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误：必须使用 root 用户运行此脚本！${PLAIN}" && exit 1

# 1. 强制清理旧环境函数
cleanup_env() {
    echo -e "${YELLOW}[*] 正在执行全量清理（删除旧的 Xray/Caddy/证书残留）...${PLAIN}"
    systemctl stop xray caddy 2>/dev/null
    systemctl disable xray caddy 2>/dev/null
    apt-get purge -y xray caddy 2>/dev/null
    rm -rf /usr/local/etc/xray /etc/caddy /var/www/video /usr/local/bin/xray /usr/local/bin/geosite /usr/local/bin/geoip
    # 清理 acme 证书残留
    if [ -d "$HOME/.acme.sh" ]; then
        $HOME/.acme.sh/acme.sh --uninstall
        rm -rf $HOME/.acme.sh
    fi
}

clear
echo -e "${GREEN}=================================================================="
echo -e "  VLESS + XTLS-Vision + Caddy 全自动部署（已添加强制环境清理）"
echo -e "=================================================================="${PLAIN}

# 询问是否清理
read -p "是否强制执行全量清理（覆盖旧安装）? [y/N]: " CLEAN
if [[ "$CLEAN" =~ ^[yY]$ ]]; then
    cleanup_env
fi

# 2. 人机交互收集信息
read -p "1. 请输入你的自建域名 (如 video.yourdomain.com): " DOMAIN
read -p "2. 请输入你的邮箱: " EMAIL

FALLBACK_PORT=8080
VIDEO_DIR="/var/www/video"

# 3. 安装基础依赖
apt-get update -y
apt-get install -y curl socat jq debian-keyring debian-archive-keyring apt-transport-https

# 4. 安装 Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install caddy -y

# 5. 安装 Xray 核心
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 6. 申请证书
curl https://get.acme.sh | sh
source ~/.bashrc
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
fuser -k 80/tcp >/dev/null 2>&1
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --ecc
mkdir -p /usr/local/etc/xray
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc --key-file /usr/local/etc/xray/xray.key --fullchain-file /usr/local/etc/xray/xray.crt

# 7. 生成 UUID 并配置 Xray
UUID=$(xray uuid)
cat << EOF > /usr/local/etc/xray/config.json
{
    "inbounds": [{
        "port": 443,
        "protocol": "vless",
        "settings": {
            "clients": [{"id": "${UUID}", "flow": "xtls-rprx-vision"}],
            "decryption": "none",
            "fallbacks": [{"dest": "${FALLBACK_PORT}"}]
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

# 8. 配置 Caddy
cat << EOF > /etc/caddy/Caddyfile
:${FALLBACK_PORT} {
    auto_https off
    root * ${VIDEO_DIR}
    file_server browse
}
EOF

# 9. 生成伪装视频站内容
mkdir -p ${VIDEO_DIR}
echo "Fake Video Site Content" > ${VIDEO_DIR}/index.html
chown -R caddy:caddy ${VIDEO_DIR}

# 10. 启动并配置联动
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc --key-file /usr/local/etc/xray/xray.key --fullchain-file /usr/local/etc/xray/xray.crt --reloadcmd "systemctl restart xray"
systemctl enable --now xray caddy
systemctl restart xray caddy

echo -e "${GREEN}部署完成！分享链接：${PLAIN}"
echo -e "vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&flow=xtls-rprx-vision&sni=${DOMAIN}#XTLS-Vision-CaddyVideo"
