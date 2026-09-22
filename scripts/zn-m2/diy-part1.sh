#!/bin/bash
# zn-m2-lite DIY part 1 — feeds 加载前
# 默认 IP 改为 192.168.1.1（保持与你当前路由一致）
sed -i 's/192.168.1.1/192.168.1.1/g' package/base-files/files/bin/config_generate 2>/dev/null || true
