#!/bin/bash
#
# zn-m2-lite DIY script part 3
# 针对 208MB 内存 / 6MB rootfs / kernel 4.4.60 的 ZN-M2 定制
#

# ---------- 1. 版本信息 ----------
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt ZN-M2 Lite (208MB optimized, build: $(date +%Y%m%d))'/g" package/base-files/files/etc/openwrt_release

# ---------- 2. Golang 版本：不用 27.x，改用 1.21 ----------
# 原因：Go 1.24+ 编译的静态二进制在 kernel 4.4.60 + 208MB 内存上会
#       fatal error: out of memory allocating heap arena map
#       实测 mihomo v1.16.0 (Go1.21) 撑不住，v1.13.2 (Go1.19) 才稳。
#       但 OpenClash 的依赖（如 clash.meta 新版）需要较新 Go，取 1.21 折中。
if [ -d feeds/packages/lang/golang ]; then
    rm -rf feeds/packages/lang/golang
fi
# 使用 P3TERX 的 golang feed（分支可按需调整）
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 22.x feeds/packages/lang/golang 2>/dev/null \
  || git clone --depth 1 https://github.com/openwrt/packages.git -b master feeds/packages/lang/golang_tmp 2>/dev/null

# ---------- 3. ttyd 免登录 ----------
sed -i -r 's#/bin/login#/bin/login -f root#g' feeds/packages/utils/ttyd/files/ttyd.config

# ---------- 4. design 主题导航栏指向 Passwall ----------
sed -i -r "s#navbar_proxy = 'openclash'#navbar_proxy = 'passwall'#g" feeds/luci/themes/luci-theme-design/luasrc/view/themes/design/header.htm

# ---------- 5. OpenClash 元数据/内核自动更新源（国内加速）----------
# 让 OpenClash 下载内核和 geo 数据走 jsdelivr 镜像，避免 raw.githubusercontent.com 被墙
if [ -f feeds/luci/applications/luci-app-openclash/root/usr/share/openclash/openclash.sh ]; then
    sed -i 's#https://raw.githubusercontent.com#https://cdn.jsdelivr.net/gh#g' \
        feeds/luci/applications/luci-app-openclash/root/usr/share/openclash/*.sh 2>/dev/null
fi

# ---------- 6. 默认开启小闪存模式（关键！）----------
# small_flash_memory=1 让内核走 /tmp (tmpfs)，不写 overlay
# 否则 squashfs 固件重启后内核必丢
if [ -f feeds/luci/applications/luci-app-openclash/root/etc/config/openclash ]; then
    sed -i "s/option small_flash_memory '0'/option small_flash_memory '1'/" \
        feeds/luci/applications/luci-app-openclash/root/etc/config/openclash 2>/dev/null
fi

# ---------- 7. 默认开启 Meta 核心 ----------
sed -i "s/option enable_meta_core '0'/option enable_meta_core '1'/" \
    feeds/luci/applications/luci-app-openclash/root/etc/config/openclash 2>/dev/null

# ---------- 8. 预置内核就位脚本（开机自动解压）----------
mkdir -p files/etc/openclash
cat > files/etc/openclash-restore.sh <<'EOF'
#!/bin/sh
# openclash-restore: 重启后把 overlay 固化的内核/geo 恢复到 tmpfs
CORE_SRC=/etc/openclash/core-backup
TMP_CORE=/tmp/etc/openclash/core
TMP_GEO=/tmp/etc/openclash

mkdir -p "$TMP_CORE" "$TMP_GEO"

if [ -f "$CORE_SRC/clash_meta.gz" ]; then
    gunzip -c "$CORE_SRC/clash_meta.gz" > "$TMP_CORE/clash_meta" 2>/dev/null
    chmod 4755 "$TMP_CORE/clash_meta"
fi

for f in Country.mmdb GeoIP.dat GeoSite.dat geoip.dat geosite.dat \
         china_ip_route.ipset china_ip6_route.ipset accelerated-domains.china.conf; do
    [ -f "$CORE_SRC/$f" ] && cp -f "$CORE_SRC/$f" "$TMP_GEO/$f" 2>/dev/null
done

sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1
exit 0
EOF
chmod 755 files/etc/openclash-restore.sh

# ---------- 9. rc.local：内存优化 + overcommit ----------
mkdir -p files/etc
cat > files/etc/rc.local <<'EOF'
# ZN-M2 Lite 开机脚本

# 恢复内核/geo 到 tmpfs
[ -x /etc/openclash-restore.sh ] && /etc/openclash-restore.sh

# 停用非必需服务释放内存（208MB 小内存设备必需）
for s in quickstart samba vlmcsd; do
  [ -x /etc/init.d/$s ] && /etc/init.d/$s stop >/dev/null 2>&1
done

# 允许超额分配虚拟内存，否则 Go 运行时 722MB 虚拟地址映射会被拒绝
sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1

exit 0
EOF

# ---------- 10. sysctl：overcommit 永久生效 ----------
mkdir -p files/etc
cat > files/etc/sysctl.conf <<'EOF'
# Go 运行时需要映射大块虚拟地址空间
vm.overcommit_memory=1
EOF

echo "zn-m2-lite diy-part3 done"
