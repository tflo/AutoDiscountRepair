-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...

local _


local defaults = {
	['default_guildmoney_preferred'] = false,
	['default_guildmoney_only'] = false,
	['show_increased_costs'] = true,
	['discount_threshold'] = 20,
	['increased_costs_threshold'] = 10 * 1e4,
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
A.ADDONNAME_LONG = myname

A.PREFIX_SHORT = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_SHORT) .. ': '
A.PREFIX_LONG = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_LONG) .. ': '

-- 3744065 Bonesmith Heirmir: Wield your weapon, I keep my hammer.
-- 3722967 Wounded dog, short.
-- 568056 Glass breaking
-- ui_warforged_item_toast_banner.ogg#1237429
-- ui_70_artifact_forge_relic_place_03.ogg#1272544 ; "artifact_forge" has more nice variants
-- sound/music/battleforazeroth/rtc_80_ard_anvil_strike.ogg#2174245 ; nice one!
A.SOUND_INCREASED_COSTS_1 = 568056
A.SOUND_INCREASED_COSTS_2 = 2174245
A.SOUND_INCREASED_COSTS_3 = 3744065
