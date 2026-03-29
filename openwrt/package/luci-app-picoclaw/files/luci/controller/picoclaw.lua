-- LuCI controller for PicoClaw AI Agent
-- SPDX-License-Identifier: MIT

module("luci.controller.picoclaw", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/picoclaw") then
		return
	end

	local page = entry(
		{"admin", "services", "picoclaw"},
		cbi("picoclaw/picoclaw"),
		_("PicoClaw AI Agent"),
		10
	)
	page.dependent = true
	page.acl_depends = { "luci-app-picoclaw" }

	entry(
		{"admin", "services", "picoclaw", "status"},
		call("action_status")
	).leaf = true
end

function action_status()
	local sys   = require "luci.sys"
	local uci   = require "luci.model.uci".cursor()
	local enabled = uci:get("picoclaw", "picoclaw", "enabled") or "0"
	local running = (sys.call("pidof picoclaw >/dev/null 2>&1") == 0)

	luci.http.prepare_content("application/json")
	luci.http.write('{"running":' .. (running and "true" or "false") ..
		',"enabled":' .. (enabled == "1" and "true" or "false") .. '}')
end
