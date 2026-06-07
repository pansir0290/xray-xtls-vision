# 🎬 VLESS + XTLS-Vision + Caddy 真实视频素材站回落一体化脚本

本项目提供了一个极其稳固、对抗 GFW 机器学习流量审计与主动探测的个人节点终极部署方案。

采用 **“最前置 Xray 监听 443 端口 —> 识别代理流量直接放行 —> 非代理/探测流量无缝脱壳回落给本地 Caddy 视频站”** 的闭环架构。完美解决传统代理在大流量下的指纹特征以及面对墙主动探测时的露馅问题。

---

## 🌟 核心技术优势

1. **精准阻击机器学习 (Behavioral Camouflage)**
   利用 **XTLS-Vision** 的动态填充（Padding）与内层流控机制，彻底消灭 TLS-in-TLS（隧道套隧道）的数据包长度与时序机械特征，强行将代理流量整形为标准的 HTTPS 网页浏览或流媒体切片下载。

2. **完美的身份合法性 (100% 阳谋)**
   使用你自己的域名与正规机构（Let's Encrypt）签发的合法 ECC 证书。在墙的审计模型中，域名、证书、服务器 IP 100% 对齐，属于法理上最纯洁的互联网流量。

3. **无懈可击的主动探测防御 (Fallback Loop)**
   当墙的探针发出错误的、伪造的、或者不带 SNI 的握手包来试探 443 端口时，Xray 会自动剥离 TLS，将请求甩给本地 `8080` 端口的 Caddy。Caddy 会吐出正规的高清视频文件和漂亮的下载页面，让探针无法定性。

4. **零依赖纯本地伪装构建 (Zero-Download)**
   脚本不依赖任何外部 GitHub 模板或第三方大文件下载，**稳定性 100%**。利用 Linux 底层 `dd` 命令在本地瞬间“画出” 100MB+ 的虚拟真实视频文件，耗时不足 1 秒且不消耗外部流量，演戏演到极致。

---

## 🛠️ 准备工作（运行前必看）

为确保脚本一次性 100% 跑通，请在执行前确认以下三点：
1. **域名解析已生效：** 请确保你的自建域名已经 A 记录解析到了当前运行脚本的落地鸡 IP（可在本地电脑 `ping 你的域名` 验证）。
2. **绝对不能开启 CDN：** 如果使用 Cloudflare，请将该域名的 Proxy 状态保持为 **“DNS Only”（灰云朵）**。开启黄云朵会导致证书申请失败且 Vision 协议失效。
3. **防火墙端口放行：** 请确保 VPS 服务商的后台安全组（Firewall）已经放行了 **80** 和 **443** 端口。

---

## 🚀 一键安装命令

在你的**海外落地服务器**上，切换至 `root` 用户，直接复制并运行以下命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/pansir0290/xray-xtls-vision/main/go.sh)

```
脚本会采用**人机交互**方式，引导你输入域名和邮箱，随后全自动完成 Caddy 与 Xray 的安装、环境冲突清理、证书申请、配置文件联动及伪装站构建。

---

## 📱 客户端通用配置参数

部署成功后，控制台会打印出专属于你的 VLESS 节点链接。通用手工配置参数如下：

| 参数项 | 配置值 |
| :--- | :--- |
| **地址 (Address)** | `你的域名` |
| **端口 (Port)** | `443` |
| **用户 ID (UUID)** | `脚本自动生成的 UUID` |
| **加密方式 (Encryption)** | `none` |
| **传输协议 (Network)** | `tcp` |
| **底层传输安全 (TLS)** | `tls` |
| **流控 (Flow)** | `xtls-rprx-vision` |
| **SNI / 伪装域名** | `你的域名` |

> 适用客户端：v2rayN, Sing-box, Clash Meta (Mihomo), v2rayNG, Shadowrocket 等支持 Xray 核心或内置 Vision 协议的现代客户端。

---

## 📂 服务器目录与常用命令

* **Xray 核心配置文件：** `/usr/local/etc/xray/config.json`
* **Caddy 配置文件：** `/etc/caddy/Caddyfile`
* **伪装视频站网页及大文件目录：** `/var/www/video/`
* **证书自动续签管理：** 由 `acme.sh` 自动接管，并绑定了续签后自动重启 Xray 任务。

**日常维护命令：**
```bash
# 查看服务状态
systemctl status xray
systemctl status caddy

# 重启服务
systemctl restart xray
systemctl restart caddy
```

---

## 📜 免责声明
本项目仅用于合法的 Linux 服务器运维、技术研究与流量行为整形测试。请勿用于任何违反您当地法律法规的活动。
