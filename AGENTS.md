# MiniAbsorbOverlay Development Instructions

This file defines the rules for automated agents working in this repository. Keep every change focused, preserve existing behavior, and prefer the project's established structure.

## Project Overview

MiniAbsorbOverlay is a World of Warcraft unit-frame enhancement addon that displays absorb shields as an overlay on health bars.

The project supports Blizzard's default unit frames and NDui party frames.

## Language

- Write project documentation and agent-facing instructions in English.
- Keep Lua identifiers, API names, commands, and technical terms in their original form.
- Keep code comments concise and use them only to explain non-obvious compatibility or implementation constraints.

## Project Structure

```text
MiniAbsorbOverlay.toc
MiniFramework.lua
MiniAbsorbOverlay.lua
Adapters/
    BlizzardUI.lua
    NDui.lua
```

File responsibilities:

- `MiniFramework.lua`: Addon initialization and shared helper functionality.
- `MiniAbsorbOverlay.lua`: Creation, caching, and updating of absorb overlays. It must not contain framework-specific frame-discovery logic.
- `Adapters/BlizzardUI.lua`: Integration with Blizzard unit frames, Compact Frames, the Personal Resource Display, and the native over-absorb glow.
- `Adapters/NDui.lua`: NDui party-frame discovery, event handling, and heal-prediction integration.
- `MiniAbsorbOverlay.toc`: Addon metadata and Lua file load order.

## Architecture Boundaries

- The core layer is responsible only for rendering and updating absorb overlays.
- Frame discovery, event registration, third-party field access, and framework lifecycle handling belong in the corresponding adapter.
- Do not reference `PlayerFrame`, `TargetFrame`, `CompactUnitFrame`, `oUF_Party`, or NDui internals from the core layer.
- Add support for another unit-frame system through a dedicated adapter instead of adding framework-specific logic to the core.
- The project is small. Do not introduce an adapter registry, inheritance hierarchy, factory, or another abstraction without a concrete reduction in complexity.

## WoW API Compatibility

- Before changing an API call, verify that it is available in the game versions declared by the TOC file.
- Account for Midnight secret-value restrictions. Do not perform ordinary Lua arithmetic, comparisons, or conditional conversion on values that may be secret.
- Prefer the following APIs when detecting clamped absorb shields:

  ```lua
  CreateUnitHealPredictionCalculator()
  UnitGetDetailedHealPrediction(unit, "player", calculator)
  calculator:GetDamageAbsorbs()
  ```

- `damageAbsorbClamped` may be a secret boolean. Use a Blizzard-provided safe API, for example:

  ```lua
  absorb:SetAlphaFromBoolean(damageAbsorbClamped, 1, 0)
  ```

- The NDui adapter must not depend on `HealthPrediction.overDamageAbsorbIndicator`, its alpha value, or the event execution order between NDui and this addon.
- Use `C_Timer.After(0)` only when waiting for frame creation or party-member reassignment. Do not use it for normal unit absorb-event updates.
- Avoid unnecessary temporary tables, closures, and repeated object creation in high-frequency event handlers.

## Lua Style

- Use tabs to preserve the indentation style of the existing Lua files.
- Prefer clear, direct implementations over unnecessary indirection.
- Use `local` to limit variable and function scope.
- Cache reusable frames, calculators, and related objects instead of recreating them during high-frequency events.
- When caching by frame object, consider weak-key tables so the cache does not prevent frame objects from being collected.
- Do not leave `print` debugging output in production code.
- Do not silently swallow errors or hide invalid state with empty handling branches.
- Preserve the existing EmmyLua annotation style, including `---@param`, `---@return`, and `---@class`.

## TOC and Naming

- Keep the addon directory, TOC file, and main Lua file named `MiniAbsorbOverlay`.
- Use `addon.AbsorbOverlay` for the addon's private core object.
- After adding or renaming a Lua file, update and verify `MiniAbsorbOverlay.toc`.
- The TOC load order must keep dependencies before their consumers:

  ```text
  MiniFramework.lua
  MiniAbsorbOverlay.lua
  Adapters\BlizzardUI.lua
  Adapters\NDui.lua
  ```

- Preserve the original author and project links documented in the README.

## Change Policy

- Prefer minimal, backward-compatible changes.
- Do not refactor unrelated code as part of a focused task.
- Do not guess third-party addon field structures. Verify the actual implementation of the relevant version before adapting to it.
- Do not modify, delete, or overwrite unrelated user changes.
- Do not perform destructive actions, delete files, or rewrite history unless the user explicitly requests it.

## Validation

After changing Lua files, run at least:

```bash
luac -p \
  MiniFramework.lua \
  MiniAbsorbOverlay.lua \
  Adapters/BlizzardUI.lua \
  Adapters/NDui.lua
```

Also verify:

- Every file referenced by the TOC exists.
- The TOC load order is correct.
- No legacy addon identifiers remain.
- The core file has no new dependency on a specific UI framework.
- The NDui adapter has not regained a dependency on NDui's absorb-indicator alpha or internal heal-prediction fields.

Local syntax checks do not replace in-game testing. Changes involving unit frames, event order, absorb prediction, or secret values must also be validated in the game.

## Original Project Attribution

- Write README files and other project documentation in English.
- Preserve the original author name: Verubato (Verz).
- Preserve the original GitHub repository:
  `https://github.com/Verubato/mini-overshields`
- Preserve the original CurseForge page:
  `https://www.curseforge.com/wow/addons/miniovershields`
