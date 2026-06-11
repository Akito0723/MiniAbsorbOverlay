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

	local absorb = CreateFrame("StatusBar", nil, healthBar)
	absorb:SetAllPoints(healthBar)
	absorb:SetReverseFill(true)
	absorb:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Overlay")
	-- Keep the overlay behind borders and other frame decorations.
	absorb:SetFrameLevel(healthBar:GetFrameLevel())

	local strata = healthBar:GetFrameStrata()
	strata = mini:IsSecret(strata) and "LOW" or strata

	absorb:SetFrameStrata(strata)
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
		Absorb = absorb,
	}
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
	local maxHealth = UnitHealthMax(unit) or 0
	local totalAbsorbs = UnitGetTotalAbsorbs(unit) or 0

	absorb:SetMinMaxValues(0, maxHealth)
	absorb:SetValue(totalAbsorbs)
	absorb:SetAlpha(alpha or 1)
	absorb:Show()

	return absorb
end

---@class Container
---@field UnitFrame table
---@field HealthBar table
---@field Absorb table
