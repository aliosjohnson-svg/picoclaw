#
# Copyright (C) 2024 Sipeed
# SPDX-License-Identifier: MIT
#

include $(TOPDIR)/rules.mk

PKG_NAME:=picoclaw
PKG_VERSION:=0.2.4
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/sipeed/picoclaw/tar.gz/refs/tags/v$(PKG_VERSION)?
PKG_HASH:=skip

PKG_MAINTAINER:=Sipeed <support@sipeed.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/sipeed/picoclaw
GO_PKG_BUILD_PKG:=github.com/sipeed/picoclaw/cmd/picoclaw
GO_PKG_BUILD_TAGS:=goolm stdjson
GO_PKG_LDFLAGS_X:= \
	github.com/sipeed/picoclaw/pkg/config.Version=v$(PKG_VERSION) \
	github.com/sipeed/picoclaw/pkg/config.GitCommit=openwrt-build \
	github.com/sipeed/picoclaw/pkg/config.BuildTime=$(SOURCE_DATE_EPOCH)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/picoclaw
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=AI Tools
  TITLE:=Ultra-lightweight personal AI agent
  URL:=https://github.com/sipeed/picoclaw
  DEPENDS:=$(GO_ARCH_DEPENDS)
  USERID:=picoclaw=1900:picoclaw=1900
endef

define Package/picoclaw/description
  PicoClaw is an ultra-lightweight personal AI assistant and agent framework
  written in pure Go. It supports 30+ LLM providers, 17+ chat channels, and
  runs on minimal hardware (<10MB RAM).

  This package provides the picoclaw gateway service, configurable via UCI
  and the LuCI web interface (requires luci-app-picoclaw).
endef

define Package/picoclaw/conffiles
/etc/config/picoclaw
endef

define Package/picoclaw/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/picoclaw $(1)/usr/bin/picoclaw

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/picoclaw.init $(1)/etc/init.d/picoclaw

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/picoclaw.config $(1)/etc/config/picoclaw

	$(INSTALL_DIR) $(1)/etc/picoclaw
	$(INSTALL_DIR) $(1)/var/lib/picoclaw/workspace
endef

$(eval $(call GoBinPackage,picoclaw))
$(eval $(call BuildPackage,picoclaw))
