#!/bin/bash
set -eu

sed -i -e '/CONFIG_MAKE_TOOLCHAIN=y/d' configs/rockchip/01-nanopi
sed -i -e 's/CONFIG_IB=y/# CONFIG_IB is not set/g' configs/rockchip/01-nanopi
sed -i -e 's/CONFIG_SDK=y/# CONFIG_SDK is not set/g' configs/rockchip/01-nanopi

sed -i -e 's/192\.168\.2\.1/192.168.8.1/g' \
	friendlywrt/target/linux/rockchip/armv8/base-files/etc/board.d/02_network

find device/common/src-patchs -type f -name '*.patch' -exec \
	sed -i -e 's/192\.168\.2\.1/192.168.8.1/g' {} +
