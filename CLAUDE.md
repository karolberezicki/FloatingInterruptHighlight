# FloatingInterruptHighlight — Developer Reference

World of Warcraft addon (Interface 120000). Floating icon that shows the player's interrupt spell and highlights when the target casts an interruptible spell.

## File Structure

```
FloatingInterruptHighlight/
├── FloatingInterruptHighlight.toc      # Addon metadata, load order
├── Core.lua                            # AceAddon init, options panel, slash commands
├── FloatingInterruptHighlight.xml      # Frame templates (FIHFrame + GlowOverlay)
├── FloatingInterruptHighlight.lua      # Frame behavior (two mixins, event handling)
└── Libs/
    ├── LibStub/
    ├── CallbackHandler-1.0/
    ├── AceAddon-3.0/
    ├── AceDB-3.0/
    ├── AceDBOptions-3.0/
    ├── AceConfig-3.0/                  # Includes Registry, Dialog, Cmd
    ├── AceConsole-3.0/
    ├── AceEvent-3.0/
    ├── AceGUI-3.0/
    └── Ace3.xml                        # Library loader
```

## Architecture

### Load Order

1. `LibStub` + `Ace3.xml` — library bootstrap
2. `Core.lua` — creates AceAddon, registers DB defaults, builds options panel
3. `FloatingInterruptHighlight.xml` — creates the `FIHFrame` global frame, applies mixins
4. `FloatingInterruptHighlight.lua` — loaded via the XML `<Script>` tag, defines the two mixins before XML instantiation triggers `OnLoad`

### Two Mixins

**`FIHGlowMixin`** — Applied to the `GlowOverlay` child frame. Manages the proc-style glow animation (FlipBook) and a color-coded cast timer (`C_CurveUtil` color curve: red → yellow → white). The `Update(active, notInterruptible, duration)` method is the single entry point — it starts/stops the animation and uses `SetAlphaFromBoolean` to handle the `notInterruptible` secret.

**`FIHFrameMixin`** — Applied to the main `FIHFrame`. Handles interrupt spell detection, cast state tracking, cooldown management, visibility logic, dragging, and option application.

### Lifecycle

```
OnLoad → RegisterEvent("PLAYER_LOGIN") + Masque setup
  ↓
PLAYER_LOGIN → Initialize() → register all events, DetectInterruptSpell, ApplyOptions
  ↓
Runtime: events → UpdateCastState / UpdateCooldown / UpdateVisibility / DetectInterruptSpell
```

`Core.lua:OnInitialize()` creates the AceDB and calls `FIHFrame:OnAddonLoaded()` to hand the profile reference to the frame before any events fire.

## Key Patterns

### Blizzard Secrets

Two pieces of combat data are protected as "secrets" in TWW:

1. **`notInterruptible`** — returned by `UnitCastingInfo`/`UnitChannelInfo` but cannot be used in show/hide branching. Handled with `SetAlphaFromBoolean(notInterruptible, 0, 1)` which sets alpha to 0 (invisible) for uninterruptible casts and 1 (visible) for interruptible casts without conditional logic.

2. **Interrupt cooldown** — `C_Spell.GetSpellCooldown()` only returns the GCD (1.5s) for interrupt spells, never the real cooldown. Tracked manually:
   - `UNIT_SPELLCAST_SUCCEEDED` with `unit == "player"` and matching `spellID` triggers `OnInterruptUsed()`
   - `OnInterruptUsed()` stores `GetTime()` + hard-coded base cooldown from the `InterruptSpells` lookup table
   - `CanInterruptBeforeCastEnds(duration)` compares remaining cooldown against `duration:GetRemainingDuration()`
   - Note: talent-modified cooldowns will be slightly inaccurate (uses base values)

### Interrupt Spell Detection

`InterruptSpells` maps `spellID → baseCooldownSeconds` for all 16 class/pet interrupts. `InterruptSpellIDs` is a flat ordered list — `DetectInterruptSpell()` iterates it and picks the first spell found via `C_SpellBook.IsSpellInSpellBook()`. Re-runs on `SPELLS_CHANGED` (talent swap) and `UNIT_PET` (pet summon/dismiss).

### Visibility Model

Simple two-state model:
- **Unlocked** — frame is always visible with mouse enabled for dragging
- **Locked** — frame is hidden by default, shown only when target is casting and `CanInterruptBeforeCastEnds()` returns true

`ShowForCast`/`HideForCast` are no-ops when unlocked (so dragging isn't disrupted by cast events).

### Cast State Detection

`UpdateCastState()` checks `UnitCastingInfo("target")` then `UnitChannelInfo("target")`. Uses TWW-era `UnitCastingDuration`/`UnitChannelDuration` which return duration objects with `:GetRemainingDuration()` and `:EvaluateRemainingDuration()`. Nil-guarded against race conditions where the cast ends between the info and duration calls.

### Masque Integration

Optional. On `OnLoad`, if Masque is present:
- Snapshots existing regions into `__baselineRegions`
- Creates a Masque group with custom type `"FIH"` providing `Icon` + `Cooldown`
- Registers a callback to re-apply options and hide rogue Masque regions on disable
- When Masque is active, native border rendering is bypassed; when disabled, border falls back to `BackdropTemplate`

### Options Panel (Core.lua)

Built with AceConfig-3.0. Sections: General, Display (icon/border), Cooldown, Position (strata/anchor/parent), Profiles. The border section shows a Masque override warning and hides color/thickness when Masque is active via `IsMasqueActive()`.

## Events

| Category | Events | Handler |
|----------|--------|---------|
| Cast tracking | `PLAYER_TARGET_CHANGED`, `UNIT_SPELLCAST_START/STOP/DELAYED/FAILED/INTERRUPTED/INTERRUPTIBLE/NOT_INTERRUPTIBLE`, `UNIT_SPELLCAST_CHANNEL_START/STOP/UPDATE` | `UpdateCastState()` (filtered to `unit == "target"`) |
| Spell detection | `SPELLS_CHANGED`, `UNIT_PET` | `DetectInterruptSpell()` |
| Cooldown swipe | `SPELL_UPDATE_COOLDOWN` | `UpdateCooldown()` + `UpdateCastState()` |
| Interrupt usage | `UNIT_SPELLCAST_SUCCEEDED` | `OnInterruptUsed()` (filtered to `unit == "player"` + matching spellID) |

## Saved Variables

`FloatingInterruptHighlightDB` — AceDB-3.0 format. Profile defaults:

```lua
{
    enabled = true,
    locked = false,
    iconSize = 48,
    alpha = 1,
    cooldown = { showSwipe = true, edge = true, bling = true, HideNumbers = false },
    border = { show = true, thickness = 2, color = { r = 0, g = 0, b = 0 } },
    position = { strata = 3, parent = "UIParent", point = "CENTER", relativePoint = "CENTER", X = 0, Y = 0 },
}
```

## Slash Commands

- `/fih` — open settings
- `/fih lock` / `/fih unlock` — toggle/set lock state
- `/fih toggle` — enable/disable
- `/fih reload` — restart the addon

## Known Limitations

- **Cooldown accuracy** — Base cooldown durations are hard-coded. Talents that reduce interrupt cooldowns (e.g. Rogue's Retractable Hook) will make the tracking slightly pessimistic (shows icon a bit late). No WoW API exposes the modified cooldown for interrupt spells.
- **Single interrupt** — Only tracks one interrupt per character (first known from the ordered list). Classes with two interrupts (e.g. Druid with both Skull Bash and Solar Beam) will only track one.
- **Pet interrupt detection** — Uses `C_SpellBook.IsSpellInSpellBook()` which covers pet spells, but pet dismissal/death between `UNIT_PET` events may cause stale state until the next detection pass.
