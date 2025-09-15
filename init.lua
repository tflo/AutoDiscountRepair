-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...
local myprettyname = C_AddOns.GetAddOnMetadata(myname, "Title")
local DB_ID = 'DB_8552E721_B117_473D_A2D1_3D0939A5338A'
local _


--[[===========================================================================
	SV and defaults
===========================================================================]]--

-- Note that we have `LoadSavedVariablesFirst: 1` in the toc, so no need to wait for ADDON_LOADED

local defaults = {
	['default_guildmoney_preferred'] = false,
	['default_guildmoney_only'] = false,
	['show_increased_costs'] = true,
	['guilds'] = {},
	['discount_threshold'] = 20,
	['increased_costs_threshold'] = 5 * 1e4,
	['increased_costs_sound'] = true,
	['show_repairsummary'] = true,
	['debugmode'] = false,
}

local function merge_defaults(src, dst)
	for k, v in pairs(src) do
		local dst_val = dst[k]
		if type(v) == 'table' then
			if type(dst_val) ~= 'table' then
				dst_val = {}
				dst[k] = dst_val
			end
			merge_defaults(v, dst_val)
		elseif type(dst_val) ~= type(v) then
			dst[k] = v
		end
	end
end

_G[DB_ID] = _G[DB_ID] or {}
merge_defaults(defaults, _G[DB_ID])
local db = _G[DB_ID]
A.db = db
A.defaults = defaults


--[[===========================================================================
	Constants
===========================================================================]]--

A.CLR_ADDON = BLUE_FONT_COLOR
A.CLR_NEUTRAL = LIGHTYELLOW_FONT_COLOR
A.CLR_GOOD = GREEN_FONT_COLOR
A.CLR_KEY = HIGHLIGHT_LIGHT_BLUE
A.CLR_ATTN = ORANGE_FONT_COLOR
A.CLR_BAD = RED_FONT_COLOR
A.CLR_DEBUG = EXPANSION_COLOR_13
A.ADDONNAME_SHORT = 'ADR'
A.ADDONNAME_LONG = myprettyname

A.PREFIX_SHORT = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_SHORT) .. ': '
A.PREFIX_LONG = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_LONG) .. ': '

local INF_NEG = -math.huge
-- { greater than diff in Gold, Sound ID }
A.SOUNDS_INCREASED_COSTS = {
	{10, 2174245},
	{5, 1272544},
	{1, 1237429},
	{0, 568056},
	{INF_NEG, 1451467}, -- costs have decreased
}

A.DISCOUNTS = {
	[0] = 'FF0000',
	[5] = 'FFA500',
	[10] = 'FFD700',
	[15] = '00FFFF',
	[20] = '00FF00',
}

A.MSGS_NOREPAIR = {
	'No repairs needed. Come back after some real action.',
	'No repairs needed. Maybe go lose a life and try again?',
	'No repairs needed. Get a little roughed up first.',
	'No repairs needed. Take a hit or two and come back.',
	'No repairs needed. Take a hit or two and come back.',
	'No repairs needed. Take some hits and come back.',
	'No repairs needed. Seems like you\'ve been careful out there.',
}

