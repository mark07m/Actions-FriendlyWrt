# CODex Summary

## What was broken

### 1. Kernel mismatch for `kmod-amneziawg`

- The rootfs build stage compiles packages in `project/friendlywrt`, which is the FriendlyWrt/OpenWrt tree for `rockchip/armv8`.
- In that tree, `target/linux/rockchip/Makefile` uses `KERNEL_PATCHVER:=6.6`, so OpenWrt kernel packages are built for `6.6.110`.
- The final NanoPi R6S SD image does not boot that kernel. The image stage uses the separate FriendlyARM RK3588 vendor kernel from manifest `rk3588.xml`, branch `kernel-rockchip:nanopi6-v6.1.y`, which yields runtime `uname -r = 6.1.141`.
- That is why the old image ended up with `/lib/modules/6.6.110/amneziawg.ko` while the router was booted with `6.1.141`.

### 2. Missing `proto_amneziawg_check_installed`

- `packages/amneziawg-openwrt/amneziawg-tools/files/amneziawg.sh` called `proto_amneziawg_check_installed` in teardown.
- That function was not defined anywhere in the package and is not provided by the sourced netifd helpers here.
- The same script also mixed socket paths: setup used `/var/run/wireguard/${config}.sock`, while teardown tried `/var/run/amneziawg/${config}.sock`.
- Result: `ifup` could hit teardown first, fail on the undefined helper, and then print the misleading “install kmod or amneziawg-go” message.

## Exact repo changes

- `.github/workflows/build.yml`
  - Rootfs stage now initializes from `rk3588.xml` instead of `rk3399.xml`.
  - Rootfs stage now sources `device/friendlyelec/rk3588/rk3588_docker.mk` so the rootfs build matches the NanoPi R6S Docker image path.
  - RK3588 image stage now runs both:
    - `scripts/3rd/add_r8125.sh`
    - `scripts/3rd/add_amneziawg.sh`
  - That means both extra kernel modules are built after `./build.sh kernel`, against the real FriendlyARM vendor kernel used by the final SD image.

- `scripts/add_packages.sh`
  - Keeps `amneziawg-tools` and `luci-proto-amneziawg` selected in the FriendlyWrt rootfs package set.
  - Stops selecting OpenWrt-side `kmod-amneziawg` and `kmod-r8125` in the rootfs stage, because those are tied to the wrong OpenWrt `6.6.110` kernel.
  - Leaves both kernel modules to the RK3588 image stage, where they are built for the real runtime kernel.

- `scripts/3rd/add_amneziawg.sh`
  - New image-stage helper.
  - Reads the real runtime kernel release from `project/kernel`.
  - Builds `amneziawg.ko` against the actual FriendlyARM RK3588 vendor kernel tree.
  - Installs the module into `out/output_*_kmodules/lib/modules/$(kernelrelease)/`.
  - Runs `depmod -b` on the staged module tree so runtime `modprobe amneziawg` can resolve it.

- `scripts/3rd/add_r8125.sh`
  - Activated for RK3588 image builds instead of being left as a commented example.
  - Hardened to use the same runtime-kernel detection pattern as `add_amneziawg.sh`.
  - Builds `r8125.ko` against the same FriendlyARM vendor kernel and refreshes staged module dependency metadata.

- `packages/amneziawg-openwrt/amneziawg-tools/files/amneziawg.sh`
  - Removes the broken `proto_amneziawg_check_installed` call.
  - Makes teardown clean up the same `/var/run/wireguard/${config}.sock` path used by setup.
  - Stops teardown from failing before a normal interface bring-up.

- `packages/amneziawg-openwrt/amneziawg-tools/Makefile`
  - `PKG_RELEASE` bumped to `2` so the fixed proto helper is rebuilt into the image.

- `packages/amneziawg-openwrt/kmod-amneziawg/Makefile`
- `packages/amneziawg-openwrt/kmod-amneziawg/files/000-initial-amneziawg.patch`
  - Previous integration fixes are retained: portable `Build/Prepare`, idempotent patch application, and patch compatibility for FriendlyARM `nanopi6-v6.1.y`.

## Why the next image should work on the real router

- The image will no longer carry the wrong OpenWrt-side `kmod-amneziawg` built for `6.6.110`.
- The image stage now injects `amneziawg.ko` into `/lib/modules/$(real_vendor_kernel_release)/`, which matches the runtime kernel produced for NanoPi R6S.
- Local validation confirmed the new script stages `amneziawg.ko` under `lib/modules/6.1.141/`, which matches the real device report.
- The staged module tree also gets refreshed `modules.dep*`, `modules.alias*`, and `modules.symbols*`, so `modprobe amneziawg` has the right metadata.
- The proto helper no longer references the undefined `proto_amneziawg_check_installed`, so `ifup awg_nl` should stop failing on that missing function.
- `r8125.ko` is now delivered through the same runtime-kernel path, so the final image also keeps the required Realtek 2.5G kernel module aligned with the booted kernel.

## What was pinned

- No new external commit pin was added in this fix set.
- AmneziaWG remains vendored from the repo package tree.
- `r8125` still builds from the existing upstream source repo path, but now through a deterministic image-stage script tied to the actual runtime kernel release.

## Verification done locally

- `bash -n` passed for:
  - `scripts/add_packages.sh`
  - `scripts/custome_config.sh`
  - `scripts/custome_kernel_config.sh`
  - `scripts/3rd/add_r8125.sh`
  - `scripts/3rd/add_amneziawg.sh`

- `sh -n` passed for:
  - `packages/amneziawg-openwrt/amneziawg-tools/files/amneziawg.sh`

- Workflow YAML parsed successfully.

- Grep verification confirms:
  - rootfs stage uses `rk3588.xml`
  - rootfs stage uses `rk3588_docker.mk`
  - image stage runs `add_r8125.sh`
  - image stage runs `add_amneziawg.sh`
  - rootfs-stage config selects:
    - `docker`
    - `amneziawg-tools`
    - `luci-proto-amneziawg`
  - rootfs-stage config no longer selects:
    - `kmod-amneziawg`
    - `kmod-r8125`
  - `amneziawg.sh` no longer references:
    - `proto_amneziawg_check_installed`
    - `/var/run/amneziawg/...`

- Linux-container validation succeeded for the runtime-kernel AmneziaWG path:
  - `amneziawg.ko` built against FriendlyARM `nanopi6-v6.1.y`
  - staged into `lib/modules/6.1.141/`
  - staged tree contains refreshed `modules.dep*`, `modules.alias*`, and `modules.symbols*`

## Remaining risk

- Physical router boot and `ifup` were not executed from inside this workspace.
- One fresh image flash on the real NanoPi R6S is still needed to confirm:
  - `uname -r`
  - `/lib/modules/$(uname -r)/amneziawg.ko`
  - `modprobe amneziawg`
  - `lsmod | grep amneziawg`
  - `ifup awg_nl`
  - `ifstatus awg_nl`

## How to trigger the build

- Go to GitHub Actions and run workflow `build`.

## What to download and flash

- Download:
  - `NanoPi-R6S-FriendlyWrt-24.10-docker.img.gz`
