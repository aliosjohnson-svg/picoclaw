#
# Copyright (C) 2024 Sipeed
# SPDX-License-Identifier: MIT
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-picoclaw
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Sipeed <support@sipeed.com>
PKG_LICENSE:=MIT

LUCI_TITLE:=LuCI support for PicoClaw AI Agent
LUCI_DEPENDS:=+picoclaw
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-picoclaw/description
  LuCI web interface for configuring the PicoClaw AI agent.
  Provides controls for API token, model selection, and gateway settings.
endef

$(eval $(call BuildPackage,luci-app-picoclaw))
