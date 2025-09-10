-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local _, A = ...

local _
local debugprint = A.debugprint

local C_TimerAfter = C_Timer.After



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
		if not IsShiftKeyDown() then A.autorepair() end
	end
end

local function PLAYER_INTERACTION_MANAGER_FRAME_HIDE(...)
	if ... == Enum.PlayerInteractionType.Merchant then -- Merchant 5
		debugprint('Merchant closed')
		A.merchant_is_open = nil
	end
end

local function PLAYER_LOGIN()
	C_TimerAfter(5, A.get_guild)
end

local function PLAYER_ENTERING_WORLD(login, reload)
	if not login and not reload then return end
	local delay = login and 5 or 1
	C_TimerAfter(delay, A.get_guild)
end

local get_stdrepaircosts_onhold
local function UPDATE_INVENTORY_DURABILITY()
	-- If at a merchant, this returns the discounted costs, not the std costs; so no point
	-- Throttling is needed bc the event can fire multiple times in a row
	if get_stdrepaircosts_onhold or A.merchant_is_open then return end
	get_stdrepaircosts_onhold = true
	C_TimerAfter(1, function()
		get_stdrepaircosts_onhold = nil
		A.get_stdrepaircosts()
	end)
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
