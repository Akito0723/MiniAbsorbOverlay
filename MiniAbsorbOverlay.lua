local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
---@type table<any, Container>
local containers = {}

local core = {}
addon.AbsorbOverlay = core

---@param unitFrame table
---@param healthBar table
---@return Container
local function EnsureContainer(unitFrame, healthBar)
	local container = containers[unitFrame]
	if container and container.HealthBar == healthBar then
		return container
	end

	local clip = CreateFrame("Frame", nil, healthBar:GetParent())
	clip:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", 0, 0)
	clip:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", 0, 0)
	clip:SetWidth(healthBar:GetWidth())
	clip:SetClipsChildren(true)

	-- Draw from the current-health edge, then clip away everything before max health.
	local absorb = CreateFrame("StatusBar", nil, clip)
	absorb:SetPoint("TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	absorb:SetPoint("BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	absorb:SetWidth(healthBar:GetWidth())
	absorb:SetReverseFill(false)
	absorb:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Overlay")
	-- Keep the overlay behind borders and other frame decorations.
	clip:SetFrameLevel(healthBar:GetFrameLevel())

	healthBar:HookScript("OnSizeChanged", function(_, width)
		clip:SetWidth(width)
		absorb:SetWidth(width)
	end)

	local strata = healthBar:GetFrameStrata()
	strata = mini:IsSecret(strata) and "LOW" or strata

	clip:SetFrameStrata(strata)
	absorb:SetStatusBarColor(1, 1, 1, 0.5)
	absorb:Hide()

	local texture = absorb:GetStatusBarTexture()
	texture:SetTexture("Interface\\RaidFrame\\Shield-Overlay", "REPEAT", "REPEAT")
	texture:SetHorizTile(true)
	texture:SetVertTile(true)
	texture:SetDrawLayer("ARTWORK", 1)

	container = {
		UnitFrame = unitFrame,
		HealthBar = healthBar,
		Clip = clip,
		Absorb = absorb,
	}

	if
		CreateUnitHealPredictionCalculator
		and UnitGetDetailedHealPrediction
		and Enum
		and Enum.UnitDamageAbsorbClampMode
	then
		local calculator = CreateUnitHealPredictionCalculator()
		calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
		container.Calculator = calculator
	end

	containers[unitFrame] = container

	return container
end

---@param unitFrame table
---@param healthBar table
---@param unit string
---@param alpha number?
---@return table absorb
function core:UpdateFrame(unitFrame, healthBar, unit, alpha)
	local container = EnsureContainer(unitFrame, healthBar)
	local absorb = container.Absorb
	local maxHealth
	local totalAbsorbs

	if container.Calculator then
		container.Calculator:ResetPredictedValues()
		UnitGetDetailedHealPrediction(unit, "player", container.Calculator)
		maxHealth = container.Calculator:GetMaximumHealth()
		totalAbsorbs = container.Calculator:GetDamageAbsorbs()
	else
		maxHealth = UnitHealthMax(unit) or 0
		totalAbsorbs = UnitGetTotalAbsorbs(unit) or 0
	end

	absorb:SetMinMaxValues(0, maxHealth)
	absorb:SetValue(totalAbsorbs)
	absorb:SetAlpha(alpha or 1)
	absorb:Show()

	return absorb
end

---@class Container
---@field UnitFrame table
---@field HealthBar table
---@field Clip table
---@field Absorb table
---@field Calculator table?
