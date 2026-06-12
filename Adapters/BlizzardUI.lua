local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
local core = addon.AbsorbOverlay

local eventsFrame

---@param absorb table
---@param overAbsorbGlow table
local function ReanchorOverAbsorbGlow(absorb, overAbsorbGlow)
	local texture = absorb:GetStatusBarTexture()

	-- Match Blizzard's overshield glow to the moving edge of our absorb texture.
	overAbsorbGlow:ClearAllPoints()
	overAbsorbGlow:SetPoint("TOP", texture, "TOP", 0, 0)
	overAbsorbGlow:SetPoint("BOTTOM", texture, "BOTTOM", 0, 0)
	overAbsorbGlow:SetPoint("RIGHT", texture, "RIGHT", 7, 0)
end

---@param unitFrame table
---@param healthBar table
---@param unit string
---@param overAbsorbGlow table?
---@return table absorb
local function UpdateFrame(unitFrame, healthBar, unit, overAbsorbGlow)
	local alpha = 1
	if overAbsorbGlow and not overAbsorbGlow:IsVisible() then
		alpha = 0
	end

	local absorb = core:UpdateFrame(unitFrame, healthBar, unit, alpha)

	if overAbsorbGlow then
		ReanchorOverAbsorbGlow(absorb, overAbsorbGlow)
	end

	return absorb
end

---@param unit string
---@return table? unitFrame
---@return table? healthBar
---@return table? overAbsorbGlow
local function GetUnitHealthBar(unit)
	if unit == "player" then
		if PlayerFrame and PlayerFrame.healthbar then
			return PlayerFrame, PlayerFrame.healthbar, PlayerFrame.overAbsorbGlow
		end
		if
			PlayerFrame
			and PlayerFrame.PlayerFrameContent
			and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
			and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBar
		then
			return PlayerFrame,
				PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBar,
				PlayerFrame.overAbsorbGlow
		end
	elseif unit == "target" then
		if TargetFrame and TargetFrame.healthbar then
			return TargetFrame, TargetFrame.healthbar, TargetFrame.overAbsorbGlow
		end
		if
			TargetFrame
			and TargetFrame.TargetFrameContent
			and TargetFrame.TargetFrameContent.TargetFrameContentMain
			and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar
		then
			return TargetFrame,
				TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar,
				TargetFrame.overAbsorbGlow
		end
	elseif unit == "focus" then
		if FocusFrame and FocusFrame.healthbar then
			return FocusFrame, FocusFrame.healthbar, FocusFrame.overAbsorbGlow
		end
		if
			FocusFrame
			and FocusFrame.TargetFrameContent
			and FocusFrame.TargetFrameContent.TargetFrameContentMain
			and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBar
		then
			return FocusFrame, FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBar, FocusFrame.overAbsorbGlow
		end
	end

	return nil, nil, nil
end

---@param unit string
local function UpdateUnitFrame(unit)
	local unitFrame, healthBar, overAbsorbGlow = GetUnitHealthBar(unit)
	if not unitFrame or not healthBar then
		return
	end

	UpdateFrame(unitFrame, healthBar, unit, overAbsorbGlow)
end

---@param frame table
local function UpdateCompactFrame(frame)
	if not frame or mini:IsSecret(frame) or frame:IsForbidden() or not frame.healthBar or not frame.unit then
		return
	end

	local unit = frame.unit

	-- Compound units contain a digit followed by a letter, unlike simple units
	-- where any digit is a trailing suffix.
	if unit:match("%d%a") then
		return
	end

	local absorb = UpdateFrame(frame, frame.healthBar, unit, frame.overAbsorbGlow)

	if frame.overAbsorbGlow and frame.UpdateAnchors and not frame.MiniAbsorbOverlayHooked then
		hooksecurefunc(frame, "UpdateAnchors", function()
			ReanchorOverAbsorbGlow(absorb, frame.overAbsorbGlow)
		end)
		frame.MiniAbsorbOverlayHooked = true
	end
end

local function HookCompactUnitFrames()
	if CompactUnitFrame_UpdateAll then
		hooksecurefunc("CompactUnitFrame_UpdateAll", UpdateCompactFrame)
	end

	if CompactUnitFrame_UpdateHealPrediction then
		hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", UpdateCompactFrame)
	end
end

---@return table? healthBar
---@return table? overAbsorbGlow
local function GetPersonalResourceHealthBar()
	if GetCVar("nameplateShowSelf") ~= "1" then
		return nil, nil
	end

	if
		PersonalResourceDisplayFrame
		and PersonalResourceDisplayFrame.HealthBarsContainer
		and PersonalResourceDisplayFrame.HealthBarsContainer.healthBar
	then
		local healthBar = PersonalResourceDisplayFrame.HealthBarsContainer.healthBar
		return healthBar, healthBar.overAbsorbGlow
	end

	return nil, nil
end

local function UpdatePersonalResourceFrame()
	local healthBar, overAbsorbGlow = GetPersonalResourceHealthBar()
	if not healthBar then
		return
	end

	UpdateFrame(healthBar, healthBar, "player", overAbsorbGlow)
end

local function UpdateAllUnitFrames()
	UpdateUnitFrame("player")
	UpdateUnitFrame("target")
	UpdateUnitFrame("focus")
	-- Blizzard updates the PRD glow before the next frame.
	C_Timer.After(0, UpdatePersonalResourceFrame)
end

local function OnEvent(_, event, ...)
	if event == "PLAYER_LOGIN" then
		HookCompactUnitFrames()
		UpdateAllUnitFrames()
		eventsFrame:UnregisterEvent("PLAYER_LOGIN")
		return
	end

	if event == "CVAR_UPDATE" then
		local cvarName = ...
		if cvarName == "nameplateShowSelf" then
			UpdatePersonalResourceFrame()
		end
		return
	end

	UpdateAllUnitFrames()
end

local function Initialize()
	eventsFrame = CreateFrame("Frame")
	eventsFrame:RegisterEvent("PLAYER_LOGIN")
	eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	eventsFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventsFrame:RegisterEvent("CVAR_UPDATE")
	eventsFrame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player", "target", "focus")
	eventsFrame:RegisterUnitEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "player", "target", "focus")
	eventsFrame:SetScript("OnEvent", OnEvent)
end

mini:WaitForAddonLoad(Initialize)
