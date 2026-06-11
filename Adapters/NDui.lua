local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
local core = addon.AbsorbOverlay

local NDUI_ADDON_NAME = "NDui"
local PARTY_HEADER_NAME = "oUF_Party"
local PARTY_UNITS = {
	player = true,
	party1 = true,
	party2 = true,
	party3 = true,
	party4 = true,
}

local eventFrame
local predictionCalculators = setmetatable({}, { __mode = "k" })

local function IsNDuiLoaded()
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		return C_AddOns.IsAddOnLoaded(NDUI_ADDON_NAME)
	end

	return IsAddOnLoaded and IsAddOnLoaded(NDUI_ADDON_NAME)
end

local function UpdatePartyFrame(frame)
	if not frame or not frame.unit or not PARTY_UNITS[frame.unit] or not frame.Health then
		return
	end

	if not CreateUnitHealPredictionCalculator or not UnitGetDetailedHealPrediction then
		return
	end

	local calculator = predictionCalculators[frame]
	if not calculator then
		calculator = CreateUnitHealPredictionCalculator()
		predictionCalculators[frame] = calculator
	end

	UnitGetDetailedHealPrediction(frame.unit, "player", calculator)
	local _, damageAbsorbClamped = calculator:GetDamageAbsorbs()
	local absorb = core:UpdateFrame(frame, frame.Health, frame.unit)

	-- damageAbsorbClamped may be a secret boolean in Midnight.
	absorb:SetAlphaFromBoolean(damageAbsorbClamped, 1, 0)
end

local function VisitPartyFrames(frame)
	if not frame then
		return
	end

	UpdatePartyFrame(frame)

	local children = { frame:GetChildren() }
	for _, child in ipairs(children) do
		VisitPartyFrames(child)
	end
end

local function UpdateAllPartyFrames()
	if not IsNDuiLoaded() then
		return
	end

	VisitPartyFrames(_G[PARTY_HEADER_NAME])
end

local function UpdateUnit(unit)
	if not PARTY_UNITS[unit] then
		return
	end

	local header = _G[PARTY_HEADER_NAME]
	if not header then
		return
	end

	local function Visit(frame)
		if frame.unit == unit and frame.Health then
			UpdatePartyFrame(frame)
			return true
		end

		local children = { frame:GetChildren() }
		for _, child in ipairs(children) do
			if Visit(child) then
				return true
			end
		end

		return false
	end

	Visit(header)
end

local function UpdateAllPartyFramesNextFrame()
	C_Timer.After(0, UpdateAllPartyFrames)
end

local function OnEvent(_, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if loadedAddon == NDUI_ADDON_NAME then
			UpdateAllPartyFramesNextFrame()
		end
	elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
		UpdateAllPartyFramesNextFrame()
	else
		UpdateUnit(...)
	end
end

local function Initialize()
	if eventFrame then
		return
	end

	eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("ADDON_LOADED")
	eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterUnitEvent("UNIT_HEALTH", "player", "party1", "party2", "party3", "party4")
	eventFrame:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "party1", "party2", "party3", "party4")
	eventFrame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player", "party1", "party2", "party3", "party4")
	eventFrame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "player", "party1", "party2", "party3", "party4")
	eventFrame:SetScript("OnEvent", OnEvent)

	UpdateAllPartyFramesNextFrame()
end

mini:WaitForAddonLoad(Initialize)
