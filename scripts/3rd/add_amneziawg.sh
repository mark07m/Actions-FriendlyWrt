#!/bin/bash
set -eu

top_path=$(pwd)
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
toolchain_dir="${TOOLCHAIN_DIR:-/opt/FriendlyARM/toolchain/11.3-aarch64/bin}"
cross_compile="${CROSS_COMPILE:-aarch64-linux-gnu-}"

[ -d "${toolchain_dir}" ] && export PATH="${toolchain_dir}:$PATH"

pushd kernel >/dev/null
    kernel_ver=$(make CROSS_COMPILE="${cross_compile}" ARCH=arm64 kernelrelease)
popd >/dev/null

kmodules_root=$(readlink -f ./out/output_*_kmodules)
modules_dir="${kmodules_root}/lib/modules/${kernel_ver}"
[ -d "${modules_dir}" ] || {
	echo "please build kernel first."
	exit 1
}

build_dir="${top_path}/amneziawg-build"
overlay_dir="${top_path}/amneziawg-files/etc/modules.d"
rm -rf "${build_dir}"
mkdir -p "${build_dir}/selftest" "${build_dir}/uapi"

cp -fp kernel/drivers/net/wireguard/*.c "${build_dir}/"
cp -fp kernel/drivers/net/wireguard/*.h "${build_dir}/"
cp -a kernel/drivers/net/wireguard/selftest/. "${build_dir}/selftest/"
patch -d "${build_dir}" -F3 -N -t -p0 \
	-i "${repo_root}/packages/amneziawg-openwrt/kmod-amneziawg/files/000-initial-amneziawg.patch"
cp -f "${repo_root}/packages/amneziawg-openwrt/kmod-amneziawg/src/Makefile" "${build_dir}/Makefile"

make ARCH=arm64 CROSS_COMPILE="${cross_compile}" -C "${top_path}/kernel" M="${build_dir}" modules
"${cross_compile}strip" --strip-unneeded "${build_dir}/amneziawg.ko"
cp -f "${build_dir}/amneziawg.ko" "${modules_dir}/"

if command -v depmod >/dev/null 2>&1; then
	depmod -b "${kmodules_root}" "${kernel_ver}" || true
fi

mkdir -p "${overlay_dir}"
echo "amneziawg" > "${overlay_dir}/30-amneziawg"
if ! grep -q 'amneziawg-files' .current_config.mk 2>/dev/null; then
	echo "FRIENDLYWRT_FILES+=(amneziawg-files)" >> .current_config.mk
fi

rm -rf "${build_dir}"
