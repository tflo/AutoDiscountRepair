-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...

local _
local debugprint = A.debugprint

local C_TimerAfter = C_Timer.After
local INTERACTIONTYPE_MERCHANT = Enum.PlayerInteractionType.Merchant -- 5



local function PLAYER_INTERACTION_MANAGER_FRAME_SHOW(...)
	if ... == INTERACTIONTYPE_MERCHANT then
		A.merchant_is_open = true
		if not IsShiftKeyDown() then A.autorepair() end
	end
end

local function PLAYER_INTERACTION_MANAGER_FRAME_HIDE(...)
	if ... == INTERACTIONTYPE_MERCHANT then
		A.merchant_is_open = nil
	end
end

-- local function PLAYER_LOGIN() C_TimerAfter(5, A.get_guild) end

-- Guild info is often not available shortly after login, so better use PEW with adaptive delays.
local function PLAYER_ENTERING_WORLD(is_login, is_reload)
	if not is_login and not is_reload then return end
	local delay = is_login and 10 or 5
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


--------------------------------------------------------------------------------
-- Event frame, handlers, and registration
--------------------------------------------------------------------------------

local ef = CreateFrame('Frame', myname .. '_eventframe')

local event_handlers = {
	-- ['PLAYER_LOGIN'] = PLAYER_LOGIN,
	['PLAYER_ENTERING_WORLD'] = PLAYER_ENTERING_WORLD,
	['PLAYER_INTERACTION_MANAGER_FRAME_SHOW'] = PLAYER_INTERACTION_MANAGER_FRAME_SHOW,
	['PLAYER_INTERACTION_MANAGER_FRAME_HIDE'] = PLAYER_INTERACTION_MANAGER_FRAME_HIDE,
	['UPDATE_INVENTORY_DURABILITY'] = UPDATE_INVENTORY_DURABILITY,
}

for event in pairs(event_handlers) do
	ef:RegisterEvent(event)
end

ef:SetScript('OnEvent', function(_, event, ...)
	event_handlers[event](...) -- We do not want a nil check here
end)
