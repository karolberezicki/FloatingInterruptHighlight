# Floating Interrupt Highlight

A floating icon that displays your interrupt ability and highlights with a glow animation when your target is casting an interruptible spell.

## Features

- **Floating interrupt icon** — Automatically detects your class/spec interrupt spell and displays it as a movable icon
- **Glow highlight** — Proc-style glow animation plays when your target begins an interruptible cast
- **Cast timer** — Color-coded countdown timer on the overlay (red → yellow → white) shows remaining cast time
- **Smart cooldown awareness** — The icon only appears if your interrupt will be off cooldown before the enemy cast finishes
- **Cooldown swipe** — Optional cooldown sweep animation on the icon after using your interrupt
- **Masque support** — Fully compatible with Masque for icon skinning
- **Drag to position** — Unlock the frame to freely drag it anywhere on screen; lock it to hide until needed
- **Profile support** — Full AceDB profile system for per-character or shared settings

## How It Works

When **unlocked**, the icon is always visible so you can position it where you want.

When **locked**, the icon is completely hidden until your target begins casting an interruptible spell. If your interrupt is on cooldown and won't be ready before the cast finishes, the icon stays hidden — no point showing what you can't use.

The addon automatically detects which interrupt spell you have based on your class and spec. Pet interrupts (Spell Lock, Axe Toss) are supported as well.

### Supported Interrupts

| Class | Spell |
|-------|-------|
| Death Knight | Mind Freeze |
| Demon Hunter | Disrupt |
| Druid | Skull Bash / Solar Beam |
| Evoker | Quell |
| Hunter | Counter Shot / Muzzle |
| Mage | Counterspell |
| Monk | Spear Hand Strike |
| Paladin | Rebuke |
| Priest | Silence |
| Rogue | Kick |
| Shaman | Wind Shear |
| Warlock | Spell Lock / Axe Toss (pet) |
| Warrior | Pummel |

## Slash Commands

- `/fih` — Open the settings panel
- `/fih lock` — Toggle frame lock
- `/fih unlock` — Unlock the frame
- `/fih toggle` — Enable or disable the addon
- `/fih reload` — Restart the addon

## Settings

- **Icon size and alpha**
- **Border color and thickness** (disabled when using a Masque skin)
- **Cooldown swipe**, edge glow, bling animation, and number visibility
- **Frame strata** and anchor point configuration
- **Custom frame parent** for anchoring to other UI elements
- **Profiles** — create, copy, and switch between profiles

## Attribution

This addon was inspired by and built upon ideas from two existing addons:

- **[ActionBar Interrupt Highlight](https://www.curseforge.com/wow/addons/actionbarinterrupthighlight)** — Interrupt spell detection, cast tracking logic, and glow overlay animation
- **[Simple Assisted Combat Icon](https://www.curseforge.com/wow/addons/simple-assisted-combat-icon)** — Floating frame architecture, drag system, options panel structure, and Masque integration
