-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...
local myprettyname = C_AddOns.GetAddOnMetadata(myname, "Title")

local _


local defaults = {
	['default_guildmoney_preferred'] = false,
	['default_guildmoney_only'] = false,
	['show_increased_costs'] = true,
	['discount_threshold'] = 20,
	['increased_costs_threshold'] = 5 * 1e4,
	['increased_costs_sound'] = true,
	['show_repairsummary'] = true,
	['debugmode'] = false,
}
_G['DB_8552E721_B117_473D_A2D1_3D0939A5338A'] =
	setmetatable(_G['DB_8552E721_B117_473D_A2D1_3D0939A5338A'] or {}, { __index = defaults })
local db = _G['DB_8552E721_B117_473D_A2D1_3D0939A5338A']
A.db = db
A.defaults = defaults

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

-- { greater than diff in Gold, Sound ID }
A.SOUNDS_INCREASED_COSTS = {
	{10, 2174245},
	{5, 1272544},
	{1, 1237429},
	{0, 568056},
	{-math.huge, 1451467}, -- costs have decreased
}


