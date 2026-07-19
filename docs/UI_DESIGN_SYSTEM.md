# Fallen Earth — UI Design System

> **Aesthetic:** Grim post-apocalyptic sci-fi (Shadowrun × Cthulhu). Rust, neon, bioluminescence, decay, and hard-won hope. Dark backgrounds with saturated accent glows, corroded metal, and organic-cybernetic hybrid details.

---

## 1. Color Palette

### 1.1 Semantic Mapping

| Token | Usage | Hex | Godot Color |
|---|---|---|---|
| `--bg-deep` | Main backgrounds, panels | `#0A0A12` | `Color(0.04, 0.04, 0.07)` |
| `--bg-surface` | Cards, containers | `#12121C` | `Color(0.07, 0.07, 0.11)` |
| `--bg-elevated` | Hovered/active panels, dropdowns | `#1A1A28` | `Color(0.10, 0.10, 0.16)` |
| `--border-subtle` | Default borders | `#2A2A3C` | `Color(0.16, 0.16, 0.24)` |
| `--border-strong` | Focus, active borders | `#4A4A6A` | `Color(0.29, 0.29, 0.42)` |

### 1.2 Accent System

| Token | Hex | Usage |
|---|---|---|
| `--accent-primary` | `#D4884A` — Rusted gold/amber | Primary buttons, headers, key numbers |
| `--accent-secondary` | `#5A8FB0` — Faded steel blue | Secondary controls, links |
| `--accent-danger` | `#C44040` — Blood rust | Delete, danger, hostile indicators |
| `--accent-success` | `#4A8C5C` — Toxic green | XP, healing, positive deltas |
| `--accent-neon` | `#6A5ACD` — Muted neon purple | Magic, Underearth, rift effects |

### 1.3 Text Colors

| Token | Hex | Usage |
|---|---|---|
| `--text-primary` | `#E8E8EE` (90% white) | Body text |
| `--text-secondary` | `#9A9AB0` (60% white) | Labels, hints, subtext |
| `--text-muted` | `#6A6A80` (40% white) | Placeholder, disabled |
| `--text-accent` | `#D4884A` | Gold stats, titles |
| `--text-danger` | `#C44040` | Damage numbers, warnings |
| `--text-success` | `#4A8C5C` | Healing numbers, buffs |
| `--text-link` | `#5A8FB0` | Clickable text |

### 1.4 Status Colors

| Token | Hex | Usage |
|---|---|---|
| `--hp-bar` | `#C44040` / `#8A2828` (fill/bg) | Health bars |
| `--mp-bar` | `#4A6A9A` / `#2A3A5A` (fill/bg) | Mana/energy bars |
| `--xp-bar` | `#4A8C5C` / `#2A4A34` (fill/bg) | XP bars |
| `--shield` | `#5A8FB0` | Shield/armor overlays |
| `--rarity-common` | `#9A9AB0` | Common item border |
| `--rarity-uncommon` | `#4A8C5C` | Uncommon item border |
| `--rarity-rare` | `#5A8FB0` | Rare item border |
| `--rarity-epic` | `#6A5ACD` | Epic item border |
| `--rarity-legendary` | `#D4884A` | Legendary item border |

### 1.5 Overlay / Backdrop

| Token | Hex | Usage |
|---|---|---|
| `--overlay-dark` | `rgba(4, 4, 8, 0.85)` | Pause menu, full-screen overlays |
| `--overlay-light` | `rgba(10, 10, 18, 0.60)` | Modal dialog backdrops |
| `--glow-primary` | `#D4884A` | Neon glow for interactive highlights |
| `--glow-rift` | `#6A5ACD` | Rift portal glow effects |

---

## 2. Typography

### 2.1 Font Stack

| Role | Font | Fallback | Source |
|---|---|---|---|
| **Headings / Display** | `Pixel Cyr` or custom pixel bitmap | Monospace bold | Bundled `.ttf` in `assets/fonts/` |
| **Body / UI text** | System (Noto Sans UI) | Sans-serif | Engine default |
| **Stats / Numbers** | Monospace or pixel condensed | Monospace | Bundled `.ttf` `assets/fonts/` |
| **Lore / Code** | Serif pixel | Serif | Bundled `.ttf` |

### 2.2 Size Scale

**Headings:**
| Token | Size (px) | Wt | LH | Usage |
|---|---|---|---|---|
| `--fs-hero` | 42 | 800 | 48 | Splash titles, major headers |
| `--fs-h1` | 28 | 700 | 34 | Panel titles, menu headers |
| `--fs-h2` | 22 | 700 | 28 | Section headers within panels |
| `--fs-h3` | 18 | 600 | 24 | Subsection headers, stat labels |

**Body:**
| Token | Size (px) | Wt | LH | Usage |
|---|---|---|---|---|
| `--fs-body` | 14 | 400 | 20 | Primary body text |
| `--fs-small` | 12 | 400 | 16 | Labels, secondary info |
| `--fs-tiny` | 10 | 400 | 14 | Tooltips, buff icons, corner text |
| `--fs-stat` | 16 | 700 | 20 | Character stats, numbers |
| `--fs-button` | 16 | 600 | 20 | Button labels |

### 2.3 Outline / Glow

| Token | Value | Usage |
|---|---|---|
| `--outline-size` | 2 px | Standard text outline (black) for readability on all backgrounds |
| `--outline-accent` | 3 px | Gold/neon glowing text (titles, special items) |
| `--outline-muted` | 1 px | Tiny labels, minimap text |

---

## 3. Spacing & Layout Grid

### 3.1 Base Unit

```
--unit: 4 px
```

All spacing is derived from this 4 px base unit.

### 3.2 Spacing Scale

| Token | Value | Usage |
|---|---|---|
| `--space-xs` | 4 px (1u) | Tight icon padding, inner gaps |
| `--space-sm` | 8 px (2u) | Element spacing, container padding |
| `--space-md` | 12 px (3u) | Between grouped controls |
| `--space-lg` | 16 px (4u) | Section padding, margins |
| `--space-xl` | 24 px (6u) | Panel padding |
| `--space-2xl` | 32 px (8u) | Between major UI sections |
| `--space-3xl` | 48 px (12u) | Page-level margins |

### 3.3 Layout Grid

| Token | Value | Usage |
|---|---|---|
| `--grid-columns` | 12 | Responsive column grid |
| `--grid-gutter` | 16 px | Column gaps |
| `--grid-margin` | 24 px | Edge margins |
| `--content-max-w` | 1280 px | Max panel width |

### 3.4 Container Sizes

| Component | Width | Height | Notes |
|---|---|---|---|
| **Top bar** | 45% of screen | 56 px | Limited to left side to avoid minimap overlap |
| **Resource bars** | 260 px | 18 px ea | Three stacked (HP/MP/XP) |
| **Minimap** | 200 px × 200 px | — | Top-right corner |
| **Hotbar** | Dynamic | 80 px | Centered bottom |
| **Side panel (quest)** | 250 px | Dynamic | Right edge docked |
| **Character menu** | 1280 × 720 | — | Fullscreen overlay |
| **Inventory cell** | 40 px × 40 px | — | Wyvernbox grid |

---

## 4. Component Library

### 4.1 Buttons

**Base dimensions:**
- Height: 40 px (small: 32 px, large: 50 px)
- Min width: 120 px (small: 80 px, large: 180 px)
- Corner radius: 4 px
- Border width: 2 px

**States:**

| State | bg_color | border_color | text_color | corner_radius |
|---|---|---|---|---|
| **Idle** | `#201830` | `#6A5090` | `#FFEECC` | 4 |
| **Hover** | `#302848` | `#D4884A` | `#FFFFFF` | 4 |
| **Pressed** | `#181028` | `#D4884A` | `#FFEECC` | 4 |
| **Disabled** | `#14141E` | `#2A2A3C` | `#6A6A80` | 4 |
| **Focus** | `#201830` | `#FFFFFF` | `#FFEECC` | 4 |

**`StyleBoxFlat` GDScript template:**
```gdscript
static func make_button_style(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_width_left = 2
    sb.border_width_top = 2
    sb.border_width_right = 2
    sb.border_width_bottom = 2
    sb.border_color = border
    sb.corner_radius_top_left = radius
    sb.corner_radius_top_right = radius
    sb.corner_radius_bottom_left = radius
    sb.corner_radius_bottom_right = radius
    return sb
```

**Button function variants:**

| Variant | bg_color | border_color | text_color | Usage |
|---|---|---|---|---|
| **Primary** | `#201830` | `#D4884A` | `#FFEECC` | Main CTA (New Game, Upgrade, Confirm) |
| **Secondary** | `#1A1A28` | `#5A8FB0` | `#B0C0E0` | Alternative action (Options, Back) |
| **Danger** | `#3A1818` | `#C44040` | `#FFCCCC` | Destructive action (Delete, Reset) |
| **Success** | `#1A2E1E` | `#4A8C5C` | `#CCEECC` | Confirm purchase, craft |
| **Ghost** | Transparent | Transparent | `#9A9AB0` → `#E8E8EE` hover | Tab bar, inline controls |

### 4.2 Panels & Windows

**Panel (Container):**
| Property | Value |
|---|---|
| bg_color | `#0A0A12` (opacity 0.85–0.95) |
| border_color | `#2A2A3C` |
| border_width | 1 px |
| corner_radius | 6 px |
| Theme style | `panel` |

**Window (Dialog):**
| Property | Value |
|---|---|
| bg_color | `#12121C` (opacity 0.95) |
| border_color | `#4A4A6A` |
| border_width | 2 px |
| corner_radius | 8 px |
| Title bar | `--accent-primary` text, 18 px |
| Close button | Ghost variant, top-right |

**Tooltip:**
| Property | Value |
|---|---|
| bg_color | `#0E0E1A` |
| border_color | `#4A4A6A` |
| border_width | 1 px |
| corner_radius | 3 px |
| Padding | 8 px (2u) |

### 4.3 Text Fields & Inputs

**LineEdit:**
| Property | Value |
|---|---|
| bg_color (normal) | `#0A0A12` |
| border_color (normal) | `#2A2A3C` |
| border_color (focus) | `#D4884A` |
| border_width | 2 px |
| corner_radius | 4 px |
| font_color | `#E8E8EE` |
| placeholder_color | `#6A6A80` |
| cursor_color | `#D4884A` |
| Min height | 36 px |
| Padding | 8 px horizontal |

**Focus style (overrides normal border):**
```gdscript
var focus_sb := StyleBoxFlat.new()
focus_sb.bg_color = Color(0.04, 0.04, 0.07)
focus_sb.border_width_all = 2
focus_sb.border_color = Color(0.83, 0.53, 0.29)  # --accent-primary
focus_sb.corner_radius_all = 4
line_edit.add_theme_stylebox_override("focus", focus_sb)
```

### 4.4 Progress Bars

**Resource bars (HP/MP/XP):**

| Property | Value |
|---|---|
| Background | `#0A0A12`, border 1 px `#2A2A3C`, corner radius 3 px |
| Fill (HP) | `#C44040` → gradient to `#8A2828` |
| Fill (MP) | `#4A6A9A` → gradient to `#2A3A5A` |
| Fill (XP) | `#4A8C5C` → gradient to `#2A4A34` |
| Height | 18 px |
| show_percentage | `true` (was `false` — audit UX-11 fix) |
| Border radius (fill) | 2 px |

**Generic ProgressBar template:**
```gdscript
static func make_resource_bar(height: int, fill_color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(80, height)
    bar.show_percentage = false

    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.03, 0.03, 0.05, 0.9)
    bg.border_width_all = 1
    bg.border_color = Color(0.12, 0.12, 0.14, 0.8)
    bg.corner_radius_all = 3
    bar.add_theme_stylebox_override("background", bg)

    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.corner_radius_all = 2
    bar.add_theme_stylebox_override("fill", fill)

    return bar
```

### 4.5 Sliders

| Property | Value |
|---|---|
| Grabber color | `#D4884A` |
| Grabber radius | 8 px circle |
| Tick color | `#2A2A3C` |
| Fill (left) color | track color to `#D4884A` gradient |
| Tick interval | Per-setting (volume: 10, graphics: whole numbers) |

### 4.6 Scroll Containers

| Property | Value |
|---|---|
| Scrollbar bg | `#0A0A12` |
| Scrollbar grabber | `#3A3A5A` |
| Grabber hover | `#5A5A7A` |
| Grabber width | 8 px |
| Grabber corner_radius | 4 px |
| Hide scrollbar | When not scrolling |

### 4.7 Inventory Cells (Wyvernbox)

| Property | Value |
|---|---|
| Cell size | 40 px × 40 px |
| Cell bg (empty) | `#0A0A12` |
| Cell bg (occupied) | `#12121C` |
| Selected border | `#D4884A`, 2 px (`selected_cell.tres`) |
| Rarity borders | Per `--rarity-*` colors, 1 px |
| Font outline | 1 px, black |

### 4.8 Icons & Indicators

**Minimap icons (custom `_draw()`):**
| Element | Color | Shape | Size |
|---|---|---|---|
| Player | `#66D9FF` | Circle + crosshair | 5.6 px radius |
| Current hex | `#FFFFFF` | Outline only | 7 px hex |
| Discovered hex | `#73806A` | Filled hex | 7 px hex |
| Rift | `#FFD930` | Circle + X | 2.8 px radius |
| Riftspire | `#FF8026` | Circle + star | 4.2 px radius |
| Town | Faction hue | Filled circle | 3.5 px radius |
| Mob (hostile) | `#FF8066` | Dot | 1.5 px radius |
| Mob (neutral) | `#B3D9B3` | Dot | 1.5 px radius |

**Buff/Debuff indicators:**
| Type | Shape | Border | Size |
|---|---|---|---|
| Buff | Rounded rect | `--accent-success` | 20 × 20 px |
| Debuff | Rounded rect | `--accent-danger` | 20 × 20 px |

---

## 5. Typography Implementation (Theme)

### 5.1 Theme `.tres` Structure

```gdscript
# A single Theme resource for the entire UI.
# Apply to the root scene's Control node.
var theme := Theme.new()

# Font sizes
theme.set_font_size("Label", "font_size", 14)       # --fs-body
theme.set_font_size("Button", "font_size", 16)       # --fs-button
theme.set_font_size("LineEdit", "font_size", 14)     # --fs-body

# Default colors
theme.set_color("Label", "font_color", Color(0.91, 0.91, 0.93))     # --text-primary
theme.set_color("Button", "font_color", Color(0.91, 0.91, 0.93))
theme.set_color("LineEdit", "font_color", Color(0.91, 0.91, 0.93))

# Default styles
var panel_bg := StyleBoxFlat.new()
panel_bg.bg_color = Color(0.04, 0.04, 0.07)
panel_bg.border_width_all = 1
panel_bg.border_color = Color(0.16, 0.16, 0.24)
panel_bg.corner_radius_all = 6
theme.set_stylebox("Panel", "panel", panel_bg)
theme.set_stylebox("PanelContainer", "panel", panel_bg)
```

### 5.2 Font Color Override Map

| Node Type | Keys to Override |
|---|---|
| `Label` | `font_color`, `font_outline_color`, `font_size` |
| `Button` | `font_color`, `font_hover_color`, `font_pressed_color`, `font_disabled_color`, `font_focus_color`, `font_size`, `outline_size`, `font_outline_color` |
| `LineEdit` | `font_color`, `font_placeholder_color`, `font_size`, `font_outline_color` |
| `ProgressBar` | `font_color`, `font_size` |
| `CheckBox` | `font_color`, `font_size` |

---

## 6. Accessibility Guidelines

### 6.1 Minimum Contrast Ratios

| Text Type | Required Ratio | Our Ratio | Pass? |
|---|---|---|---|
| Body text (`--text-primary` on `--bg-deep`) | 4.5:1 | `#E8E8EE` on `#0A0A12` → **~16:1** | ✅ |
| Muted text (`--text-muted` on `--bg-surface`) | 3:1 | `#6A6A80` on `#12121C` → **~4.5:1** | ✅ |
| Accent text (`--text-accent` on `--bg-deep`) | 4.5:1 | `#D4884A` on `#0A0A12` → **~8:1** | ✅ |
| Disabled text (`--text-muted` on `--bg-elevated`) | 3:1 | `#6A6A80` on `#1A1A28` → **~3.5:1** | ✅ |

> **Rule:** Do not reduce contrast below these thresholds. Use `--text-muted` only for non-critical labels, not actionable content.

### 6.2 Keyboard Navigation

| Requirement | Implementation |
|---|---|
| All interactive nodes `focus_mode != FOCUS_NONE` | Set `Control.FOCUS_ALL` on buttons, cells, inputs |
| Visible focus indicator | Apply `focus` stylebox override with `#FFFFFF` or `--accent-primary` 2 px border |
| Focus ring radius | Match element's corner radius |
| Tab order flows LTR, top-to-bottom | Use `focus_neighbor_left/right/top/bottom` = `"."` for grid cells |
| Grid inventory focus chains | Implement `find_valid_focus_neighbor()` per Wyvernbox pattern |

**Focus stylebox:**
```gdscript
var focus_sb := StyleBoxFlat.new()
focus_sb.border_width_all = 2
focus_sb.border_color = Color(1, 1, 1)  # White focus ring
focus_sb.corner_radius_all = 4
# Do NOT set bg_color — keep existing background visible
node.add_theme_stylebox_override("focus", focus_sb)
```

### 6.3 Scalable UI

| Requirement | Implementation |
|---|---|
| Base resolution target | 1920 × 1080 (stretch with `keep aspect`) |
| Min supported | 1280 × 720 |
| Max supported | 3840 × 2160 |
| Layout method | Containers + percent anchors, **never** fixed pixel offsets for positioning |
| Exception | Minimap/Hotbar size scales proportionally, not absolutely |
| `set_anchors_preset` | Use `Control.PRESET_FULL_RECT` for overlays, not `anchor_right = 1.0` |
| Text scaling | Use `add_theme_font_size_override` exclusively (not `rect_size` tricks) |

### 6.4 Color Blindness

| Consideration | Approach |
|---|---|
| Status indicators | Use **icon + color** (never color alone). HP=heart icon, MP=drop icon, XP=star icon |
| Rarity distinctions | Color + border pattern (solid, dashed, double for Common→Legendary) |
| Minimap elements | Shape-coded (circle=town, hex=discovered, cross=x rift) |
| Damage types | Color + label text (never tint-only) |

### 6.5 Text Readability

| Requirement | Value |
|---|---|
| Minimum body font size | 14 px (`--fs-body`) |
| Minimum UI label size | 12 px (`--fs-small`), only for secondary info |
| Outline (shadow) on all text | `font_outline_color = Color.BLACK`, `outline_size = 2` |
| Autowrap on dynamic text | `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` |
| Line height minimum | 1.4× font size for readability |

---

## 7. Implementation Priority (from Audit)

| Phase | Task | Files Affected | Est. Effort |
|---|---|---|---|
| **P0.1** | Create `Theme.tres` resource with all defaults | New: `assets/ui/Theme.tres` | 2h |
| **P0.2** | Acquire and bundle pixel font for headings | `assets/fonts/` | 1h |
| **P0.3** | Remove `FOCUS_NONE` from all interactive nodes | 6 scripts | 4h |
| **P0.4** | Add focus stylebox overrides + focus neighbors | 6 scripts | 3h |
| **P1.1** | Create `StyleBoxHelper.gd` for consistent StyleBoxFlat construction | New helper | 1h |
| **P1.2** | Migrate all button creation to `ButtonStyleHelper` | 8+ scripts | 3h |
| **P1.3** | Enable `show_percentage` on resource bars | `HUD.gd` | 0.25h |
| **P1.4** | Convert `anchor_right = 1.0` to `anchors_preset` | 6 files | 2h |
| **P2.1** | Add hover/disabled/pressed styles to all inline StyleBoxFlat | 6 `.tscn` files | 2h |
| **P2.2** | Replace custom tab bar in CharacterMenu with `TabContainer` | `CharacterMenu.gd` | 2h |
| **P2.3** | Add empty/loading/error states to dynamic UIs | 4 scripts | 2h |

---

## 8. Quick Reference: GDScript Snippets

### Apply theme to root
```gdscript
# In your main scene's _ready():
var theme := preload("res://assets/ui/Theme.tres")
get_tree().root.theme = theme
# Or per-Control:
$MyPanel.theme = theme
```

### Centralized color constants
```gdscript
# Place in autoload or global constants file
enum UI { BG_DEEP, BG_SURFACE, BG_ELEVATED, ACCENT_PRIMARY, TEXT_PRIMARY, TEXT_MUTED, HP, MP, XP }

const UI_COLORS := {
    UI.BG_DEEP:      Color(0.04, 0.04, 0.07),
    UI.BG_SURFACE:   Color(0.07, 0.07, 0.11),
    UI.BG_ELEVATED:  Color(0.10, 0.10, 0.16),
    UI.ACCENT_PRIMARY: Color(0.83, 0.53, 0.29),
    UI.TEXT_PRIMARY:  Color(0.91, 0.91, 0.93),
    UI.TEXT_MUTED:   Color(0.42, 0.42, 0.50),
    UI.HP:           Color(0.77, 0.25, 0.25),
    UI.MP:           Color(0.29, 0.42, 0.60),
    UI.XP:           Color(0.29, 0.55, 0.36),
}
```

### Button one-liner (post-helper migration)
```gdscript
ButtonStyleHelper.apply_style($MyButton, "primary")
# Style variants: "primary", "secondary", "danger", "success"
```

### Accessible focus setup for grid
```gdscript
# In inventory grid cell creation:
cell.focus_mode = Control.FOCUS_ALL
cell.focus_neighbor_left = cell_path_left
cell.focus_neighbor_right = cell_path_right
cell.focus_neighbor_top = cell_path_up
cell.focus_neighbor_bottom = cell_path_down
cell.focus_entered.connect(_on_cell_focused.bind(cell_index))
cell.focus_exited.connect(_on_cell_unfocused)
```
---

*Document generated from UI audit (42 `.tscn`, 173 `.gd`) + lore analysis + design system best practices.*
