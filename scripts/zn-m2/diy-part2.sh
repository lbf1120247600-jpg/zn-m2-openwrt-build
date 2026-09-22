#!/bin/bash
# zn-m2-lite DIY part 2 — feeds update 后
# 优先安装 passwall 源（原固件的做法，保持兼容性）
./scripts/feeds install -a -f -p passwall_packages
./scripts/feeds install -a -f -p passwall_luci
