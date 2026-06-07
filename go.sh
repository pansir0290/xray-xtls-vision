#!/bin/bash

# 颜色控制
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}错误：必须使用 root 用户运行此脚本！${PLAIN}" && exit 1

clear
echo -e "${GREEN}=================================================================="
echo -e "  VLESS + XTLS-Vision + Caddy 真实视频站回落（全自动一体化脚本）"
echo -e "=================================================================="${PLAIN}

# 1. 人机交互收集信息
read -p "1. 请输入你的自建域名 (如 video.yourdomain.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}域名不能为空！${PLAIN}" && exit 1
fi

read -p "2. 请输入你的邮箱 (用于注册并申请 SSL 证书): " EMAIL
if [ -z "$EMAIL" ]; then
    echo -e "${RED}邮箱不能为空！${PLAIN}" && exit 1
fi

FALLBACK_PORT=8080
VIDEO_DIR="/var/www/video"

echo -e "\n${YELLOW}确认配置信息：${PLAIN}"
echo -e "   - 伪装域名: ${DOMAIN}"
echo -e "   - 证书邮箱: ${EMAIL}"
echo -e "   - 内部回落端口: ${FALLBACK_PORT}"
echo -e "   - 伪装视频目录: ${VIDEO_DIR}"
echo -e "=================================================================="
read -p "确认无误后按回车键，正式开始“降维打击”部署..."

# 2. 卸载可能冲突的 Apache/Nginx 并安装基础依赖
echo -e "${GREEN}[*] 正在清理环境并安装系统依赖...${PLAIN}"
apt-get update -y
apt-get remove -y nginx apache2
apt-get install -y curl socat jq debian-keyring debian-archive-keyring apt-transport-https

# 3. 安装 Caddy 官方正版
echo -e "${GREEN}[*] 正在安装 Caddy...${PLAIN}"
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -y
apt-get install caddy -y

# 核心步骤：立刻停止并禁用 caddy 默认服务，防止它强占 80/443 导致后面申请证书失败
systemctl stop caddy

# 4. 安装 Xray 核心
echo -e "${GREEN}[*] 正在安装 Xray 最新官方核心...${PLAIN}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
mkdir -p /usr/local/etc/xray

# 5. 使用 acme.sh 自动化申请 ECC 证书
echo -e "${GREEN}[*] 正在通过 acme.sh 申请免费的 ECC 证书...${PLAIN}"
curl https://get.acme.sh | sh -s email=$EMAIL
source ~/.bashrc
~/.acme.sh/acme.sh --upgrade --auto-upgrade
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 强行释放 80 端口以防万一
fuser -k 80/tcp >/dev/null 2>&1

# 独立模式申请证书
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --ecc
if [ $? -ne 0 ]; then
    echo -e "${RED}错误：证书申请失败！请检查域名解析是否正确，或 80 端口是否被安全组拦截。${PLAIN}"
    exit 1
fi

# 安装证书到 Xray 目录
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
    --key-file /usr/local/etc/xray/xray.key \
    --fullchain-file /usr/local/etc/xray/xray.crt

# 6. 自动化配置 Xray (VLESS + XTLS-Vision + 回落到 8080)
echo -e "${GREEN}[*] 正在配置 Xray 路由规则...${PLAIN}"
UUID=$(xray uuid)

cat << EOF > /usr/local/etc/xray/config.json
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": "${FALLBACK_PORT}",
                        "xver": 0
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "minVersion": "1.2",
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/xray/xray.crt",
                            "keyFile": "/usr/local/etc/xray/xray.key"
                        }
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF

# 7. 自动化配置 Caddy (本地监听 8080 + 关掉自动 HTTPS)
echo -e "${GREEN}[*] 正在配置 Caddyfile 完美回落模式...${PLAIN}"
cat << EOF > /etc/caddy/Caddyfile
:${FALLBACK_PORT} {
    auto_https off
    root * ${VIDEO_DIR}
    file_server browse
}
EOF

# 8. 自动化下载/构建虚拟视频网站内容伪装
echo -e "${GREEN}[*] 正在构建高清视频下载站伪装内容...${PLAIN}"
mkdir -p ${VIDEO_DIR}

# 创造几个真实的、有体积的虚拟视频文件（用于迎合大流量特征）
echo -e "${YELLOW}正在生成 100MB 虚拟视频伪装文件，请稍候...${PLAIN}"
dd if=/dev/zero of=${VIDEO_DIR}/Tokyo_4K_HDR_Demo.mp4 bs=1M count=100 >/dev/null 2>&1
dd if=/dev/zero of=${VIDEO_DIR}/Cyberpunk_Neon_Aesthetics_1080P.mkv bs=1M count=150 >/dev/null 2>&1

# 写入漂亮的精装视频下载网页
cat << 'HTM' > /var/www/video/index.html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>4K 极清视频素材流媒体本地备份库</title>
    <style>
        body { font-family: -apple-system, sans-serif; background: #121212; color: #e0e0e0; max-width: 800px; margin: 40px auto; padding: 20px; }
        h1 { color: #ff007f; border-bottom: 2px solid #333; padding-bottom: 10px; }
        .file-list { background: #1e1e1e; padding: 20px; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.5); }
        .file-item { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #2d2d2d; }
        .file-item:last-child { border: none; }
        a { color: #00adb5; text-decoration: none; font-weight: bold; }
        a:hover { text-decoration: underline; }
        .meta { color: #777; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>🎬 个人影视后期高性能素材备份站</h1>
    <p class="meta">当前节点：日本东京 (Tokyo, JP) | 传输协议：内网多线程高速回源</p>
    <div class="file-list">
        <div class="file-item">
            <a href="Tokyo_4K_HDR_Demo.mp4">🎥 Tokyo_4K_HDR_Demo.mp4</a>
            <span class="meta">100.00 MB / 视频格式: MP4</span>
        </div>
        <div class="file-item">
            <a href="Cyberpunk_Neon_Aesthetics_1080P.mkv">🎥 Cyberpunk_Neon_Aesthetics_1080P.mkv</a>
            <span class="meta">150.00 MB / 视频格式: MKV</span>
        </div>
    </div>
</body>
</html>
HTM

# 赋予权限
chown -R caddy:caddy ${VIDEO_DIR}

# 9. 证书自动续签联动重启
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
    --key-file /usr/local/etc/xray/xray.key \
    --fullchain-file /usr/local/etc/xray/xray.crt \
    --reloadcmd "systemctl restart xray"

# 10. 启动所有服务
echo -e "${GREEN}[*] 正在启动服务...${PLAIN}"
systemctl daemon-reload
systemctl enable xray caddy
systemctl restart xray caddy

# 清理脚本痕迹
clear
echo -e "${GREEN}=================================================================="
echo -e "       🎉 恭喜！终极闭环一体化全自动部署成功！"
echo -e "==================================================================${PLAIN}"
echo -e "${YELLOW}【落地端节点参数】${PLAIN}"
echo -e " 🔹 地址 (Address)     : ${DOMAIN}"
echo -e " 🔹 端口 (Port)        : 443"
echo -e " 🔹 用户 ID (UUID)     : ${UUID}"
echo -e " 🔹 加密方式 (Encrypt) : none"
echo -e " 🔹 传输协议 (Network) : tcp"
echo -e " 🔹 安全传输 (TLS)     : tls"
echo -e " 🔹 流控 (Flow)        : xtls-rprx-vision"
echo -e " 🔹 SNI / 伪装域名      : ${DOMAIN}"
echo -e ""
echo -e "${YELLOW}【通用 vless 分享链接】${PLAIN}"
echo -e "${GREEN}vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&flow=xtls-rprx-vision&sni=${DOMAIN}#XTLS-Vision-CaddyVideo${PLAIN}"
echo -e "=================================================================="
echo -e "${YELLOW}【防封测试验证】${PLAIN}"
echo -e " 💡 现在你可以直接在浏览器里访问：https://${DOMAIN}"
echo -e " 💡 墙和所有人看到的都是一个带 100M+ 真实大文件下载的极速视频素材站！"
echo -e "=================================================================="
EOF

chmod +x xray_caddy_ultimate.sh
./xray_caddy_ultimate.sh
