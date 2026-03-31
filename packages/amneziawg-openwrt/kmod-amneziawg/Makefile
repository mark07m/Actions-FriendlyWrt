include $(TOPDIR)/rules.mk

include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kmod-amneziawg
PKG_VERSION:=0.0.1
PKG_RELEASE:=3

include $(INCLUDE_DIR)/package.mk

define KernelPackage/amneziawg
	SECTION:=kernel
	CATEGORY:=Kernel Modules
	SUBMENU:=Network Support
	URL:=https://amnezia.org/
	MAINTAINER:=Amnezia Admin <admin@amnezia.org>
	TITLE:=AmneziaWG Kernel Module
	FILES:=$(PKG_BUILD_DIR)/amneziawg.ko
	DEPENDS:= \
		+kmod-udptunnel4 \
		+kmod-udptunnel6 \
		+kmod-crypto-lib-chacha20poly1305 \
		+kmod-crypto-lib-curve25519
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/selftest
	cp -fp $(LINUX_DIR)/drivers/net/wireguard/*.c $(PKG_BUILD_DIR)/
	cp -fp $(LINUX_DIR)/drivers/net/wireguard/*.h $(PKG_BUILD_DIR)/
	cp -a $(LINUX_DIR)/drivers/net/wireguard/selftest/. $(PKG_BUILD_DIR)/selftest/
	mkdir -p $(PKG_BUILD_DIR)/uapi
	for patch in files/*.patch; do \
		patch -d $(PKG_BUILD_DIR)/ -F3 -N -t -p0 -i "$$$$(pwd)/$$$${patch}"; \
	done
	cp -f src/Makefile $(PKG_BUILD_DIR)
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(BUILDFLAGS)" \
		modules
endef

$(eval $(call KernelPackage,amneziawg))
