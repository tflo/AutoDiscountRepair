-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...
local myprettyname = C_AddOns.GetAddOnMetadata(myname, "Title")
local DB_ID = 'DB_8552E721_B117_473D_A2D1_3D0939A5338A'

-- Blizz
local format = format

--[[===========================================================================
	SV and defaults
===========================================================================]]--

-- Note that we have `LoadSavedVariablesFirst: 1` in the toc, so no need to wait for ADDON_LOADED

local DB_VERSION_CURRENT = 1

local defaults = {
	['default_guildmoney_preferred'] = false,
	['default_guildmoney_only'] = false,
	['show_increased_costs'] = true,
	['guilds'] = {},
	['discount_threshold'] = 20,
	['increased_costs_threshold'] = 5 * 1e4,
	['increased_costs_sound'] = true,
	['show_repairsummary'] = true,
	['auto_repair'] = true,
	['debugmode'] = false,
	['db_version'] = DB_VERSION_CURRENT,
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

-- DB cleanup, once necessary
-- if not db.db_version or db.db_version < DB_VERSION_CURRENT then
-- 	-- clean up old keys
-- end
-- db.db_version = DB_VERSION_CURRENT


--[[===========================================================================
	Helpers
===========================================================================]]--

local function color_text(text, color)
	return color:WrapTextInColorCode(tostring(text))
end

local function key_txt(text) return color_text(text, A.CLR_KEY) end
local function addon_txt(text) return color_text(text, A.CLR_ADDON) end
local function neutral_txt(text) return color_text(text, A.CLR_NEUTRAL) end
local function attn_txt(text) return color_text(text, A.CLR_ATTN) end
local function bad_txt(text) return color_text(text, A.CLR_BAD) end
local function good_txt(text) return color_text(text, A.CLR_GOOD) end

A.key_txt = key_txt
A.attn_txt = attn_txt
A.good_txt = good_txt

function A.addonmsg(text, color)
	local color = color or A.CLR_NEUTRAL
	print(A.PREFIX_SHORT .. color:WrapTextInColorCode(text))
end

function A.addonmessage(text, color)
	local color = color or A.CLR_NEUTRAL
	print(A.PREFIX_LONG .. color:WrapTextInColorCode(text))
end

function A.debugprint(text)
	if not db.debugmode then return end
	print(A.PREFIX_SHORT .. A.CLR_DEBUG:WrapTextInColorCode(text))
end


--[[===========================================================================
	Constants
===========================================================================]]--

A.CLR_ADDON = HIGHLIGHT_LIGHT_BLUE
A.CLR_NEUTRAL = LIGHTYELLOW_FONT_COLOR
A.CLR_GOOD = GREEN_FONT_COLOR
A.CLR_KEY = BLUE_FONT_COLOR
A.CLR_ATTN = ORANGE_FONT_COLOR
A.CLR_BAD = RED_FONT_COLOR
A.CLR_DEBUG = EXPANSION_COLOR_13
A.ADDONNAME_SHORT = 'ADR'
A.ADDONNAME_LONG = myprettyname

A.PREFIX_SHORT = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_SHORT) .. ': '
A.PREFIX_LONG = A.CLR_ADDON:WrapTextInColorCode(A.ADDONNAME_LONG) .. ': '

A.REPAIR_COST_UPDATE_DELAY = 1

A.GUILD_RETRY_DELAY = 20
A.GUILD_RETRY_MAX = 3

local INF_NEG = -math.huge
-- { greater than diff in Gold, Sound ID }
A.SOUNDS_INCREASED_COSTS = {
	{10, 2174245},
	{5, 1272544},
	{1, 1237429},
	{0, 568056},
	{INF_NEG, 1451467}, -- costs have decreased
}

A.DISCOUNT_MAX = 20
A.DISCOUNT_TOLERANCE = 0.01
A.DISCOUNTS = {
	[0] = 'FF0000',
	[5] = 'FFA500',
	[10] = 'FFD700',
	[15] = '00FFFF',
	[A.DISCOUNT_MAX] = '00FF00',
}


--[[===========================================================================
	Messages
===========================================================================]]--

local L = {}

L.MSGS_NOREPAIR = {
	'No repairs needed. Come back after some real action.',
	'No repairs needed. Maybe go lose a life and try again?',
	'No repairs needed. Get a little roughed up first.',
	'No repairs needed. Take a hit or two and come back.',
	'No repairs needed. Time to take some hits.',
	'No repairs needed. Seems like you\'ve been careful out there.',
	'No repairs needed. Can’t fix perfection.',
	'No repairs needed. Have you been dodging on purpose?',
	'No repairs needed. Did you let your pet do the tanking again?',
	'No repairs needed. Maybe the enemies are scared of scratching your gear.',
	'No repairs needed. Was that quest just a brisk walk?',
	'No repairs needed. Maybe time for some reckless delves?',
	'No repairs needed. Even your boots look bored.',
	'No repairs needed. Still looks fresh from the forge.',
	'No repairs needed. Were you fighting or sightseeing?',
}

-- Guild
L.NO_GUILD_INFO = '\nWARNING: Guild info unavailable (try %s/' .. A.GUILD_RETRY_MAX .. '); possible server lag.\n— Retrying in ' .. A.GUILD_RETRY_DELAY .. ' seconds.\n— Auto-repairs you’ll do now will be paid with your personal funds!'
L.NO_GUILD_INFO_FINAL = '\nFINAL WARNING: Guild data not retrieved; probably server lag.\n— Please wait, then reload or relog.\n— All auto-repairs will be paid with your personal funds until reload or relog!'
-- Costs
L.COSTS_INVENTORY_TOTAL = 'Inventory (= total) repair costs: %s (%s%s)'
L.COSTS_BAGS_TOTAL = 'Bags (= total) repair costs: %s (%s%s)'
L.COSTS_INVENTORY = 'Inventory repair costs: %s (%s%s)'
L.COSTS_BAGS = 'Bags repair costs: %s (%s%s)'
L.COSTS_TOTAL = 'Total repair costs: %s (%s%s)'
-- Merchant
L.REPAIR_IMPOSSIBLE = attn_txt('For some reason, you currently cannot repair here.')
L.CALCULATION_MISMATCH = 'We have a calculation mismatch: the computed discount of %s%% does not match any nominal discount (0%%, 5%%, 10%%, 15%%, 20%%)! Probably our last record of the standard repair costs is not accurate or outdated. Aborting auto-repair! (You may try to restart interaction with the merchant.)'
L.REPAIR_SUCCESS = 'Repaired for %s (%s discount)'
L.REPAIR_FAILURE_GUILD = 'Your gear was not (or not entirely) repaired. This is probably because of your ' .. attn_txt('guildonly') .. ' setting.'
L.REPAIR_FAILURE = 'Your gear was not (or not entirely) repaired. Did you run out of money?'
L.DISCOUNT_TOO_LOW = 'Not enough discount here: %s – %s = %s'
L.REPAIR_OFF = 'Auto-repair is disabled!\n— You could repair here for: %s – %s = %s'
-- Config
L.CFG_NOGUILD = format('%s --> cannot change or set guild settings. If you think this char is in a guild, try to reload the UI.', bad_txt('No guild registered for this char'))
L.CFG_GUILD_PREF = 'Prefer guild funds for auto-repairs: %s'
L.CFG_GUILD_ONLY = 'Use exclusively guild funds for auto-repairs: %s'
L.CFG_COSTS_PRINT = 'Print the current repair costs when they increase: %s'
L.CFG_SUMMARY = 'Print summary at merchant: %s'
L.CFG_COSTS_SOUND = 'Play a sound when increased repair costs are printed: %s'
L.CFG_DISCOUNT_THRESH = 'Discount threshold: %s'
L.CFG_COSTS_THRESH = 'Minimum cost increase to print a new message: %s Gold'
L.CFG_REPAIR = 'Auto-repair enabled: %s (auto-enabled at login)'
L.CFG_INVALID = format('%s Type %s for a list of arguments.', bad_txt('Invalid argument(s).'), key_txt('/adr help'))
L.CFG_DEBUG = 'Debug mode: %s'
-- Help
L.HELP_HEADING = format('%s Help:', addon_txt(A.ADDONNAME_LONG))
L.HELP_INTRO = format('%s accepts these arguments [type; current value (default)]:', key_txt('/adr'))
L.HELP_GUILD_PREF = key_txt('guild') .. ' : Prefer guild funds for auto-repairs [toggle; %s (%s)].'
L.HELP_GUILD_ONLY = key_txt('guildonly') .. ' : Use exclusively guild funds for auto-repairs [toggle; %s (%s)]. If enabled, this implies "Prefer guild funds".'
L.HELP_DISCOUNT_THRESH = key_txt('0%%||5%%||10%%||15%%||20%%||max') .. ' : Discount threshold [percent; %s (%s%%)].'
L.HELP_SUMMARY = key_txt('summary') .. ' : Print summary at repair merchant [toggle; %s (%s)].'
L.HELP_COSTS_PRINT = key_txt('costs') .. ' : Print the current repair costs when they increase [toggle; %s (%s)].'
L.HELP_COSTS_THRESH = key_txt('<number>') .. ' : Minimum cost increase to print a new message [difference in Gold; %s (%s)]. This requires the ' .. key_txt('costs') .. ' option to be enabled.'
L.HELP_COSTS_SOUND = key_txt('sound') .. ' : Play a sound when increased repair costs are printed [toggle; %s (%s)]. This requires the ' .. key_txt('costs') .. ' option to be enabled.'
L.HELP_HELP = format('%s or %s : Print this help text.', key_txt('help'), key_txt('h'))
L.HELP_REPAIR = key_txt('repair') .. ' : Auto-repair [toggle; %s (%s)]. Auto-enabled at login.'
L.HELP_DEBUG = key_txt('dm') .. ' : Debug mode [toggle; %s (%s)]. Enable only when needed.'

L.BLOCK_SEP = addon_txt('++++++++++++++++++++++++++++++++++++++++++')

A.L = L
