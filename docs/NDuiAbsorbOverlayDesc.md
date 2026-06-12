# NDui Absorb Overlay Rendering

This document describes how NDui and MiniAbsorbOverlay currently render damage absorbs. It is based on the actual frame anchors, status-bar values, clipping regions, and alpha controls in the code.

## Legend

```text
█ Current health
▒ NDui incoming healing
▓ NDui internal absorb or MiniAbsorbOverlay external absorb
░ Missing health
```

All examples use a maximum health value of `100`. Each character represents approximately `5` health.

## Rendering Pipeline

NDui creates its prediction frame over the health bar and enables child clipping:

```lua
local frame = CreateFrame("Frame", nil, self)
frame:SetAllPoints(self.Health)
frame:SetClipsChildren(true)
```

NDui anchors incoming healing after the current-health texture:

```lua
myBar:SetPoint("LEFT", self.Health:GetStatusBarTexture(), "RIGHT")
```

NDui anchors its internal absorb bar after the incoming-healing texture:

```lua
absorbBar:SetPoint("LEFT", myBar:GetStatusBarTexture(), "RIGHT")
```

Therefore, NDui renders predictions in this order:

```text
Current health -> Incoming healing -> Internal absorb
```

MiniAbsorbOverlay creates a separate clipping frame beginning at the right edge of the health bar:

```lua
clip:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", 0, 0)
clip:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", 0, 0)
clip:SetClipsChildren(true)
```

Its absorb bar starts at the end of the current-health texture:

```lua
absorb:SetPoint("TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
absorb:SetPoint("BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
```

The complete absorb segment is rendered from the current-health edge, but only pixels beyond the maximum-health boundary are visible through the external clipping frame.

MiniAbsorbOverlay configures its prediction calculator with:

```lua
calculator:SetDamageAbsorbClampMode(
    Enum.UnitDamageAbsorbClampMode.MaximumHealth
)
```

The returned values are passed directly to status-bar APIs. The addon does not subtract, compare, or otherwise perform Lua arithmetic on potentially secret health or absorb values.

The NDui adapter controls external visibility with the calculator's clamped flag:

```lua
absorb:SetAlphaFromBoolean(damageAbsorbClamped, 1, 0)
```

## Cases Without Incoming Healing

### Health 60, Absorb 20

```text
NDui internal                MiniAbsorbOverlay external
[████████████▓▓▓▓░░░░]
 Health 60    Absorb 20  Missing 20
```

NDui renders the absorb inside the health bar. The complete absorb segment does not reach the external clipping region, and `damageAbsorbClamped` is false, so the external bar is transparent.

### Health 80, Absorb 20

```text
NDui internal                MiniAbsorbOverlay external
[████████████████▓▓▓▓]
 Health 80          Absorb 20
```

The absorb exactly fills the remaining health. NDui displays all `20` internally. MiniAbsorbOverlay's segment ends at the clipping boundary, so it has no visible external pixels.

### Health 80, Absorb 40

```text
NDui internal                MiniAbsorbOverlay external
[████████████████▓▓▓▓]▓▓▓▓
 Health 80          20   20
                    |    +-- MiniAbsorbOverlay: 100 -> 120
                    +------- NDui: 80 -> 100
```

NDui renders the first `20` inside the health bar. MiniAbsorbOverlay renders a complete segment from `80` to `120`, but its clipping frame removes `80` to `100`. Only the external `20` remains visible.

The internal and external bars do not draw the same region.

### Health 100, Absorb 40

```text
NDui internal                MiniAbsorbOverlay external
[████████████████████]▓▓▓▓▓▓▓▓
 Health 100                 Absorb 40
```

NDui has no internal space available. MiniAbsorbOverlay starts at the full-health edge, so the complete `40` is visible externally.

### Health 20, Absorb 100

```text
NDui internal                MiniAbsorbOverlay external
[████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓]▓▓▓▓
  20       Internal 80       External 20
```

NDui uses `80` to fill the missing-health region. MiniAbsorbOverlay renders from `20` to `120`; clipping removes the internal `20` to `100` portion and leaves `20` externally.

### Health 100, Absorb 150

```text
NDui internal                MiniAbsorbOverlay external
[████████████████████]▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
 Health 100                 Maximum visible external value: 100
```

MiniAbsorbOverlay uses `MaximumHealth` absorb clamping. The externally visible bar is limited to one full health-bar width. The remaining `50` is not rendered.

## Cases With Incoming Healing

NDui places its internal absorb after incoming healing. MiniAbsorbOverlay does not use NDui's incoming-healing texture as its anchor; it always starts at the current-health texture.

This difference causes the current external overlay to underestimate overflow when incoming healing is present.

### Health 80, Incoming Healing 10, Absorb 10

```text
NDui internal                MiniAbsorbOverlay external
[████████████████▒▒▓▓]
 Health 80          10 10
                    |  +-- Absorb
                    +----- Incoming healing
```

NDui renders incoming healing from `80` to `90`, then absorb from `90` to `100`. MiniAbsorbOverlay renders its absorb from `80` to `90`, entirely before the external clipping boundary, so nothing is shown externally.

### Health 80, Incoming Healing 10, Absorb 20

Actual predicted total:

```text
80 + 10 + 20 = 110
```

Current code renders:

```text
NDui internal                MiniAbsorbOverlay external
[████████████████▒▒▓▓]
 Health 80          10 10
```

The ideal external result would be:

```text
NDui internal                MiniAbsorbOverlay external
[████████████████▒▒▓▓]▓▓
                    10 10
```

MiniAbsorbOverlay currently starts at health `80` and draws absorb `20`, producing a segment from `80` to `100`. It does not enter the external clipping region, so the overflowing `10` is not shown.

### Health 80, Incoming Healing 10, Absorb 40

The actual overflow is:

```text
80 + 10 + 40 - 100 = 30
```

Current code renders:

```text
NDui internal                MiniAbsorbOverlay external
[████████████████▒▒▓▓]▓▓▓▓
 Health 80          10 10   20
                    |  |    +-- MiniAbsorbOverlay external
                    |  +------- NDui internal absorb
                    +---------- NDui incoming healing
```

MiniAbsorbOverlay draws from `80` to `120`. Clipping leaves only `100` to `120`, so it shows `20` instead of the actual overflow `30`.

The missing external amount equals the incoming healing that contributed to filling the health bar.

### Health 80, Incoming Healing 30, Absorb 10

NDui clamps incoming healing at the health-bar boundary:

```text
NDui internal                MiniAbsorbOverlay external
[████████████████▒▒▒▒]
 Health 80          Visible incoming healing 20
```

The absorb is beyond the predicted maximum-health boundary, but MiniAbsorbOverlay draws its segment from `80` to `90`. Because that segment remains before the external clipping boundary, no external absorb is visible.

## Confirmed Behavior

Without incoming healing:

```text
NDui internal                MiniAbsorbOverlay external
[Current health + internal absorb]external overflow absorb
```

The internal and external absorb regions do not overlap.

With incoming healing:

```text
Current health -> NDui incoming healing -> NDui internal absorb
Current health -> MiniAbsorbOverlay complete absorb
```

MiniAbsorbOverlay underestimates the external amount because its geometric starting point does not include NDui's incoming-healing segment.

## Additional NDui Indicator

NDui also creates `overDamageAbsorbIndicator` at the right edge of its health bar:

```lua
overAbsorb:SetPoint("TOPLEFT", self.Health, "TOPRIGHT", -5, 2)
overAbsorb:SetPoint("BOTTOMLEFT", self.Health, "BOTTOMRIGHT", -5, -2)
```

This indicator may visually overlap the beginning of MiniAbsorbOverlay's external bar. It is a glow indicator, not a duplicate rendering of the internal absorb amount.

## Source Files

- MiniAbsorbOverlay core: `MiniAbsorbOverlay.lua`
- MiniAbsorbOverlay NDui adapter: `Adapters/NDui.lua`
- NDui prediction frame construction: `Interface/AddOns/NDui/Modules/UFs/Functions.lua`
- NDui oUF prediction updates: `Interface/AddOns/NDui/Libs/oUF/Elements/healthprediction.lua`
