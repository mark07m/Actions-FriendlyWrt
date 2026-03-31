# CODex Summary

## Changed files

- `.github/workflows/build.yml`
  - The rootfs stage now initializes from `rk3588.xml` instead of `rk3399.xml`.
  - The rootfs stage now sources `device/friendlyelec/rk3588/rk3588_docker.mk` so the package/rootfs layout matches the NanoPi R6S image pipeline.
  - The image stage now runs `scripts/3rd/add_amneziawg.sh` after `./build.sh kernel` so `amneziawg.ko` is compiled against the real FriendlyARM RK3588 vendor kernel.

- `scripts/add_packages.sh`
  - Still vendors `amneziawg-tools` and `luci-proto-amneziawg` into the FriendlyWrt tree.
  - No longer selects OpenWrt-side `kmod-amneziawg` or duplicate `kmod-r8125` in the rootfs stage, because those would be built for the OpenWrt `6.6.110` kernel instead of the runtime NanoPi R6S kernel.

- `scripts/3rd/add_amneziawg.sh`
  - New script.
  - Builds `amneziawg.ko` from the vendored AmneziaWG patch set against the actual `project/kernel` tree used by the NanoPi R6S image stage.
  - Copies the module into `out/output_*_kmodules/lib/modules/$(kernelrelease)/`.
  - Runs `depmod -b` on the staged kmodules tree so runtime module indexes are refreshed for the same kernel release.

- `packages/amneziawg-openwrt/amneziawg-tools/files/amneziawg.sh`
  - Removes the broken `proto_amneziawg_check_installed` teardown call.
  - Makes teardown clean up the same `/var/run/wireguard/${config}.sock` path used by setup.
  - Stops teardown from aborting interface bring-up on a missing helper function.

- `packages/amneziawg-openwrt/amneziawg-tools/Makefile`
  - `PKG_RELEASE` bumped to `2` for the netifd helper fix.

- `packages/amneziawg-openwrt/kmod-amneziawg/Makefile`
- `packages/amneziawg-openwrt/kmod-amneziawg/files/000-initial-amneziawg.patch`
  - Previous build fixes are retained: portable `Build/Prepare`, idempotent patch application, and a patch rebased for FriendlyARM `nanopi6-v6.1.y`.

## Root cause: kernel mismatch

- The rootfs build stage compiles packages inside `project/friendlywrt`, which is the FriendlyWrt/OpenWrt tree for `rockchip/armv8`.
- In that tree, `target/linux/rockchip/Makefile` uses `KERNEL_PATCHVER:=6.6`, so OpenWrt kernel packages are produced for `6.6.110`.
- The final NanoPi R6S SD image does not boot that OpenWrt kernel. The image stage boots the separate FriendlyARM RK3588 vendor kernel from manifest `rk3588.xml`, branch `kernel-rockchip:nanopi6-v6.1.y`, which produces runtime `uname -r = 6.1.141`.
- Because `kmod-amneziawg` was previously selected in the rootfs stage, it got installed into `/lib/modules/6.6.110/` inside the image, which can never satisfy runtime `modprobe` on a system booted with `6.1.141`.

## Root cause: missing proto_amneziawg_check_installed

- `packages/amneziawg-openwrt/amneziawg-tools/files/amneziawg.sh` called `proto_amneziawg_check_installed` in `proto_amneziawg_teardown()`.
- That function was not defined anywhere in the AmneziaWG helper and is not provided by the sourced netifd helpers here.
- The helper was also internally inconsistent: setup removed `/var/run/wireguard/${config}.sock`, while teardown tried to remove `/var/run/amneziawg/${config}.sock`.
- Result: `ifup`/reload paths could hit teardown first, explode on the undefined helper, and then fall through into the misleading “install kmod or amneziawg-go” message.

## Exact fixes made

- Rootfs-stage OpenWrt kernel module selection for AmneziaWG was removed.
  - The next image will no longer embed the wrong `6.6.110` `kmod-amneziawg` package in the rootfs.

- AmneziaWG kernel module building moved to the image stage.
  - `scripts/3rd/add_amneziawg.sh` now compiles the module after the FriendlyARM RK3588 kernel is built.
  - Local validation proved the script places `amneziawg.ko` into:
    - `out/output_mock_kmodules/lib/modules/6.1.141/amneziawg.ko`
  - The same validation also produced fresh:
    - `modules.dep`
    - `modules.alias`
    - `modules.symbols`
    - their `*.bin` companions

- The netifd proto helper was fixed.
  - Teardown no longer references `proto_amneziawg_check_installed`.
  - Teardown now mirrors the upstream `wireguard.sh` pattern and simply removes the interface plus the correct socket path.

- The rootfs stage is now aligned to the RK3588 device context.
  - This keeps the NanoPi R6S build path consistent across rootfs and image stages instead of mixing `rk3399` rootfs metadata with `rk3588` image output.

## Why the next image should work on the real router

- The image will stop carrying the wrong OpenWrt-side `kmod-amneziawg` built for `6.6.110`.
- The image stage will inject `amneziawg.ko` for the actual NanoPi R6S runtime kernel release returned by `make kernelrelease` from the FriendlyARM RK3588 kernel tree.
- Local validation confirmed that the new script stages the module under `lib/modules/6.1.141/`, which is the same form required by runtime `uname -r`.
- The generated module index files mean `modprobe amneziawg` has the expected runtime metadata in the correct kernel directory.
- The netifd proto helper no longer contains the undefined `proto_amneziawg_check_installed` call, so `ifup awg_nl` should not die on that missing function anymore.

## Verification done

- `bash -n` passed for:
  - `scripts/add_packages.sh`
  - `scripts/custome_config.sh`
  - `scripts/custome_kernel_config.sh`
  - `scripts/3rd/add_r8125.sh`
  - `scripts/3rd/add_amneziawg.sh`

- `sh -n` passed for:
  - `packages/amneziawg-openwrt/amneziawg-tools/files/amneziawg.sh`

- Workflow YAML parsed successfully.

- Grep verification in the repo confirms:
  - rootfs stage uses `rk3588.xml`
  - rootfs stage uses `rk3588_docker.mk`
  - image stage runs `add_amneziawg.sh`
  - rootfs-stage config still selects:
    - `docker`
    - `amneziawg-tools`
    - `luci-proto-amneziawg`
  - rootfs-stage config no longer selects:
    - `kmod-amneziawg`
    - `kmod-r8125`
  - `amneziawg.sh` no longer references:
    - `proto_amneziawg_check_installed`
    - `/var/run/amneziawg/...`

- Linux-container validation of the new image-stage module script succeeded.
  - The script built `amneziawg.ko` against FriendlyARM `nanopi6-v6.1.y`.
  - The script staged the module into `lib/modules/6.1.141/`.
  - The staged tree contains `modules.dep*`, `modules.alias*`, and `modules.symbols*`.

## Still not fully hardware-verified here

- I cannot boot the new SD image on your physical NanoPi R6S from inside this workspace.
- The remaining real-device checks still need one fresh flash of the next image:
  - `uname -r`
  - `/lib/modules/$(uname -r)/amneziawg.ko`
  - `modprobe amneziawg`
  - `lsmod | grep amneziawg`
  - `ifup awg_nl`
  - `ifstatus awg_nl`

## Trigger and artifact

- Trigger the workflow from GitHub Actions using `build`.
- Download and flash:
  - `NanoPi-R6S-FriendlyWrt-24.10-docker.img.gz`
