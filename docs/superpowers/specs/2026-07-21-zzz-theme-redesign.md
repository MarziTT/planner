---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: fe7e0515290b04070c7aa137e3bf58e6_db76959484d611f1be89525400287e28
    ReservedCode1: PuV951vesu6bK+8y7nde7gDe5MgLw5OwuN//whvhvXOlYoMZ98II5r1MZfSTZ3/kYy0Hbk1Ho76NVM1F13vxxsJetrU+jcpufTN4Yq4qBt+TPpybcC8axFgsTDS5Agtdq7qi0jAApn2913CHHvoRXr+xY+A0en+06uwQ1lt94SZ+JTbWaU1ddiyRSZg=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: fe7e0515290b04070c7aa137e3bf58e6_db76959484d611f1be89525400287e28
    ReservedCode2: PuV951vesu6bK+8y7nde7gDe5MgLw5OwuN//whvhvXOlYoMZ98II5r1MZfSTZ3/kYy0Hbk1Ho76NVM1F13vxxsJetrU+jcpufTN4Yq4qBt+TPpybcC8axFgsTDS5Agtdq7qi0jAApn2913CHHvoRXr+xY+A0en+06uwQ1lt94SZ+JTbWaU1ddiyRSZg=
---

# ZZZ Theme Redesign — Design Spec

**Date:** 2026-07-21  
**Status:** Approved  
**Author:** Agent + User  

## 1. Background

All themes (Sakura, Ocean, Forest, Desert Dusk, Aurora, ZZZ) currently share the same Material Design component layout. The only per-theme differences are three color tokens (seed, lightMuted, darkMuted). The ZZZ theme additionally shows a GIF background on event tiles via `isZzz` boolean branching, but the card shape, typography, spacing, and overall visual language are identical to other themes.

The user wants ZZZ to have a **visually distinct** theme informed by the Kamen Rider ZZZ (Zeztz) IP: lucid dreaming, dream capsules, code organizations, futuristic HUD/terminal aesthetics.

## 2. Design Direction

**"Dream Agent HUD Terminal"** — every UI element evokes a secret agent's lucid dream command interface.

- **Tone:** Futuristic / Industrial / HUD  
- **Key metaphors:** Dream capsule, driver belt, code commands, dream archives, neon terminals  
- **What someone remembers:** Events look like classified dream-capsule files on a glowing terminal

## 3. Color System

| Token | Value | Usage |
|-------|-------|-------|
| Primary (red) | `#E53935` | Left-edge glow bar, accent text, active indicators |
| Neon cyan | `#00E5FF` | Stroke outlines, secondary highlights, code annotations |
| Deep purple | `#170F17` | Background base |
| Surface dark | `#0D0B12` | Card background, darker variant |
| Text primary | `#E8E0F0` | Event titles, labels |
| Text muted | `#7B6E88` | Secondary info, timestamps |

## 4. Component Designs

### 4.1 Event Tile — "Dream Capsule Card"

- **Shape:** Custom `ClipPath` with 4-corner bevel (12px chamfer), giving a hexagonal capsule silhouette
- **Left glow bar:** 4px red gradient strip along the left edge (`#E53935` → transparent)
- **Right GIF:** Full-bleed background GIF with 0.6 opacity dark overlay
- **Title prefix:** `Z-{event.id}` monospace code before the title (read-only, generated from event ID)
- **Neon stroke:** 1.5px cyan outline (`#00E5FF`) on the capsule border
- **Scanline texture:** Subtle horizontal scanlines overlaid on the card

### 4.2 Event Tile — Tag Chips

- **Shape:** Pill/capsule (rounded ends, straight middle), matching the "dream capsule" metaphor
- **Stroke:** 1px with tag's own color at 0.7 alpha
- **Fill:** Tag color at 0.15 alpha
- **Dot:** 6px circle in tag color, no text color override

### 4.3 Time Picker — HUD Terminal Panel

- **Display mode (collapsed):** A monospace command line reading:  
  `> SET_TIME: 21:30  > SET_DATE: 2026.07.21` with a blinking cursor
- **Date/time edit mode:** Full-screen modal styled as a "code password dial" — large monospace numbers on a dark background with cyan accents
- **LED marquee:** A thin red LED ticker bar at the top of the dashboard, scrolling the selected date: `■■■ 2026-07-21 TUE ■■■ ACTIVE DREAM SESSION ■■■`

### 4.4 Buttons — "Code Commands"

- Monospace font (`JetBrains Mono` or system mono)
- `>` arrow prefix before text (e.g., `> SAVE`, `> CANCEL`)
- Background: dark with 1px cyan border
- Active state: red glow background

### 4.5 Dashboard Background

- Base: `#170F17` deep purple-black
- Scanline texture overlay (repeating horizontal lines at 2px spacing, 0.03 opacity white)
- No Material card containers — use spacing and glow lines for grouping

## 5. Architecture

### Theme-aware branching

Components will use a `isZzz` boolean (already available via `ThemeState.preset == kamenRiderZzz`) to switch between:

- **Standard render** (current Material path) — all other themes
- **ZZZ render** (new HUD/capsule path) — only when `isZzz` is true

No separate widget tree — same `_EventTile`, `_ModernTimePicker`, etc., with conditional rendering branches.

### Files to modify

| File | Changes |
|------|---------|
| `planner_dashboard.dart` | Event tile ZZZ variant, tag chips ZZZ variant, LED marquee, scanline background |
| `theme_controller.dart` / `app_theme.dart` | Additional ZZZ-specific theme tokens if needed |
| New: `widgets/zzz/` | Optional: extract ZZZ widget variants into a new directory |

## 6. Acceptance Criteria

1. Switch theme to ZZZ — event cards are capsule-shaped with beveled corners, not rounded rectangles
2. Cards show cyan neon stroke + left red glow bar
3. Title shows `Z-{id}` prefix in monospace
4. Tag chips are pill/capsule-shaped with colored stroke
5. Time display shows monospace `> SET_TIME: HH:MM > SET_DATE: YYYY.MM.DD` format
6. Tapping time opens full-screen code-password-style dial
7. Dashboard top shows red LED marquee scrolling current date
8. Buttons show `> LABEL` monospace style
9. Background has scanline texture
10. Other themes (Sakura, Ocean, etc.) render exactly as before — no regression

## 7. Out of Scope

- Motion/animation for capsule morphing
- Sound effects
- Real-time scanline animation
- GIF resource changes
*（内容由AI生成，仅供参考）*
