-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local _, A = ...
local db = A.db
local L = A.L


-- Blizz
local format = format
local C_TimerAfter = C_Timer.After
local WrapTextInColorCode = WrapTextInColorCode
local GetMoneyString = GetMoneyString
local IsInGuild = IsInGuild
local GetGuildInfo = GetGuildInfo
local GetNormalizedRealmName = GetNormalizedRealmName
local C_TooltipInfoGetInventoryItem = C_TooltipInfo.GetInventoryItem
local C_TooltipInfoGetBagItem = C_TooltipInfo.GetBagItem
local C_ContainerGetContainerNumSlots = C_Container.GetContainerNumSlots
local C_ContainerGetContainerItemDurability = C_Container.GetContainerItemDurability

local key_txt = A.key_txt
local attn_txt = A.attn_txt
local good_txt = A.good_txt

local addonmsg = A.addonmsg
local addonmessage = A.addonmessage
local debugprint = A.debugprint


--[[===========================================================================
	Main
===========================================================================]]--

-- Getting the guild name is crucial, otherwise players who opted to drain guild
-- funds for repair would have a bad surprise. (Guild settings are per guild.)
-- But the guild server API (namely `GetGuildInfo`) is wonky after login and
-- especially under lag conditions. So, we use delays (see events.lua), repeat
-- the fetch attempt a number of times, and print fat red messages to the
-- console, if we can't fetch.
-- `IsInGuild` is much more reliable and we use this to find out if the player
-- is in a guild at all. But it also may (rarely) erroneously return false; our
-- delays should help, but if not, we can't do anything at all, since we do not
-- know then if the char is in a guild. So we can't even print warnings, as
-- these would also reach legit guildless chars.
-- Leaving/joining: We check for guild only at session begin, because we do not
-- want to make repeated calls during the session that are redundant in 98% of
-- the cases. So, the player should reload if they leave, join or change the
-- guild. Until then the addon will use potentially inappropriate guild
-- settings. If there was a dedicated player-left/joined-guild event, we would
-- use that, but PLAYER_GUILD_UPDATE fires way too often and for unrelated
-- reasons.
local guild = nil
function A.get_guild() -- @ login
	if not IsInGuild() then
		debugprint('Not in guild (IsInGuild returned false).')
		return
	end
	local tries = 0
	local function try_get_guild()
		tries = tries + 1
		local guild_name, _, _, guild_realm = GetGuildInfo('player')
		guild_realm = guild_realm or GetNormalizedRealmName()
		if not (guild_name and guild_realm) then
			if tries < A.GUILD_RETRY_MAX then
				addonmessage(format(L.NO_GUILD_INFO, tries), A.CLR_BAD)
				debugprint(
					format(
						'Guild info fetch failed (try %s): %s, %s',
						tries,
						guild_name or 'NO NAME',
						guild_realm or 'NO REALM'
					)
				)
				C_TimerAfter(A.GUILD_RETRY_DELAY, try_get_guild)
			else
				addonmessage(L.NO_GUILD_INFO_FINAL, A.CLR_BAD)
				debugprint(format('Max retries (%s) reached, no guild set.', A.GUILD_RETRY_MAX))
			end
			return
		end
		guild = guild_name .. '-' .. guild_realm
		debugprint(format('Guild set: %s (try %s)', guild, tries))
		if guild and not db.guilds[guild] then
			db.guilds[guild] = {
				['guildmoney_preferred'] = db['default_guildmoney_preferred'],
				['guildmoney_only'] = db['default_guildmoney_only'],
			}
			debugprint('Initialized new guild settings.')
		end
	end
	try_get_guild()
end


--[[---------------------------------------------------------------------------
	Get the costs
---------------------------------------------------------------------------]]--

-- Only used in messages
local function roundmoney(amount, precision)
	local precision = precision or 'c'
	precision = precision:sub(1, 1)
	if precision == 'c' or amount < 50 then return amount end
	local factor = precision == 'g' and amount >= 5000 and 10000 or 100
	local rounded = floor(amount / factor + 0.5) * factor
	return rounded
end

local repairable_slots = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17 }
local num_repairable_slots = #repairable_slots

local function get_repaircosts_inv()
	local total = 0
	-- local ts_start = GetTimePreciseSec() -- debug
	for i = 1, num_repairable_slots do
		-- for slot = 1,17 do -- this seems to be even faster
		local slot = repairable_slots[i]
		local durability, max_durability = GetInventoryItemDurability(slot)
		if durability and durability ~= max_durability then
			local data = C_TooltipInfoGetInventoryItem('player', slot)
			local costs = data and data.repairCost
			if costs then total = total + costs end
		end
	end
	-- local time_spent = GetTimePreciseSec() - ts_start -- debug
	-- debugprint('Needed for inventory repair costs:', time_spent) -- debug
	return total
end

local function get_repaircosts_bags()
	local total = 0
	-- local ts_start = GetTimePreciseSec() -- debug
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
	-- local time_spent = GetTimePreciseSec() - ts_start -- debug
	-- debugprint('Needed for bags repair costs:', time_spent) -- debug
	return total
end

local function get_sound_for_costincrease(diff)
	for _, v in ipairs(A.SOUNDS_INCREASED_COSTS) do
		if diff >= v[1] then return v[2] end
	end
end

-- @ UPDATE_INVENTORY_DURABILITY
function A.get_stdrepaircosts(byusercmd)
	-- Check this again here
	if A.merchant_is_open then return end
	local stdrepaircosts_inv = get_repaircosts_inv()
	local stdrepaircosts_bags = get_repaircosts_bags()
	local stdrepaircosts = stdrepaircosts_inv + stdrepaircosts_bags
	debugprint('Repair costs updated.')
	-- Messages
	if db.show_increased_costs or byusercmd then
		local thresh, round_total, round_diff = db.increased_costs_threshold, 'silver', 'copper'
		if not A.last_repaircosts_inv then
			-- First run
			thresh = 0
			A.last_repaircosts_inv = stdrepaircosts_inv
			A.last_repaircosts_bags = stdrepaircosts_bags
		end
		if byusercmd then thresh = 0 end
		local diff_inv = stdrepaircosts_inv - A.last_repaircosts_inv
		local absdiff_inv = abs(diff_inv)
		local diff_bags = stdrepaircosts_bags - A.last_repaircosts_bags
		local absdiff_bags = abs(diff_bags)
		A.last_repaircosts_inv, A.last_repaircosts_bags = stdrepaircosts_inv, stdrepaircosts_bags
		local diff_total = diff_inv + diff_bags
		local absdiff_total = abs(diff_total)
		if absdiff_total >= thresh or absdiff_inv >= thresh or absdiff_bags >= thresh then
			if db.increased_costs_sound then
				PlaySoundFile(get_sound_for_costincrease(diff_total))
			end
			if stdrepaircosts_bags == 0 and diff_bags == 0 then
				addonmsg(
					format(
						L.COSTS_INVENTORY_TOTAL,
						GetMoneyString(roundmoney(stdrepaircosts_inv, round_total), true),
						diff_inv >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_inv, round_diff), true)
					)
				)
			elseif stdrepaircosts_inv == 0 and diff_inv == 0 then
				addonmsg(
					format(
						L.COSTS_BAGS_TOTAL,
						GetMoneyString(roundmoney(stdrepaircosts_bags, round_total), true),
						diff_bags >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_bags, round_diff), true)
					)
				)
			else
				addonmsg(
					format(
						L.COSTS_INVENTORY,
						GetMoneyString(roundmoney(stdrepaircosts_inv, round_total), true),
						diff_inv >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_inv, round_diff), true)
					)
				)
				addonmsg(
					format(
						L.COSTS_BAGS,
						GetMoneyString(roundmoney(stdrepaircosts_bags, round_total), true),
						diff_bags >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_bags, round_diff), true)
					)
				)
				addonmsg(
					format(
						L.COSTS_TOTAL,
						GetMoneyString(roundmoney(stdrepaircosts, round_total), true),
						diff_total >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_total, round_diff), true)
					)
				)
			end
		end
	end
	A.stdrepaircosts = stdrepaircosts
end


--[[---------------------------------------------------------------------------
	At the merchant
---------------------------------------------------------------------------]]--


local function pick_random(array)
    local i = fastrandom(#array)
    return array[i]
end


local function find_closest_valid_discount(actual)
	for k in pairs(A.DISCOUNTS) do
		if abs(k - actual) < A.DISCOUNT_TOLERANCE then return k end
	end
	return nil
end

function A.autorepair()
	local actual_costs, canrepair = GetRepairAllCost()
	if not canrepair then
		if actual_costs == 0 then
			addonmsg(pick_random(L.MSGS_NOREPAIR))
		else
			addonmsg(L.REPAIR_IMPOSSIBLE)
		end
		return
	end
	if actual_costs == 0 then
		debugprint('This should never happen!')
		return
	end
	local actual_discount = 100 - actual_costs / A.stdrepaircosts * 100
	local nominal_discount = find_closest_valid_discount(actual_discount)
	debugprint(
		format(
			'Act: %s | Tol: %s | Nom: %s',
			actual_discount,
			A.DISCOUNT_TOLERANCE,
			nominal_discount
		)
	)
	-- For debugging, but maybe leave it in as safety.
	if not nominal_discount then
		addonmessage(attn_txt(format(L.CALCULATION_MISMATCH, actual_discount)))
		return
	end
	local repair_enabled = db.auto_repair and not IsShiftKeyDown()
	if repair_enabled and nominal_discount >= db.discount_threshold then
		if
			guild and (db.guilds[guild].guildmoney_preferred or db.guilds[guild].guildmoney_only)
		then
			if CanGuildBankRepair() then -- Not documented? - but it works
				RepairAllItems(true)
				if not db.guilds[guild].guildmoney_only then
					RepairAllItems(false) -- Fallback if out of guild funds
				end
			elseif not db.guilds[guild].guildmoney_only then
				RepairAllItems(false)
			end
		else
			RepairAllItems(false)
		end
		if db.show_repairsummary then
			-- Re-calculate repair costs
			-- This comes to early w/o timer; TODO: test with different delays
			C_TimerAfter(1, function()
				local costs = get_repaircosts_inv() + get_repaircosts_bags()
				if costs == 0 then
					addonmsg(
						format(
							L.REPAIR_SUCCESS,
							GetMoneyString(roundmoney(actual_costs, 'silver'), true),
							WrapTextInColorCode(
								nominal_discount .. '%',
								'ff' .. A.DISCOUNTS[nominal_discount]
							)
						)
					)
				elseif db.guilds[guild].guildmoney_only then
					addonmsg(L.REPAIR_FAILURE_GUILD)
				else
					addonmsg(L.REPAIR_FAILURE)
				end
			end)
		end
	elseif db.show_repairsummary then
		local msg = repair_enabled and L.DISCOUNT_TOO_LOW or L.REPAIR_OFF
		addonmsg(
			format(
				msg,
				GetMoneyString(roundmoney(A.stdrepaircosts, 'silver'), true),
				WrapTextInColorCode(nominal_discount .. '%', 'ff' .. A.DISCOUNTS[nominal_discount]),
				GetMoneyString(roundmoney(actual_costs, 'silver'), true)
			)
		)
	end
end


--[[===========================================================================
	Console
===========================================================================]]--


local function slash_cmd(msg)
	local args = strsplittable(' ', strtrim(msg), 2)
	if not args[1] or args[1] == '' then
		A.get_stdrepaircosts(true)
	elseif (args[1] == 'guild' or args[1] == 'guildonly') and not guild then
		addonmsg(L.CFG_NOGUILD)
	elseif args[1] == 'guild' then
		db.guilds[guild].guildmoney_preferred = not db.guilds[guild].guildmoney_preferred
		addonmsg(
			format(
				L.CFG_GUILD_PREF,
				key_txt(db.guilds[guild].guildmoney_preferred)
			)
		)
	elseif args[1] == 'guildonly' then
		db.guilds[guild].guildmoney_only = not db.guilds[guild].guildmoney_only
		addonmsg(
			format(
				L.CFG_GUILD_ONLY ,
				key_txt(db.guilds[guild].guildmoney_only)
			)
		)
	elseif args[1] == 'summary' then
		db.show_repairsummary = not db.show_repairsummary
		addonmsg(format(L.CFG_SUMMARY, key_txt(db.show_repairsummary)))
	elseif args[1] == 'costs' or args[1] == 'cost' then
		db.show_increased_costs = not db.show_increased_costs
		addonmsg(
			format(
				L.CFG_COSTS_PRINT,
				key_txt(db.show_increased_costs)
			)
		)
	elseif args[1] == 'sound' then
		db.increased_costs_sound = not db.increased_costs_sound
		addonmsg(
			format(
				L.CFG_COSTS_SOUND,
				key_txt(db.increased_costs_sound)
			)
		)
	elseif args[1] == 'repair' then
		db.auto_repair = not db.auto_repair
		addonmsg(
			format(
				L.CFG_REPAIR,
				key_txt(db.auto_repair)
			)
		)
	elseif args[1] == 'max' or args[1]:sub(-1) == '%' then
		local val = tonumber(args[1]:sub(1, -2)) or 20 -- `max`, `%`, `xyz%` --> 20
		db.discount_threshold = max(min(val, 20), 0)
		addonmsg(format(L.CFG_DISCOUNT_THRESH, key_txt(db.discount_threshold .. '%')))
	elseif tonumber(args[1]) then
		local val = max(min(tonumber(args[1]), 1000), 0)
		db.increased_costs_threshold = val * 1e4
		addonmsg(
			format(
				L.CFG_COSTS_THRESH,
				key_txt(db.increased_costs_threshold / 1e4)
			)
		)
	elseif args[1] == 'help' or args[1] == 'h' or args[1] == 'H'  or args[1] == 'Help' then
		local lines = {
			L.BLOCK_SEP,
			L.HELP_HEADING,
			L.HELP_INTRO,
			format(
				L.HELP_GUILD_PREF,
				good_txt(db.guilds[guild].guildmoney_preferred),
				tostring(A.defaults.default_guildmoney_preferred)
			),
			format(
				L.HELP_GUILD_ONLY,
				good_txt(db.guilds[guild].guildmoney_only),
				tostring(A.defaults.default_guildmoney_only)
			),
			format(
				L.HELP_DISCOUNT_THRESH,
				good_txt(db.discount_threshold .. '%'),
				A.defaults.discount_threshold
			),
			format(
				L.HELP_SUMMARY,
				good_txt(db.show_repairsummary),
				tostring(A.defaults.show_repairsummary)
			),
			format(
				L.HELP_COSTS_PRINT,
				good_txt(db.show_increased_costs),
				tostring(A.defaults.show_increased_costs)
			),
			format(
				L.HELP_COSTS_THRESH,
				good_txt(db.increased_costs_threshold / 1e4),
				A.defaults.increased_costs_threshold / 1e4
			),
			format(
				L.HELP_COSTS_SOUND,
				good_txt(db.increased_costs_sound),
				tostring(A.defaults.increased_costs_sound)
			),
			format(
				L.HELP_REPAIR,
				good_txt(db.auto_repair),
				tostring(A.defaults.auto_repair)
			),
			format(
				L.HELP_DEBUG,
				good_txt(db.debugmode),
				tostring(A.defaults.debugmode)
			),
			L.HELP_HELP,
			L.BLOCK_SEP,
		}
		-- Hide repair and debug toggles in std help
		if args[1] == 'help' or args[1] == 'h' then table.removemulti(lines, 11, 2) end
		for _, line in ipairs(lines) do
			print(line)
		end
	elseif args[1] == 'dm' then
		db.debugmode = not db.debugmode
		addonmsg(format(L.CFG_DEBUG, key_txt(db.debugmode)))
	else
		addonmsg(
			L.CFG_INVALID
		)
	end
end

SLASH_AutoDiscountRepair1 = '/adr'
SlashCmdList.AutoDiscountRepair = slash_cmd

