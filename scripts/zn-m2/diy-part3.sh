#!/bin/bash
#
# zn-m2-lite DIY part 3 (build #8)
# Passwall only - OpenClash/OpenVPN removed per user request
#

# ---------- 1. 版本信息 ----------
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt ZN-M2 Lite Passwall (build: $(date +%Y%m%d))'/g" package/base-files/files/etc/openwrt_release

# ---------- 2. Golang：保持 27.x ----------
# 注意：不要降 golang！geoview 0.2.6 的 go.mod 要求 go >= 1.25.0，
# 降到 22.x 会导致编译失败。内存问题用 lite geo / 停服务 / overcommit 解决。
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang

# ---------- 3. ttyd 免登录 ----------
sed -i -r 's#/bin/login#/bin/login -f root#g' feeds/packages/utils/ttyd/files/ttyd.config

# ---------- 4. design 主题导航栏指向 Passwall ----------
sed -i -r "s#navbar_proxy = 'openclash'#navbar_proxy = 'passwall'#g" feeds/luci/themes/luci-theme-design/luasrc/view/themes/design/header.htm

# ---------- 5. 预置开机脚本：内存优化 ----------
mkdir -p files/etc
cat > files/etc/rc.local <<'EOF'
# ZN-M2 Lite 开机脚本（208MB 内存优化）

# 停用非必需服务释放内存（208MB 小内存设备必需）
for s in quickstart samba vlmcsd ttyd; do
  [ -x /etc/init.d/$s ] && /etc/init.d/$s stop >/dev/null 2>&1
done

# Go 运行时需要映射大块虚拟地址空间
sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1

exit 0
EOF

# ---------- 6. sysctl：overcommit ----------
cat > files/etc/sysctl.conf <<'EOF'
vm.overcommit_memory=1
EOF

echo "zn-m2-lite diy-part3 (build #8) done"
