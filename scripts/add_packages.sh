#!/bin/bash
set -eu

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AMNEZIA_VENDOR_DIR="${REPO_ROOT}/packages/amneziawg-openwrt"
AMNEZIA_PACKAGE_DIR="friendlywrt/package/amneziawg"
ROCKCHIP_EXTRA_CONFIG="configs/rockchip/99-codex-native-vpn"
ROCKCHIP_DOCKER_EXTRA_CONFIG="configs/rockchip-docker/99-codex-docker"
ROCKCHIP_DOCKER_SHARED_LINK="configs/rockchip-docker/99-codex-native-vpn"

# {{ Add luci-app-diskman
(cd friendlywrt && {
    mkdir -p package/luci-app-diskman
    wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile.old -O package/luci-app-diskman/Makefile
})
cat >> configs/rockchip/01-nanopi <<EOL
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_btrfs_progs=y
CONFIG_PACKAGE_luci-app-diskman_INCLUDE_lsblk=y
CONFIG_PACKAGE_luci-i18n-diskman-zh-cn=y
CONFIG_PACKAGE_smartmontools=y
EOL
# }}

# {{ Add luci-theme-argon
(cd friendlywrt/package && {
    [ -d luci-theme-argon ] && rm -rf luci-theme-argon
    git clone https://github.com/jerrykuku/luci-theme-argon.git --depth 1 -b master
})
echo "CONFIG_PACKAGE_luci-theme-argon=y" >> configs/rockchip/01-nanopi
sed -i -e 's/function init_theme/function old_init_theme/g' friendlywrt/target/linux/rockchip/armv8/base-files/root/setup.sh
cat > /tmp/appendtext.txt <<EOL
function init_theme() {
    if uci get luci.themes.Argon >/dev/null 2>&1; then
        uci set luci.main.mediaurlbase="/luci-static/argon"
        uci commit luci
    fi
}
EOL
sed -i -e '/boardname=/r /tmp/appendtext.txt' friendlywrt/target/linux/rockchip/armv8/base-files/root/setup.sh
# }}

# {{ Vendor native AmneziaWG packages directly into the FriendlyWrt tree.
rm -rf "${AMNEZIA_PACKAGE_DIR}"
mkdir -p "${AMNEZIA_PACKAGE_DIR}"
rsync -a --delete "${AMNEZIA_VENDOR_DIR}/" "${AMNEZIA_PACKAGE_DIR}/"
# }}

# {{ Add config fragments for R6S extras.
# Kernel modules tied to the FriendlyARM vendor kernel are injected during
# the image stage, not the OpenWrt rootfs stage, to avoid 6.6-vs-6.1 mismatches.
cat > "${ROCKCHIP_EXTRA_CONFIG}" <<'EOL'
CONFIG_PACKAGE_amneziawg-tools=y
CONFIG_PACKAGE_luci-proto-amneziawg=y
EOL

ln -sfn ../rockchip/99-codex-native-vpn "${ROCKCHIP_DOCKER_SHARED_LINK}"

cat > "${ROCKCHIP_DOCKER_EXTRA_CONFIG}" <<'EOL'
CONFIG_PACKAGE_docker=y
EOL
# }}
