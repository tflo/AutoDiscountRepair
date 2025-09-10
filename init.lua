-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...
A.debug = true

local _


local defaults = {
	['default_guildmoney_preferred'] = false,
	['default_guildmoney_only'] = false,
	['show_increased_costs'] = true,
	['discount_threshold'] = 20,
	['increased_costs_threshold'] = 10 * 1e4,
	['show_repairsummary'] = true,
}
_G['DB_8552E721_B117_473D_A2D1_3D0939A5338A'] =
	setmetatable(_G['DB_8552E721_B117_473D_A2D1_3D0939A5338A'] or {}, { __index = defaults })
local db = _G['DB_8552E721_B117_473D_A2D1_3D0939A5338A']
A.db = db

A.CLR_ADDON = BLUE_FONT_COLOR
A.CLR_NEUTRAL = LIGHTYELLOW_FONT_COLOR
A.CLR_GOOD = GREEN_FONT_COLOR
A.CLR_KEY = HIGHLIGHT_LIGHT_BLUE
A.CLR_ATTN = ORANGE_FONT_COLOR
A.CLR_BAD = RED_FONT_COLOR
A.CLR_DEBUG = EXPANSION_COLOR_13
A.ADDONNAME_SHORT = 'ADR'
A.ADDONNAME_LONG = myname

A.PREFIX_SHORT = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_SHORT) .. ': '
A.PREFIX_LONG = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_LONG) .. ': '
