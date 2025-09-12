-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local _, A = ...
local db = A.db


-- API
local _
local C_TimerAfter = C_Timer.After
local IsInGuild = IsInGuild
local C_TooltipInfoGetInventoryItem = C_TooltipInfo.GetInventoryItem
local C_TooltipInfoGetBagItem = C_TooltipInfo.GetBagItem
local C_ContainerGetContainerNumSlots = C_Container.GetContainerNumSlots
local C_ContainerGetContainerItemDurability = C_Container.GetContainerItemDurability
local GetMoneyString = GetMoneyString

local function color_text(text, color)
	return color:WrapTextInColorCode(tostring(text))
end

local function key_txt(text) return color_text(text, A.CLR_KEY) end
local function addon_txt(text) return color_text(text, A.CLR_ADDON) end
local function neutral_txt(text) return color_text(text, A.CLR_NEUTRAL) end
local function attn_txt(text) return color_text(text, A.CLR_ATTN) end
local function bad_txt(text) return color_text(text, A.CLR_BAD) end
local function good_txt(text) return color_text(text, A.CLR_GOOD) end

local function addonmsg(text, color)
	local color = color or A.CLR_NEUTRAL
	print(A.PREFIX_SHORT .. color:WrapTextInColorCode(text))
end
A.addonmsg = addonmsg

local function addonmessage(text, color)
	local color = color or A.CLR_NEUTRAL
	print(A.PREFIX_LONG .. color:WrapTextInColorCode(text))
end
A.addonmessage = addonmessage

local function debugprint(text)
	if not db.debugmode then return end
	print(A.PREFIX_SHORT .. A.CLR_DEBUG:WrapTextInColorCode(text))
end
A.debugprint = debugprint


--[[===========================================================================
	Main
===========================================================================]]--

-- @ login
-- We check for guild only at session begin, because we do not want to make
-- calls during the rest of the session that are completely redundant in 99% of
-- the cases. So, the player should reload if they leave, join or change the
-- guild. Until then the addon will use outdated guild settings.
-- If there was a dedicated player_left_guild event, we would use that, but
-- PLAYER_GUILD_UPDATE fires too often and for unrelated reasons.
local guild, is_in_guild, getguild_tries = nil, nil, 0
function A.get_guild()
	if IsInGuild() then
		getguild_tries = getguild_tries + 1
		is_in_guild = true
		local guild_name, _, _, guild_realm = GetGuildInfo('player')
		guild_realm = guild_realm or GetNormalizedRealmName()
		if not guild_name or not guild_realm then
			debugprint(
				'Player is in guild, but I was unable to retrieve the guild info! ('
					.. getguild_tries
					.. ', '
					.. (guild_name or 'NO NAME')
					.. ', '
					.. (guild_realm or 'NO REALM')
					.. ')'
			)
			if getguild_tries <= 3 then C_TimerAfter(10, get_guild) end
			return
		end
		guild = guild_name .. '-' .. guild_realm
		debugprint('Guild: ' .. guild .. ' (' .. getguild_tries .. ')')
		if guild and not db.guilds[guild] then
			db.guilds[guild] = {
				['guildmoney_preferred'] = db['default_guildmoney_preferred'],
				['guildmoney_only'] = db['default_guildmoney_only'],
			}
			debugprint('Guild is new')
		end
	else
		debugprint('IsInGuild() --> false')
	end
end


--[[---------------------------------------------------------------------------
	Get the costs
---------------------------------------------------------------------------]]--

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
			local data, costs = C_TooltipInfoGetInventoryItem('player', slot), nil
			if data then costs = data.repairCost end
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
	debugprint 'Repair costs updated.'
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
						'Inventory (= total) repair costs: %s (%s%s)',
						GetMoneyString(roundmoney(stdrepaircosts_inv, round_total), true),
						diff_inv >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_inv, round_diff), true)
					)
				)
			elseif stdrepaircosts_inv == 0 and diff_inv == 0 then
				addonmsg(
					format(
						'Bags (= total) repair costs: %s (%s%s)',
						GetMoneyString(roundmoney(stdrepaircosts_bags, round_total), true),
						diff_bags >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_bags, round_diff), true)
					)
				)
			else
				addonmsg(
					format(
						'Inventory repair costs: %s (%s%s)',
						GetMoneyString(roundmoney(stdrepaircosts_inv, round_total), true),
						diff_inv >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_inv, round_diff), true)
					)
				)
				addonmsg(
					format(
						'Bags repair costs: %s (%s%s)',
						GetMoneyString(roundmoney(stdrepaircosts_bags, round_total), true),
						diff_bags >= 0 and '+' or '-',
						GetMoneyString(roundmoney(absdiff_bags, round_diff), true)
					)
				)
				addonmsg(
					format(
						'Total repair costs: %s (%s%s)',
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
		-- For debugging, but maybe leave it in as safety.
		if not nominal_discount then
			addonmessage(
				attn_txt(
					format(
						'We have a calculation mismatch: the computed discount of %s%% does not match any nominal discount (0%%, 5%%, 10%%, 15%%, 20%%)! Probably our last record of the standard repair costs is not accurate or outdated. Aborting auto-repair! (You may try to restart interaction with the merchant.)',
						actual_discount
					)
				)
			)
			return
		end
		if nominal_discount >= db.discount_threshold then
			if
				is_in_guild
				and (db.guilds[guild].guildmoney_preferred or db.guilds[guild].guildmoney_only)
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
								'Repaired for %s (%s discount)',
								GetMoneyString(roundmoney(actual_costs, 'silver'), true),
								WrapTextInColorCode(
									nominal_discount .. '%',
									'ff' .. discounts[nominal_discount]
								)
							)
						)
					elseif db.guilds[guild].guildmoney_only then
						addonmsg(
							'Your gear was not (or not entirely) repaired. This is probably because of your '
								.. attn_txt('guildonly')
								.. ' setting.'
						)
					else
						addonmsg(
							'Your gear was not (or not entirely) repaired. Did you run out of money?'
						)
					end
				end)
			end
		elseif db.show_repairsummary then
			addonmsg(
				format(
					'You could repair here for: %s - %s = %s',
					GetMoneyString(roundmoney(A.stdrepaircosts, 'silver'), true),
					WrapTextInColorCode(
						nominal_discount .. '%',
						'ff' .. discounts[nominal_discount]
					),
					GetMoneyString(roundmoney(actual_costs, 'silver'), true)
				)
			)
		end
	end
end


--[[===========================================================================
	Console
===========================================================================]]--

local function slash_cmd(msg)
	local args = strsplittable(' ', strtrim(msg), 2)
	if not args[1] or args[1] == '' then
		A.get_stdrepaircosts(true)
	elseif args[1] == 'guild' or args[1] == 'guildonly' and not guild then
		addonmsg(
			bad_txt('No guild registered for this char')
				.. ' --> cannot change or set guild settings. If you think this char is in a guild, try to reload the UI.'
		)
	elseif args[1] == 'guild' then
		db.guilds[guild].guildmoney_preferred = not db.guilds[guild].guildmoney_preferred
		addonmsg(
			'Prefer guild funds for auto-repairs: '
				.. key_txt(db.guilds[guild].guildmoney_preferred)
		)
	elseif args[1] == 'guildonly' then
		db.guilds[guild].guildmoney_only = not db.guilds[guild].guildmoney_only
		addonmsg(
			'Use exclusively guild funds for auto-repairs: '
				.. key_txt(db.guilds[guild].guildmoney_only)
		)
	elseif args[1] == 'summary' then
		db.show_repairsummary = not db.show_repairsummary
		addonmsg('Print summary at merchant: ' .. key_txt(db.show_repairsummary))
	elseif args[1] == 'costs' or args[1] == 'cost' then
		db.show_increased_costs = not db.show_increased_costs
		addonmsg(
			'Print the current repair costs when they increase: '
				.. key_txt(db.show_increased_costs)
		)
	elseif args[1] == 'sound' then
		db.increased_costs_sound = not db.increased_costs_sound
		addonmsg(
			'Play a sound when increased repair costs are printed: '
				.. key_txt(db.increased_costs_sound)
		)
	elseif args[1] == 'max' or args[1]:match('^%d?%d%%$') then
		local value = args[1] == 'max' and 20 or tonumber(args[1]:sub(1, -2))
		db.discount_threshold = min(value, 20)
		addonmsg('Discount threshold: ' .. key_txt(db.discount_threshold .. '%'))
	elseif tonumber(args[1]) then
		db.increased_costs_threshold = tonumber(args[1]) * 1e4
		addonmsg(
			'Minimum cost increase to print a new message: '
				.. key_txt(db.increased_costs_threshold / 1e4)
				.. ' Gold'
		)
	elseif args[1] == 'help' or args[1] == 'h' then
		local lines = {
			addon_txt(A.ADDONNAME_LONG) .. neutral_txt(' help:'),
			key_txt('/adr')
				.. neutral_txt(' accepts these arguments [type; current value (default)]:'),
			key_txt('guild') .. ' : Prefer guild funds for auto-repairs [toggle; ' .. good_txt(
				db.guilds[guild].guildmoney_preferred
			) .. ' (' .. tostring(A.defaults.default_guildmoney_preferred) .. ')].',
			key_txt('guildonly')
				.. ' : Use exclusively guild funds for auto-repairs [toggle; '
				.. good_txt(db.guilds[guild].guildmoney_only)
				.. ' ('
				.. tostring(A.defaults.default_guildmoney_only)
				.. ')]. If enabled, this implies "Prefer guild funds".',
			key_txt('0%||5%||10%||15%||20%||max')
				.. ' : Discount threshold [percent; '
				.. good_txt(db.discount_threshold .. '%')
				.. ' ('
				.. A.defaults.discount_threshold
				.. '%)].',
			key_txt('summary') .. ' : Print summary at repair merchant [toggle; ' .. good_txt(
				db.show_repairsummary
			) .. ' (' .. tostring(A.defaults.show_repairsummary) .. ')].',
			key_txt('costs')
				.. ' : Print the current repair costs when they increase [toggle; '
				.. good_txt(db.show_increased_costs)
				.. ' ('
				.. tostring(A.defaults.show_increased_costs)
				.. ')].',
			key_txt('<number>')
				.. ' : Minimum cost increase to print a new message [difference in Gold; '
				.. good_txt(db.increased_costs_threshold / 1e4)
				.. ' ('
				.. A.defaults.increased_costs_threshold / 1e4
				.. ')]. This requires the '
				.. key_txt('costs')
				.. ' option to be enabled.',
			key_txt('sound')
				.. ' : Play a sound when increased repair costs are printed [toggle; '
				.. good_txt(db.increased_costs_sound)
				.. ' ('
				.. tostring(A.defaults.increased_costs_sound)
				.. ')]. This requires the '
				.. key_txt('costs')
				.. ' option to be enabled.',
			key_txt('help') .. ' or ' .. key_txt('h') .. ' : Print this help text.',
		}
		for _, line in ipairs(lines) do
			print(line)
		end
	elseif args[1] == 'dm' then
		db.debugmode = not db.debugmode
		addonmsg('Debug mode: ' .. key_txt(db.debugmode))
	else
		addonmsg(
			bad_txt('Invalid argument(s).')
				.. ' Type '
				.. key_txt('/adr help')
				.. ' for a list of arguments.'
		)
	end
end

SLASH_AutoDiscountRepair1 = '/adr'
SlashCmdList.AutoDiscountRepair = slash_cmd

