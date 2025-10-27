-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2025 Thomas Floeren

local myname, A = ...
local db = A.db

local debugprint = A.debugprint

-- Blizz
local C_TimerAfter = C_Timer.After
local INTERACTIONTYPE_MERCHANT = Enum.PlayerInteractionType.Merchant -- 5


--[[===========================================================================
	Event functions
===========================================================================]]--

local function PLAYER_INTERACTION_MANAGER_FRAME_SHOW(...)
	if ... == INTERACTIONTYPE_MERCHANT then
		A.merchant_is_open = true
		if not (IsShiftKeyDown() and IsControlKeyDown()) and CanMerchantRepair() then
			A.autorepair()
		end
	end
end

local function PLAYER_INTERACTION_MANAGER_FRAME_HIDE(...)
	if ... == INTERACTIONTYPE_MERCHANT then
		A.merchant_is_open = nil
	end
end

-- Guild info is often not available shortly after login, so better use PEW with adaptive delays.
local function PLAYER_ENTERING_WORLD(is_login, is_reload)
	if not is_login and not is_reload then return end
	local delay = is_login and 10 or 5
	C_TimerAfter(delay, A.get_guild)
	if is_login then db.auto_repair = true end
	-- Private login debug, to check repair costs after login against the last state of the last session
	-- (sometimes there's a diff for no apparent reason).
	-- Private, bc it runs only if `chars` key is present in db, to not contaminate the user's db.
	if db.chars then
		A.PLAYERNAME = UnitName('player')
		db.chars[A.PLAYERNAME] = db.chars[A.PLAYERNAME] or {}
		db.chars[A.PLAYERNAME].costs_logout = db.chars[A.PLAYERNAME].costs_logout or 111111111
	end
end

local get_stdrepaircosts_onhold
local function UPDATE_INVENTORY_DURABILITY()
	-- If at a merchant, this returns the discounted costs, not the std costs; so no point
	-- Throttling is needed bc the event can fire multiple times in a row
	if get_stdrepaircosts_onhold or A.merchant_is_open then
		debugprint('UID ignored') -- Remove when no longer needed
		return
	end
	get_stdrepaircosts_onhold = true
	C_TimerAfter(A.REPAIR_COST_UPDATE_DELAY, function()
		get_stdrepaircosts_onhold = nil
		A.get_stdrepaircosts()
	end)
end

local function PLAYER_LOGOUT()
	-- Private login debug
	if db.chars then db.chars[A.PLAYERNAME].costs_logout = A.stdrepaircosts or 999999999 end
end

--[[===========================================================================
	Event frame, handlers, and registration
===========================================================================]]--

local ef = CreateFrame('Frame', myname .. '_eventframe')

local event_handlers = {
	['PLAYER_ENTERING_WORLD'] = PLAYER_ENTERING_WORLD,
	['PLAYER_INTERACTION_MANAGER_FRAME_SHOW'] = PLAYER_INTERACTION_MANAGER_FRAME_SHOW,
	['PLAYER_INTERACTION_MANAGER_FRAME_HIDE'] = PLAYER_INTERACTION_MANAGER_FRAME_HIDE,
	['UPDATE_INVENTORY_DURABILITY'] = UPDATE_INVENTORY_DURABILITY,
	['PLAYER_LOGOUT'] = PLAYER_LOGOUT,
}

for event in pairs(event_handlers) do
	ef:RegisterEvent(event)
end

ef:SetScript('OnEvent', function(_, event, ...)
	event_handlers[event](...) -- We do not want a nil check here
end)
