-- LuCI CBI model for PicoClaw AI Agent
-- SPDX-License-Identifier: MIT

local sys    = require "luci.sys"
local util   = require "luci.util"

m = Map("picoclaw", translate("PicoClaw AI Agent"),
	translate("PicoClaw is an ultra-lightweight personal AI assistant. " ..
	          "Configure your LLM provider and start the gateway service."))

-- ─── Service Control ──────────────────────────────────────────────────────────
s = m:section(TypedSection, "picoclaw", translate("Service"))
s.anonymous = true
s.addremove = false

-- Status indicator (read-only)
local running = (sys.call("pidof picoclaw >/dev/null 2>&1") == 0)
local status_html = running
	and '<span style="color:green;font-weight:bold">&#9679; ' .. translate("Running") .. '</span>'
	or  '<span style="color:red;font-weight:bold">&#9679; ' .. translate("Stopped") .. '</span>'

o = s:option(DummyValue, "_status", translate("Status"))
o.rawhtml = true
o.default = status_html

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

-- ─── LLM Provider & Model ─────────────────────────────────────────────────────
s2 = m:section(TypedSection, "picoclaw", translate("Model Configuration"))
s2.anonymous = true
s2.addremove = false

o = s2:option(ListValue, "provider", translate("Provider"))
o:value("anthropic",     "Anthropic (Claude)")
o:value("openai",        "OpenAI (GPT)")
o:value("deepseek",      "DeepSeek")
o:value("longcat",       "LongCat")
o:value("openai_compat", translate("Custom (OpenAI-compatible)"))
o.default = "anthropic"

o = s2:option(ListValue, "model", translate("Model"))
-- Anthropic
o:value("claude-sonnet-4.6",  "Claude Sonnet 4.6 (Anthropic)")
o:value("claude-opus-4-6",    "Claude Opus 4.6 (Anthropic)")
o:value("claude-haiku-4-5",   "Claude Haiku 4.5 (Anthropic)")
-- OpenAI
o:value("gpt-4o",             "GPT-4o (OpenAI)")
o:value("gpt-4o-mini",        "GPT-4o Mini (OpenAI)")
o:value("gpt-5.4",            "GPT-5.4 (OpenAI)")
-- DeepSeek
o:value("deepseek-chat",      "DeepSeek Chat")
o:value("deepseek-reasoner",  "DeepSeek Reasoner")
-- LongCat
o:value("LongCat-Flash-Thinking", "LongCat Flash Thinking")
-- Custom
o:value("custom",             translate("Custom model name (set below)"))
o.default = "claude-sonnet-4.6"

-- Custom model name text box (shown when model == "custom")
o = s2:option(Value, "_model_custom", translate("Custom Model Name"))
o.placeholder = "e.g. my-provider/my-model-v1"
o:depends("model", "custom")
o.cfgvalue = function(self, section)
	local m_val = m.uci:get("picoclaw", section, "model") or ""
	-- If the stored value is not one of the predefined list entries, show it here
	local predefined = {
		"claude-sonnet-4.6","claude-opus-4-6","claude-haiku-4-5",
		"gpt-4o","gpt-4o-mini","gpt-5.4",
		"deepseek-chat","deepseek-reasoner",
		"LongCat-Flash-Thinking","custom"
	}
	for _, v in ipairs(predefined) do
		if m_val == v then return "" end
	end
	return m_val
end
o.write = function(self, section, value)
	if value and value ~= "" then
		m.uci:set("picoclaw", section, "model", value)
	end
end

o = s2:option(Value, "api_key", translate("API Key"))
o.password = true
o.placeholder = "sk-..."
o.rmempty = false

o = s2:option(Value, "api_base", translate("API Base URL"))
o.placeholder = translate("Leave empty to use provider default")
o.rmempty = true
o.description = translate("Required for custom/self-hosted deployments. " ..
	"Example: https://my-proxy.example.com/v1")

-- ─── Gateway Settings ─────────────────────────────────────────────────────────
s3 = m:section(TypedSection, "picoclaw", translate("Gateway Settings"))
s3.anonymous = true
s3.addremove = false

o = s3:option(Value, "gateway_host", translate("Listen Address"))
o.placeholder = "0.0.0.0"
o.default     = "0.0.0.0"
o.description = translate(
	"<b>0.0.0.0</b> — accept connections from any interface (external access)<br/>" ..
	"<b>127.0.0.1</b> — local connections only")

o = s3:option(Value, "gateway_port", translate("Listen Port"))
o.datatype = "port"
o.default  = "18790"

o = s3:option(ListValue, "log_level", translate("Log Level"))
o:value("debug", "Debug")
o:value("info",  "Info")
o:value("warn",  "Warn")
o:value("error", "Error")
o.default = "info"

o = s3:option(Value, "data_dir", translate("Data Directory"))
o.placeholder = "/var/lib/picoclaw"
o.default     = "/var/lib/picoclaw"
o.description = translate("Storage location for workspace, memory, and database files.")

-- ─── Actions ─────────────────────────────────────────────────────────────────
s4 = m:section(TypedSection, "picoclaw", translate("Actions"))
s4.anonymous = true
s4.addremove = false

o = s4:option(DummyValue, "_actions", "")
o.rawhtml = true
o.default = [[
<div style="margin-top:4px">
  <button class="btn cbi-button cbi-button-apply"
          onclick="window.location.href=']] ..
    luci.dispatcher.build_url("admin","services","picoclaw","status") ..
    [[';return false">]] .. translate("Check Status") .. [[</button>
  &nbsp;
  <button class="btn cbi-button cbi-button-positive"
          onclick="fetch('/cgi-bin/luci/admin/services/picoclaw/status')
            .then(r=>r.json())
            .then(d=>alert('Running: '+d.running));return false">
    ]] .. translate("Refresh Status") .. [[
  </button>
</div>
]]

return m
