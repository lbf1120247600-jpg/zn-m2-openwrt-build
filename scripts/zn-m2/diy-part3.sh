#!/bin/bash
#
# zn-m2-lite DIY part 3 (build #9)
# 在 #7 基础上删掉 OpenClash 与 uHTTPd
#

# ---------- 版本信息 ----------
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt ZN-M2 Lite Passwall (build: $(date +%Y%m%d))'/g" package/base-files/files/etc/openwrt_release

# ---------- Golang 保持 27.x ----------
# geoview 0.2.6 的 go.mod 要求 go >= 1.25.0，降版会编译失败
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang

# ---------- ttyd 免登录 ----------
sed -i -r 's#/bin/login#/bin/login -f root#g' feeds/packages/utils/ttyd/files/ttyd.config

# ---------- design 主题导航栏指向 Passwall ----------
sed -i -r "s#navbar_proxy = 'openclash'#navbar_proxy = 'passwall'#g" feeds/luci/themes/luci-theme-design/luasrc/view/themes/design/header.htm

# ---------- 开机脚本：内存优化（208MB 设备必需）----------
mkdir -p files/etc
cat > files/etc/rc.local <<'EOF'
# ZN-M2 Lite 开机脚本

# 停用非必需服务释放内存
for s in quickstart samba vlmcsd ttyd; do
  [ -x /etc/init.d/$s ] && /etc/init.d/$s stop >/dev/null 2>&1
done

# Go 运行时需要映射大块虚拟地址空间
sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1

exit 0
EOF

cat > files/etc/sysctl.conf <<'EOF'
vm.overcommit_memory=1
EOF

echo "zn-m2-lite diy-part3 (build #9) done"
