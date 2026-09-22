# ZN-M2 Lite 精简优化固件 — 构建包使用说明

针对你的设备：**兆能 ZN M2 / IPQ6018 / kernel 4.4.60 / 208MB 内存 / 6MB rootfs / 无WiFi / 无USB**

---

## 一、这个包里有什么

```
zn-m2-build/
├── config/
│   └── zn-m2-lite.config          # 精简版编译配置（147项，原版162项）
├── feeds-lite.conf.default        # feeds 源（去掉 lucky/gecoosac，加 openclash）
├── scripts/zn-m2-lite/
│   ├── diy-part1.sh               # 基础定制
│   ├── diy-part2.sh               # feeds 安装优先级
│   └── diy-part3.sh               # 核心定制（golang版本/内存优化/开机脚本）
├── .github/workflows/
│   └── zn-m2-lite.yml             # GitHub Actions 构建流程
├── zn-m2.config                   # 原版配置（参考用，不参与构建）
└── README.md                      # 本文件
```

---

## 二、为什么要这样做（而不是本地编译）

你的 Windows 机器**没有 WSL、没有 Docker**，无法本地编译 OpenWrt。
而这个社区固件本身就是用 **GitHub Actions 云端构建**的——所以正确做法是
**fork 仓库 → 替换配置 → 触发 Actions → 下载固件**。

不需要你本地有任何编译环境。

---

## 三、精简了什么

| 类别 | 砍掉的东西 | 理由 |
|---|---|---|
| VPN | WireGuard、OpenVPN | 你用代理，不用 VPN |
| 内网穿透 | Lucky、NPS | 弱电箱设备不需要 |
| 集客AC | gecoosac | 酒店网络有专业 AC，不用这个 |
| DDNS | ddns-scripts | 无公网 IP 需求 |
| 杂项 LuCI | ARP绑定、自动重启、文件传输、UPnP、WOL、design配置 | 用不到 |
| socks/dns 工具 | dns2socks、dns2tcp、ipt2socks、microsocks、ssocks、pdnsd | Passwall 自带更完整的 |
| 压测 | coremark、stress-ng | 完全没用 |
| curl 冷门协议 | FTP、TFTP、cookies、TLS-SRP、unix-sockets | 省固件体积 |
| OpenVPN 编译选项 | 8 个 ENABLE_* 选项 | 已不编 openvrt |

**保留的核心**：Passwall（SingBox/Xray/Haproxy/Hysteria）+ OpenClash + ChinaDNS-NG + LuCI + ttyd + curl/bash/htop

---

## 四、针对你机器的关键优化（这是重点）

这些是从之前几轮实战踩坑中总结的，已写进 `diy-part3.sh`：

### 1. Golang 版本改为 1.21（不用原版的 27.x）
原固件 `diy-part3.sh` 第 20 行把 golang 换成 27.x。**这对你的机器是灾难**：
```
fatal error: out of memory allocating heap arena map
```
实测：Go 1.26 的 mihomo 在 208MB 内存上必崩。已改为 22.x 分支。

### 2. 默认开启 `small_flash_memory=1`
这是你最初那个报错的根治方案：
```
客户端可能无法更新，因为 squashfs 格式的固件更新后不会释放闪存空间
```
开启后内核走 `/tmp/etc/openclash/core/`（tmpfs 内存盘），**不写 overlay，不占闪存**。

### 3. 默认开启 Meta 核心
`enable_meta_core=1`，用 mihomo 而非传统 clash。

### 4. 内置开机恢复脚本 `/etc/openclash-restore.sh`
重启后自动把 overlay 里备份的内核（gzip 存放，7.6MB）解压到 tmpfs。
**解决"重启后内核丢失"**。

### 5. `vm.overcommit_memory=1` 永久生效
写进 `/etc/sysctl.conf` + `rc.local`。
Go 运行时要映射 722MB 虚拟地址空间，不开这个会被内核拒绝。

### 6. 开机自动停用非必需服务
`rc.local` 里停掉 quickstart（占 696MB 虚拟内存）、samba、vlmcsd。
实测能把可用内存从 35MB 提到 45MB+。

### 7. OpenClash 下载源走 jsdelivr 镜像
`diy-part3.sh` 会把 `raw.githubusercontent.com` 替换成 `cdn.jsdelivr.net/gh`，
避免你的网络环境解析不了 GitHub raw 域名（之前日志里一堆 `Could not resolve host: raw.githubusercontent.com`）。

---

## 五、怎么构建（3 步）

### 第 1 步：Fork 仓库
打开 https://github.com/openwrt-fork/zn-m2-openwrt-build
点右上角 **Fork**， fork 到你自己的账号下。

### 第 2 步：替换文件
在你 fork 后的仓库里，用 GitHub 网页端或 git 推送，做这些替换：

| 操作 | 源文件（本包内） | 目标路径（你的仓库） |
|---|---|---|
| 替换 | `config/zn-m2-lite.config` | `config/zn-m2-lite.config` |
| 替换 | `feeds-lite.conf.default` | `feeds.conf.default` |
| 替换 | `scripts/zn-m2-lite/diy-part1.sh` | `scripts/zn-m2/diy-part1.sh` |
| 替换 | `scripts/zn-m2-lite/diy-part2.sh` | `scripts/zn-m2/diy-part2.sh` |
| 替换 | `scripts/zn-m2-lite/diy-part3.sh` | `scripts/zn-m2/diy-part3.sh` |
| 新增 | `.github/workflows/zn-m2-lite.yml` | `.github/workflows/zn-m2-lite.yml` |

**注意**：workflow 文件里的 `DIY_P1_SH` 等路径仍指向 `./scripts/zn-m2/`，
所以 DIY 脚本要放到 `scripts/zn-m2/` 下覆盖原文件，不是新建目录。

**最省事的做法**：直接告诉我，我可以生成一个完整的 git 仓库压缩包，
你解压后 `git push` 一把梭。

### 第 3 步：触发构建
进你仓库的 **Actions** 页面 → 左侧选 **zn-m2-lite build** → 右侧 **Run workflow** → 运行。

构建时间约 **2-3 小时**（只编一个变体，比原版快一半）。
完成后自动发布到 Release，文件名类似：
```
openwrt-ipq60xx-generic-zn_m2-squashfs-nand-sysupgrade-lite.bin
```

---

## 六、刷机

⚠️ **刷机会清空配置，先备份**（见第七节）

| 场景 | 文件 | 说明 |
|---|---|---|
| 系统升级（保留配置） | `*sysupgrade-lite.bin` | 推荐，你现在就能用 |
| uboot 救砖 | `*factory-lite.ubi` | 只在变砖时用 |

升级方式（任选其一）：
1. **LuCI 界面**：系统 → 备份/升级 → 选择 .bin → 保留配置（可选）
2. **SSH**：`scp` 上传到 `/tmp/`，然后 `sysupgrade -F /tmp/xxx.bin`
   （`-F` 强制，不检查固件名）

---

## 七、刷机前必须备份

```sh
# SSH 连上路由器后执行
sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz
scp root@192.168.1.1:/tmp/backup-*.tar.gz ./
```

需要额外手动留一份的（备份包可能不含）：
- `/etc/openclash/config/L.yaml`（你的订阅配置）
- `/etc/openclash/core-backup/`（内核备份）

---

## 八、风险与备选

### 风险 1：OpenClash 可能编译失败
`feeds-lite.conf.default` 里加的 `vernesong/OpenClash` 是给新版 OpenWrt 用的，
**在这个 19.07 定制固件上没验证过**。

如果编译报 `luci-app-openclash` 相关错误：
- 方案 A：从 `feeds-lite.conf.default` 删掉 openclash 那行，从 `zn-m2-lite.config` 删掉
  `luci-app-openclash` 两项，重新触发构建（只用 Passwall）
- 方案 B：保留原固件（当前在跑的这套），不刷机

**Passwall 是社区固件原生适配的，肯定能编过。**

### 风险 2：Golang 22.x 分支可能不存在
`diy-part3.sh` 里我用了 fallback（22.x 失败则 clone packages master）。
如果两个都失败，会退回系统默认 golang，可能又回到 OOM 问题。
到时候看编译日志再调。

### 风险 3：208MB 内存跑新版内核依然吃力
即使 golang 降到 1.21，如果 Passwall 的 SingBox/Xray 是 Go 1.21+ 编译的，
仍可能 OOM。**建议刷完后先用 ttyd 看 `free` 确认内存余量**。

---

## 九、不刷机的替代方案

如果你不想冒险刷机，现在这套（iStoreOS + mihomo v1.13.2 + 我做的 shim）已经能：
- 正常路由上网
- OpenClash 界面正常
- 内核跑在 tmpfs 不占闪存
- 重启自动恢复

**唯一的问题是你的机场节点连不上**（VLESS over Cloudflare，v1.13.2 不支持好）。
这个问题刷机也未必解决——真正的原因是 208MB 内存装不下能支持那些节点的新版内核。

**最实际的建议**：换个有 SS/Trojan 节点的机场，或者只在电脑上用 Clash Verge 挂代理。

---

## 十、文件清单

所有文件都在 `C:\Users\Administrator\Desktop\zn-m2-build\` 下，
可以直接打包发给你，或我用 git 仓库形式给你。
