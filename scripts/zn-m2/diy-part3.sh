#!/bin/bash
#
# zn-m2-lite DIY part 3
# 针对 208MB 内存 / 6MB rootfs / kernel 4.4.60 的 ZN-M2 定制
#

# ---------- 1. 版本信息 ----------
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt ZN-M2 Lite (build: $(date +%Y%m%d))'/g" package/base-files/files/etc/openwrt_release

# ---------- 2. Golang 版本：保持 27.x（与上游一致）----------
# 注意：不要降 golang！
#   geoview 0.2.6 (passwall 依赖) 的 go.mod 要求 go >= 1.25.0
#   降到 22.x 会直接编译失败：go: ../../go.mod requires go >= 1.25.0
# 内存问题用其他方式解决（lite geo / 停服务 / overcommit），不动 golang
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang

# ---------- 3. ttyd 免登录 ----------
sed -i -r 's#/bin/login#/bin/login -f root#g' feeds/packages/utils/ttyd/files/ttyd.config

# ---------- 4. design 主题导航栏指向 Passwall ----------
sed -i -r "s#navbar_proxy = 'openclash'#navbar_proxy = 'passwall'#g" feeds/luci/themes/luci-theme-design/luasrc/view/themes/design/header.htm

# ---------- 5. OpenClash 下载源走 jsdelivr 镜像 ----------
if [ -d feeds/luci/applications/luci-app-openclash ]; then
    sed -i 's#https://raw.githubusercontent.com#https://cdn.jsdelivr.net/gh#g' \
        feeds/luci/applications/luci-app-openclash/root/usr/share/openclash/*.sh 2>/dev/null
fi

# ---------- 6. 预置开机恢复脚本（内核/geo/shim）----------
mkdir -p files/etc
cat > files/etc/openclash-restore.sh <<'EOF'
#!/bin/sh
# openclash-restore: 重启后恢复内核/geo/shim
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

# ruby shim（musl 系统 glibc ruby 必崩）
if [ -f "$CORE_SRC/ruby-shim" ]; then
    cp "$CORE_SRC/ruby-shim" /usr/bin/ruby 2>/dev/null
    chmod 755 /usr/bin/ruby 2>/dev/null
    [ -f "$CORE_SRC/yamlread.awk" ] && cp -f "$CORE_SRC/yamlread.awk" /usr/share/openclash/ 2>/dev/null
fi

# nohup shim（精简固件缺 nohup）
if [ -f "$CORE_SRC/nohup-shim" ]; then
    cp "$CORE_SRC/nohup-shim" /usr/bin/nohup 2>/dev/null
    chmod 755 /usr/bin/nohup 2>/dev/null
fi

sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1
exit 0
EOF
chmod 755 files/etc/openclash-restore.sh

# ---------- 7. rc.local：内存优化 ----------
cat > files/etc/rc.local <<'EOF'
# ZN-M2 Lite 开机脚本

[ -x /etc/openclash-restore.sh ] && /etc/openclash-restore.sh

# 停用非必需服务释放内存（208MB 小内存设备必需）
for s in quickstart samba vlmcsd ttyd; do
  [ -x /etc/init.d/$s ] && /etc/init.d/$s stop >/dev/null 2>&1
done

# Go 运行时需要映射大块虚拟地址空间
sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1

exit 0
EOF

# ---------- 8. sysctl ----------
cat > files/etc/sysctl.conf <<'EOF'
vm.overcommit_memory=1
EOF

# ---------- 9. 预置 OpenClash 默认配置（小闪存 + meta 核心）----------
if [ -d feeds/luci/applications/luci-app-openclash/root/etc/config ]; then
    CFG=feeds/luci/applications/luci-app-openclash/root/etc/config/openclash
    if [ -f "$CFG" ]; then
        sed -i "s/option small_flash_memory '0'/option small_flash_memory '1'/" "$CFG"
        sed -i "s/option enable_meta_core '0'/option enable_meta_core '1'/" "$CFG"
    fi
fi

echo "zn-m2-lite diy-part3 done"
