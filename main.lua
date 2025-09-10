-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...
local myprettyname = C_AddOns.GetAddOnMetadata(myname, "Title")

local debug = true

-- API
local _
local printf = print
-- local wticc = WrapTextInColorCode
local C_TimerAfter = C_Timer.After
local IsInGuild = IsInGuild
local C_TooltipInfoGetInventoryItem = C_TooltipInfo.GetInventoryItem
local C_TooltipInfoGetBagItem = C_TooltipInfo.GetBagItem
local C_ContainerGetContainerNumSlots = C_Container.GetContainerNumSlots
local C_ContainerGetContainerItemDurability = C_Container.GetContainerItemDurability

-- DB
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

-- Console
local function color_text(text, color)
	return color:WrapTextInColorCode(tostring(text))
end

local C_ADDON = BLUE_FONT_COLOR
local C_NEUTRAL = LIGHTYELLOW_FONT_COLOR
local C_GOOD = GREEN_FONT_COLOR
local C_KEY = HIGHLIGHT_LIGHT_BLUE
local C_ATTN = ORANGE_FONT_COLOR
local C_BAD = RED_FONT_COLOR
local C_DEBUG = EXPANSION_COLOR_13
local ADDONNAME_SHORT = 'ADR'
local ADDONNAME_LONG = myname
local function key_txt(text) return color_text(text, C_KEY) end
local function addon_txt(text) return color_text(text, C_ADDON) end
local function neutral_txt(text) return color_text(text, C_NEUTRAL) end
local function attn_txt(text) return color_text(text, C_ATTN) end
local function bad_txt(text) return color_text(text, C_BAD) end
local function good_txt(text) return color_text(text, C_GOOD) end
local PREFIX_SHORT = C_ADDON:WrapTextInColorCode(ADDONNAME_SHORT) .. ': '
local PREFIX_LONG = C_ADDON:WrapTextInColorCode(ADDONNAME_LONG) .. ': '

local function addonmsg(text, color)
	local color = color or C_NEUTRAL
	print(PREFIX_SHORT .. color:WrapTextInColorCode(text))
end
local function addonmessage(text, color)
	local color = color or C_NEUTRAL
	print(PREFIX_LONG .. color:WrapTextInColorCode(text))
end
local function debugprint(text)
if not debug then return end
	print(PREFIX_SHORT .. C_DEBUG:WrapTextInColorCode(text))
end

---

local guild, is_in_guild, get_guild_tries = nil, nil, 0
local function get_guild()
	if IsInGuild() then
		get_guild_tries = get_guild_tries + 1
		is_in_guild = true
		local guild_name, _, _, guild_realm = GetGuildInfo('player')
		guild_realm = guild_realm or GetNormalizedRealmName()
		if not guild_name or not guild_realm then
			debugprint('Player is in guild, but I was unable to retrieve the guild info! (' .. get_guild_tries .. ', ' .. (guild_name or 'NO NAME') .. ', ' .. (guild_realm or 'NO REALM') .. ')')
			if get_guild_tries <= 3 then C_TimerAfter(10, get_guild) end
			return
		end
		guild = guild_name .. '-' .. guild_realm
		debugprint('Guild: ' .. guild .. ' (' .. get_guild_tries .. ')')
		if guild and not db[guild] then
			db[guild] = {
				['guildmoney_preferred'] = db['default_guildmoney_preferred'],
				['guildmoney_only'] = db['default_guildmoney_only'],
			}
			debugprint('guild is new')
		end
	else
		debugprint('IsInGuild() --> false')
	end
end



local repairable_slots = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17 }
local function roundmoney(amount, precision)
	local precision = precision or 'c'
	precision = precision:sub(1, 1)
	if precision == 'c' or amount < 50 then return amount end
	local factor = precision == 'g' and amount >= 5000 and 10000 or 100
	local rounded = floor(amount / factor + 0.5) * factor
	return rounded
end

local function get_repaircosts_inv()
	local total = 0
-- 	local ts_start = GetTimePreciseSec() -- debug
	for _, slot in ipairs(repairable_slots) do
	-- for slot = 1,17 do -- this seems to be even faster
		local durability, max_durability = GetInventoryItemDurability(slot)
		if durability and durability ~= max_durability then
			local data, costs = C_TooltipInfoGetInventoryItem('player', slot), nil
			if data then costs = data.repairCost end
			if costs then total = total + costs end
		end
	end
-- 	local time_spent = GetTimePreciseSec() - ts_start -- debug
-- 	printf('Needed for inventory repair costs:', time_spent) -- debug
	return total
end

local function get_repaircosts_bags()
	local total = 0
-- 	local ts_start = GetTimePreciseSec() -- debug
	for bag = 0, 4 do
		for slot = 1, C_ContainerGetContainerNumSlots(bag) do
			local durability, max_durability = C_ContainerGetContainerItemDurability(bag, slot)
			if durability and durability ~= max_durability then
				local data, costs = C_TooltipInfoGetBagItem(bag, slot), nil
				if data then costs = data.repairCost end
				if costs then total = total + costs end
			end
		end
	end
-- 	local time_spent = GetTimePreciseSec() - ts_start -- debug
-- 	printf('Needed for bags repair costs:', time_spent) -- debug
	return total
end

local get_stdrepaircosts_onhold
-- @ UPDATE_INVENTORY_DURABILITY
function A.get_stdrepaircosts(byusercmd)
	-- If at a merchant, this returns the discounted costs, not the std costs!
	if get_stdrepaircosts_onhold or A.merchant_is_open then return end
	get_stdrepaircosts_onhold = true
	C_TimerAfter(1, function()
		get_stdrepaircosts_onhold = nil
		if A.merchant_is_open then return end
		local stdrepaircosts_inv = get_repaircosts_inv()
		local stdrepaircosts_bags = get_repaircosts_bags()
-- 		stdrepaircosts_bags = 0 -- debug
		local stdrepaircosts = stdrepaircosts_inv + stdrepaircosts_bags
-- 		printf(format('Repair costs updated.')) -- debug
		-- Messages
		if db.show_increased_costs or byusercmd then
			local thresh, round_total, round_diff = db.increased_costs_threshold, 'silver', 'copper'
			local diff, absdiff, inv_displayed, bags_displayed
			-- Inventory
			if not A.last_repaircosts_inv then
				-- First run
				thresh = 0
				A.last_repaircosts_inv = stdrepaircosts_inv
			end
			if byusercmd then thresh = 0 end
			local diff_inv = stdrepaircosts_inv - A.last_repaircosts_inv
			diff = diff_inv
			if diff ~= 0 or thresh == 0 then
				absdiff = abs(diff)
				if absdiff >= thresh then
					inv_displayed = true
					A.last_repaircosts_inv = stdrepaircosts_inv
					addonmsg(format('Inventory repair costs: %s (%s%s)', GetMoneyString(roundmoney(stdrepaircosts_inv, round_total), true), diff >= 0 and '+' or '-', GetMoneyString(roundmoney(absdiff, round_diff), true)))
				end
			end
			-- Bags
			A.last_repaircosts_bags = A.last_repaircosts_bags or stdrepaircosts_bags
			local diff_bags = stdrepaircosts_bags - A.last_repaircosts_bags
			diff = diff_bags
			if diff ~= 0 or thresh == 0 then
				absdiff = abs(diff)
				if absdiff >= thresh then
					bags_displayed = true
					A.last_repaircosts_bags = stdrepaircosts_bags
					addonmsg(format('Bags repair costs: %s (%s%s)', GetMoneyString(roundmoney(stdrepaircosts_bags, round_total), true), diff >= 0 and '+' or '-', GetMoneyString(roundmoney(absdiff, round_diff), true)))
				end
			end
			-- Total
			if inv_displayed or bags_displayed then
				diff = diff_inv + diff_bags
				absdiff = abs(diff)
				addonmsg(format('Total repair costs: %s (%s%s)', GetMoneyString(roundmoney(stdrepaircosts, round_total), true), diff >= 0 and '+' or '-', GetMoneyString(roundmoney(absdiff, round_diff), true)))
			end
		end
		A.stdrepaircosts = stdrepaircosts
	end)
end

local discounts = {
	[0] = 'FF0000',
	[5] = 'FFA500',
	[10] = 'FFD700',
	[15] = '00FFFF',
	[20] = '00FF00',
}

local function find_closest_valid_discount(actual)
	for k in pairs(discounts) do
		if abs(k - actual) < 0.003 then return k end
	end
	return nil
end

function A.autorepair()
	if IsShiftKeyDown() then return end
	if CanMerchantRepair() then
		local actual_costs, canrepair = GetRepairAllCost()
		if not canrepair then
			if actual_costs == 0 then
				addonmsg('Nothing to repair. Do some damage to your gear and come back.')
			else
				addonmsg(attn_txt('For some reason, you currently cannot repair here.'))
			end
			return
		end
		if actual_costs == 0 then return end
		local actual_discount = 100 - actual_costs / A.stdrepaircosts * 100
		local nominal_discount = find_closest_valid_discount(actual_discount)
-- 		printf(format('Raw actual discount: %s; nominal: %s', actual_discount, nominal_discount or 'Failed!')) -- debug
		-- For debugging, but maybe leave it in as safety.
		if not nominal_discount then
			addonmsg(attn_txt(format('We have a calculation mismatch: the computed discount of %s%% does not match any nominal discount (0%%, 5%%, 10%%, 15%%, 20%%)! Probably our last record of the standard repair costs is not accurate or outdated. Aborting auto-repair!', actual_discount)))
			return
		end
		if nominal_discount >= db.discount_threshold then
			if is_in_guild and (db[guild].guildmoney_preferred or db[guild].guildmoney_only) then
				if CanGuildBankRepair() then -- Not documented? - but it works
					RepairAllItems(true)
					if not db[guild].guildmoney_only then
						RepairAllItems(false) -- Fallback if guild money isn't sufficient
					end
				elseif not db[guild].guildmoney_only then
					RepairAllItems(false)
				end
			else
				RepairAllItems(false)
			end
			if db.show_repairsummary then
				local costs = get_repaircosts_inv() + get_repaircosts_bags()
				if costs == 0 then
					addonmsg(format('Repaired for %s (%s discount)', GetMoneyString(roundmoney(actual_costs, 'silver'), true), WrapTextInColorCode(nominal_discount .. '%', 'ff' .. discounts[nominal_discount])))
				elseif db[guild].guildmoney_only then
					addonmsg('Your gear was not (or not entirely) repaired. This is probably because of your ' .. attn_txt('guildonly') .. ' setting.')
				else
					addonmsg('Your gear was not (or not entirely) repaired. Did you run out of money?')
				end
			end
		elseif db.show_repairsummary then
			addonmsg(format('You could repair here for: %s - %s = %s', GetMoneyString(roundmoney(A.stdrepaircosts, 'silver'), true), WrapTextInColorCode(nominal_discount .. '%', 'ff' .. discounts[nominal_discount]), GetMoneyString(roundmoney(actual_costs, 'silver'), true)))
		end
	end
end

-- Events

local ef = CreateFrame('Frame', 'ADR_eventframe')

ef:RegisterEvent 'PLAYER_INTERACTION_MANAGER_FRAME_SHOW'
ef:RegisterEvent 'PLAYER_INTERACTION_MANAGER_FRAME_HIDE'
ef:RegisterEvent 'UPDATE_INVENTORY_DURABILITY'
ef:RegisterEvent 'PLAYER_ENTERING_WORLD'
-- ef:RegisterEvent 'PLAYER_LOGIN'

local function PLAYER_INTERACTION_MANAGER_FRAME_SHOW(...)
	if ... == Enum.PlayerInteractionType.Merchant then -- Merchant 5
		debugprint('Merchant opened')
		A.merchant_is_open = true
		A.autorepair()
	end
end
local function PLAYER_INTERACTION_MANAGER_FRAME_HIDE(...)
	if ... == Enum.PlayerInteractionType.Merchant then -- Merchant 5
		debugprint('Merchant closed')
		A.merchant_is_open = nil
	end
end
local function PLAYER_LOGIN()
	C_TimerAfter(5, get_guild)
end
local function PLAYER_ENTERING_WORLD(login, reload)
	if not login and not reload then return end
	local delay = login and 5 or 1
	C_TimerAfter(delay, get_guild)
end
local function UPDATE_INVENTORY_DURABILITY()
	-- The function contains a throttle
	A.get_stdrepaircosts()
end


local event_handlers = {
-- 	['PLAYER_LOGIN'] = PLAYER_LOGIN,
	['PLAYER_ENTERING_WORLD'] = PLAYER_ENTERING_WORLD,
	['PLAYER_INTERACTION_MANAGER_FRAME_SHOW'] = PLAYER_INTERACTION_MANAGER_FRAME_SHOW,
	['PLAYER_INTERACTION_MANAGER_FRAME_HIDE'] = PLAYER_INTERACTION_MANAGER_FRAME_HIDE,
	['UPDATE_INVENTORY_DURABILITY'] = UPDATE_INVENTORY_DURABILITY,
}

ef:SetScript('OnEvent', function(_, event, ...)
	local handler = event_handlers[event]
	if handler then handler(...) end
end)

-- Slash

local function slash_cmd(msg)
	local args = strsplittable(' ', strtrim(msg), 2)
	if not args[1] or args[1] == '' then
		A.get_stdrepaircosts(true)
	elseif args[1] == 'guild' or args[1] == 'guildonly' and not guild then
		addonmsg(bad_txt('No guild registered for this char')
			.. ' --> cannot change guild settings. If you think this char is in a guild, try to reload the UI.')
	elseif args[1] == 'guild' then
		db[guild].guildmoney_preferred = not db[guild].guildmoney_preferred
		addonmsg('Prefer guild money for auto repairs: ' .. key_txt(db[guild].guildmoney_preferred))
	elseif args[1] == 'guildonly' then
		db[guild].guildmoney_only = not db[guild].guildmoney_only
		addonmsg('Use exclusively guild money for auto repairs: ' .. key_txt(db[guild].guildmoney_only))
	elseif args[1] == 'summary' then
		db.show_repairsummary = not db.show_repairsummary
		addonmsg('Show summary at merchant: ' .. key_txt(db.show_repairsummary))
	elseif args[1] == 'costs' then
		db.show_increased_costs = not db.show_increased_costs
		addonmsg('Show the current repair costs when they increased: ' .. key_txt(db.show_increased_costs))
	elseif args[1]:sub(-1, -1) == '%' or args[1] == 'max' then
		local value = args[1] == 'max' and 20 or tonumber(args[1]:sub(1, -2))
		db.discount_threshold = max(min(value, 20), 0)
		addonmsg('Discount threshold: ' .. key_txt(db.discount_threshold .. '%'))
	elseif tonumber(args[1]) then
		db.increased_costs_threshold = tonumber(args[1]) * 1e4
		addonmsg('Increment for showing repair costs: ' .. key_txt(db.increased_costs_threshold/1e4) .. ' Gold')
	elseif args[1] == 'help' or args[1] == 'h' then
		local lines = {
			addon_txt(ADDONNAME_LONG) .. neutral_txt(' help:'),
			key_txt('/adr') .. neutral_txt(' understands these arguments [type; current value (default)]:'),
			key_txt('guild') .. ' : Prefer guild money for auto repairs [toggle; '
				.. good_txt(db[guild].guildmoney_preferred) .. ' (' .. tostring(defaults.default_guildmoney_preferred) ..')]',
			key_txt('guildonly') .. ' : Use exclusively guild money for auto repairs [toggle; '
				.. good_txt(db[guild].guildmoney_only) .. ' (' .. tostring(defaults.default_guildmoney_only)
				.. ')]. If true, this implies "Prefer guild money".',
			key_txt('0%||5%||10%||15%||20%||max') .. ' : Discount threshold [percent; '
				.. good_txt(db.discount_threshold .. '%') .. ' (' .. defaults.discount_threshold ..'%)]',
			key_txt('summary') .. ' : Show summary at merchant [toggle; ' .. good_txt(db.show_repairsummary)
				.. ' (' .. tostring(defaults.show_repairsummary) ..')]',
			key_txt('costs') .. ' : Show current repair costs when they increased [toggle; '
				.. good_txt(db.show_increased_costs) .. ' (' .. tostring(defaults.show_increased_costs) ..')]',
			key_txt('<number>') .. ' : Increment for showing repair costs [amount in Gold; '
				.. good_txt(db.increased_costs_threshold/1e4) .. ' (' .. defaults.increased_costs_threshold/1e4 ..')]',
			key_txt('help') .. ' or ' .. key_txt('h') .. ' : This help text.',
		}
		for _, line in ipairs(lines) do
			print(line)
		end
	else
		addonmsg(bad_txt('Invalid argument(s).') .. ' Type ' .. key_txt('/adr help') .. ' for a list of arguments.')
	end
end

SLASH_AutoDiscountRepair1 = '/adr'
SlashCmdList.AutoDiscountRepair = slash_cmd

