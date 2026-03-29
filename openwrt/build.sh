#!/bin/bash
# Build PicoClaw IPK packages for OpenWRT
# Usage: ./build.sh [ARCH]
#
# ARCH options:
#   aarch64  - ARM 64-bit (most modern routers, e.g. RPi 4, NanoPi R5)
#   armv7    - ARM 32-bit hard-float (e.g. Banana Pi, old Raspberry Pi)
#   x86_64   - x86 64-bit (x86 routers, VMs)
#   mipsel   - MIPS little-endian (e.g. TP-Link, older Xiaomi)
#   mips     - MIPS big-endian
#
# Requires: go 1.21+, tar, gzip, binutils (ar)

set -euo pipefail

ARCH="${1:-aarch64}"
VERSION="0.2.4"
PKG_RELEASE="1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$OUT_DIR/build_${ARCH}"
IPK_DIR="$BUILD_DIR/ipk"
PACK_IPK="$SCRIPT_DIR/scripts/pack_ipk.sh"

# Map ARCH to Go cross-compile env + OpenWRT OS_ARCH string
case "$ARCH" in
	aarch64)  GOARCH=arm64;   GOARM="";  GOMIPS="";          OS_ARCH="aarch64_generic" ;;
	armv7)    GOARCH=arm;     GOARM=7;   GOMIPS="";          OS_ARCH="arm_cortex-a7_neon-vfpv4" ;;
	armv6)    GOARCH=arm;     GOARM=6;   GOMIPS="";          OS_ARCH="arm_arm1176jzf-s_vfp" ;;
	x86_64)   GOARCH=amd64;   GOARM="";  GOMIPS="";          OS_ARCH="x86_64" ;;
	mipsel)   GOARCH=mipsle;  GOARM="";  GOMIPS=softfloat;   OS_ARCH="mipsel_24kc" ;;
	mips)     GOARCH=mips;    GOARM="";  GOMIPS=softfloat;   OS_ARCH="mips_24kc" ;;
	mips64)   GOARCH=mips64;  GOARM="";  GOMIPS="";          OS_ARCH="mips64_octeonplus" ;;
	riscv64)  GOARCH=riscv64; GOARM="";  GOMIPS="";          OS_ARCH="riscv64_riscv64" ;;
	*)
		echo "Unknown ARCH: $ARCH"
		echo "Supported: aarch64 armv7 armv6 x86_64 mipsel mips mips64 riscv64"
		exit 1
		;;
esac

PKG_FULL="picoclaw_${VERSION}-${PKG_RELEASE}_${OS_ARCH}"
LUCI_PKG_FULL="luci-app-picoclaw_1.0.0-1_all"

mkdir -p "$IPK_DIR"

# ─── 1. Compile binary ────────────────────────────────────────────────────────
echo "==> Compiling picoclaw for $ARCH (GOARCH=$GOARCH GOARM=${GOARM:-n/a})..."
BINARY="$BUILD_DIR/picoclaw"
(
	cd "$REPO_ROOT"
	env CGO_ENABLED=0 \
	    GOOS=linux \
	    GOARCH="$GOARCH" \
	    ${GOARM:+GOARM=$GOARM} \
	    ${GOMIPS:+GOMIPS=$GOMIPS} \
	go build \
		-trimpath \
		-tags "goolm stdjson" \
		-ldflags "-s -w \
			-X github.com/sipeed/picoclaw/pkg/config.Version=v${VERSION} \
			-X github.com/sipeed/picoclaw/pkg/config.GitCommit=openwrt-build \
			-X github.com/sipeed/picoclaw/pkg/config.BuildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		-o "$BINARY" \
		./cmd/picoclaw
)
echo "    Binary: $BINARY  ($(du -sh "$BINARY" | cut -f1))"

# ─── 2. Build picoclaw IPK ────────────────────────────────────────────────────
echo "==> Assembling picoclaw IPK..."
PKG_DIR="$BUILD_DIR/pkg_picoclaw"
rm -rf "$PKG_DIR"

install -d "$PKG_DIR/usr/bin"
install -d "$PKG_DIR/etc/init.d"
install -d "$PKG_DIR/etc/config"
install -d "$PKG_DIR/etc/picoclaw"

install -m 0755 "$BINARY" \
	"$PKG_DIR/usr/bin/picoclaw"
install -m 0755 "$SCRIPT_DIR/package/picoclaw/files/picoclaw.init" \
	"$PKG_DIR/etc/init.d/picoclaw"
install -m 0600 "$SCRIPT_DIR/package/picoclaw/files/picoclaw.config" \
	"$PKG_DIR/etc/config/picoclaw"

BINARY_SIZE=$(du -sk "$BINARY" | cut -f1)
cat > "$PKG_DIR/control" <<EOF
Package: picoclaw
Version: ${VERSION}-${PKG_RELEASE}
Architecture: ${OS_ARCH}
Maintainer: Sipeed <support@sipeed.com>
Section: utils
Priority: optional
Installed-Size: ${BINARY_SIZE}
Depends:
Description: Ultra-lightweight personal AI agent (gateway mode)
 PicoClaw is a pure-Go AI assistant framework supporting 30+ LLM
 providers and 17+ chat channels with a tiny memory footprint.
EOF

printf '/etc/config/picoclaw\n' > "$PKG_DIR/conffiles"

cat > "$PKG_DIR/postinst" <<'HEREDOC'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -x /etc/init.d/picoclaw ] && /etc/init.d/picoclaw enable
exit 0
HEREDOC
chmod 0755 "$PKG_DIR/postinst"

cat > "$PKG_DIR/prerm" <<'HEREDOC'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -x /etc/init.d/picoclaw ] && {
	/etc/init.d/picoclaw stop    2>/dev/null || true
	/etc/init.d/picoclaw disable 2>/dev/null || true
}
exit 0
HEREDOC
chmod 0755 "$PKG_DIR/prerm"

bash "$PACK_IPK" "$PKG_DIR" "$IPK_DIR/${PKG_FULL}.ipk"

# ─── 3. Build luci-app-picoclaw IPK ──────────────────────────────────────────
echo "==> Assembling luci-app-picoclaw IPK..."
LUCI_SRC="$SCRIPT_DIR/package/luci-app-picoclaw/files"
LUCI_DIR="$BUILD_DIR/pkg_luci"
rm -rf "$LUCI_DIR"

install -d "$LUCI_DIR/usr/lib/lua/luci/controller"
install -d "$LUCI_DIR/usr/lib/lua/luci/model/cbi/picoclaw"
install -d "$LUCI_DIR/usr/lib/lua/luci/i18n"
install -d "$LUCI_DIR/usr/share/luci/acl.d"

install -m 0644 "$LUCI_SRC/luci/controller/picoclaw.lua" \
	"$LUCI_DIR/usr/lib/lua/luci/controller/picoclaw.lua"
install -m 0644 "$LUCI_SRC/luci/model/cbi/picoclaw/picoclaw.lua" \
	"$LUCI_DIR/usr/lib/lua/luci/model/cbi/picoclaw/picoclaw.lua"
install -m 0644 "$LUCI_SRC/luci/i18n/picoclaw.zh-cn.po" \
	"$LUCI_DIR/usr/lib/lua/luci/i18n/picoclaw.zh-cn.po"
install -m 0644 "$LUCI_SRC/luci/acl.d/luci-app-picoclaw.json" \
	"$LUCI_DIR/usr/share/luci/acl.d/luci-app-picoclaw.json"

cat > "$LUCI_DIR/control" <<EOF
Package: luci-app-picoclaw
Version: 1.0.0-1
Architecture: all
Maintainer: Sipeed <support@sipeed.com>
Section: luci
Priority: optional
Installed-Size: 20
Depends: picoclaw, luci-base
Description: LuCI interface for PicoClaw AI Agent
 Provides web UI configuration for API tokens, model selection,
 and gateway settings via the OpenWRT LuCI admin panel.
EOF

cat > "$LUCI_DIR/postinst" <<'HEREDOC'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
rm -f /tmp/luci-indexcache 2>/dev/null || true
[ -f /usr/bin/luci-reload ] && /usr/bin/luci-reload 2>/dev/null || true
exit 0
HEREDOC
chmod 0755 "$LUCI_DIR/postinst"

bash "$PACK_IPK" "$LUCI_DIR" "$IPK_DIR/${LUCI_PKG_FULL}.ipk"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "==> Build complete. Packages:"
ls -lh "$IPK_DIR/"*.ipk
echo ""
echo "Install on router (replace 192.168.1.1 with your router IP):"
echo "  scp $IPK_DIR/*.ipk root@192.168.1.1:/tmp/"
echo "  ssh root@192.168.1.1 \\"
echo "    'opkg install /tmp/${PKG_FULL}.ipk /tmp/${LUCI_PKG_FULL}.ipk'"
echo ""
echo "After install:"
echo "  - Configure via LuCI: Services > PicoClaw AI Agent"
echo "  - Or edit /etc/config/picoclaw and run:"
echo "      /etc/init.d/picoclaw start"
