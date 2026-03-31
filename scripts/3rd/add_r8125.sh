#!/bin/bash
set -eu
top_path=$(pwd)
toolchain_dir="${TOOLCHAIN_DIR:-/opt/FriendlyARM/toolchain/11.3-aarch64/bin}"
cross_compile="${CROSS_COMPILE:-aarch64-linux-gnu-}"
r8125_repo="${R8125_REPO:-https://github.com/zeroday0619/r8125}"
r8125_branch="${R8125_BRANCH:-main}"
r8125_src_dir="${top_path}/r8125-src"

# prepare toolchain and get the kernel version
[ -d "${toolchain_dir}" ] && export PATH="${toolchain_dir}:$PATH"
pushd kernel >/dev/null
    kernel_ver=$(make CROSS_COMPILE="${cross_compile}" ARCH=arm64 kernelrelease)
popd
kmodules_root=$(readlink -f ./out/output_*_kmodules)
modules_dir="${kmodules_root}/lib/modules/${kernel_ver}"
[ -d "${modules_dir}" ] || {
	echo "please build kernel first."
	exit 1
}

# build kernel driver
rm -rf "${r8125_src_dir}"
git clone --depth 1 "${r8125_repo}" -b "${r8125_branch}" "${r8125_src_dir}"
pushd "${r8125_src_dir}/src" >/dev/null
	make ARCH=arm64 CROSS_COMPILE="${cross_compile}" -C "${top_path}/kernel" M="$(pwd)" modules
	"${cross_compile}strip" --strip-unneeded r8125.ko
	cp r8125.ko "${modules_dir}/"
popd >/dev/null

if command -v depmod >/dev/null 2>&1; then
	depmod -b "${kmodules_root}" "${kernel_ver}" || true
fi

# prepare rootfs overlay
tmp_dir="${top_path}/r8125-files/etc/modules.d/"
mkdir -p "${tmp_dir}"
echo "r8125" > "${tmp_dir}/10-r8125"
echo "FRIENDLYWRT_FILES+=(r8125-files)" >> .current_config.mk

rm -rf "${r8125_src_dir}"
