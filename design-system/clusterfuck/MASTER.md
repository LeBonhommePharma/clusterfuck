# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** ClusterFuck
**Generated:** 2026-09-17 01:38:10
**Category:** Space Tech / Aerospace
**Design Dials:** Variance 3/10 (Centered / Minimal) | Motion 3/10 (Subtle) | Density 8/10 (Dense / Dashboard)

---

## Global Rules

### Color Palette

| Role | Hex (dark ground) | Hex (light ground) | CSS Variable |
|------|-----|-----|--------------|
| Primary / ΔS · σ_irr | `#8B5CF6` | `#7E4AF5` | `--violet` |
| On Primary | `#08091A` | `#08091A` | `--bg` |
| Secondary / ΔS_vib · env | `#00A2FF` | `#0074B7` | `--aqua` |
| Accent / ΔH · CTA | `#45E0A8` | `#157F59` | `--mint` |
| Stats / ΔG | `#FF9300` | `#A45F00` | `--tangerine` |
| Baseline / apo | `#DCDCE4` | `#6C6C8D` | `--magnesium` |
| Background | `#08091A` | `#F4F6FB` | `--bg` |
| Card | `rgba(17,18,38,.82)` | `#FFFFFF` | `--bg-card` |
| Foreground | `#E4E3F5` | `#1E293B` | `--fg` |
| Muted | `#8D8CB0` | `#5A6478` | `--fg-muted` |
| Border | `violet @ 35%` | `violet @ 25%` | `--violet-35` / `--violet-25` |
| Destructive / T | `#F5232B` | `#BE123C` | `--firetruck` |
| Fail text (small) | `#FF6B6B` | `#BE123C` | `--state-fail-text` |
| Warning / receptor | `#FF2F92` | `#DB0068` | `--strawberry` |
| Ring | `#8B5CF6` | `#7E4AF5` | `--violet` |

**Color Notes:** FlexAID∆S **palette v2** (`tokens.css`), same family as NATURaL / Shannon. Not Exergy gold remaining rings. Generated aerospace `#0284C7` / `#16A34A` / `#F0F9FF` is unused.

Each key colour is bound to a thermodynamic quantity and is never reassigned. **Retired — do not reintroduce:** `--teal`, `--gold`, `--terra`, `--cyan`, `--coral`, `--green`, any yellow, cyan `#22D3EE`, salmon `#C2456F`, gold `#FBBF24`, steel `#6E7C99`, snow `#FFFFFF` as a key colour.

The light-ground column keeps each key colour's **hue and chroma exactly** and moves only lightness. Hue and chroma carry the identity; lightness is free. The variants exist because v2 is tuned for the indigo ink and collapses on a light ground — mint is 1.68:1 on white. Every light value clears 4.5:1 on `#F4F6FB`.

### Typography

- **Heading Font:** SF Pro (Orbitron maps here; do not ship Google Fonts in the apps)
- **Body Font:** SF Pro
- **Metrics:** SF Mono
- **Mood:** dense Crooks control HUD, mint closure, violet σ_irr

### Spacing Variables

*Density: 8/10 — Dense / Dashboard*

| Token | Value | Usage |
|-------|-------|-------|
| `--space-xs` | `2px` / `0.125rem` | Tight gaps |
| `--space-sm` | `4px` / `0.25rem` | Icon gaps, inline spacing |
| `--space-md` | `8px` / `0.5rem` | Standard padding |
| `--space-lg` | `12px` / `0.75rem` | Section padding |
| `--space-xl` | `16px` / `1rem` | Large gaps |
| `--space-2xl` | `24px` / `1.5rem` | Section margins |
| `--space-3xl` | `32px` / `2rem` | Hero padding |

### Shadow Depths

| Level | Value | Usage |
|-------|-------|-------|
| `--shadow-sm` | `0 1px 2px rgba(0,0,0,0.05)` | Subtle lift |
| `--shadow-md` | `0 4px 6px rgba(0,0,0,0.1)` | Cards, buttons |
| `--shadow-lg` | `0 10px 15px rgba(0,0,0,0.1)` | Modals, dropdowns |
| `--shadow-xl` | `0 20px 25px rgba(0,0,0,0.15)` | Hero images, featured cards |

---

## Component Specs

### Buttons

```css
/* Primary Button */
.btn-primary {
  background: var(--mint);
  color: var(--bg);       /* ink on mint = 11.73:1. Never white on mint (1.66:1). */
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 600;
  transition: all 200ms ease;
  cursor: pointer;
}

.btn-primary:hover {
  opacity: 0.9;
  transform: translateY(-1px);
}

/* Secondary Button */
.btn-secondary {
  background: transparent;
  color: var(--violet);          /* on the ink. On a light ground use #7E4AF5. */
  border: 2px solid var(--violet);
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 600;
  transition: all 200ms ease;
  cursor: pointer;
}
```

### Cards

```css
.card {
  background: var(--bg-card);
  border-radius: 12px;
  padding: 24px;
  box-shadow: var(--shadow-md);
  transition: all 200ms ease;
  cursor: pointer;
}

.card:hover {
  box-shadow: var(--shadow-lg);
  transform: translateY(-2px);
}
```

### Inputs

```css
.input {
  padding: 12px 16px;
  border: 1px solid var(--violet-25);   /* violet wash, never a neutral slate rule */
  border-radius: 8px;
  font-size: 16px;
  transition: border-color 200ms ease;
}

.input:focus {
  border-color: var(--violet);
  outline: none;
  box-shadow: 0 0 0 3px var(--violet-20);
}
```

### Modals

```css
.modal-overlay {
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
}

.modal {
  background: white;
  border-radius: 16px;
  padding: 32px;
  box-shadow: var(--shadow-xl);
  max-width: 500px;
  width: 90%;
}
```

---

## Style Guidelines

**Style:** Exaggerated Minimalism

**Keywords:** Bold minimalism, oversized typography, high contrast, negative space, loud minimal, statement design

**Best For:** Fashion, architecture, portfolios, agency landing pages, luxury brands, editorial

**Key Effects:** font-size: clamp(3rem 10vw 12rem), font-weight: 900, letter-spacing: -0.05em, massive whitespace

### Page Pattern

**Pattern Name:** Immersive + Feature-Rich

- **CTA Placement:** Above fold
- **Section Order:** Hero > Features > CTA

---

## Motion

**Scroll Reveal** (Subtle) — Trigger: scroll (viewport enter) | Duration: 300-400ms | Easing: `power1.out`

```js
gsap.from(el, { opacity: 0, y: 12, duration: 0.35, ease: 'power1.out', scrollTrigger: { trigger: el, start: 'top 90%', toggleActions: 'play none none reverse' } });
```

**Framework notes:** Requires the ScrollTrigger plugin registered once via gsap.registerPlugin(ScrollTrigger)

- ✅ Keep the y offset small (8-16px) so it reads as a fade, not a slide
- ❌ Don't reveal below-the-fold content needed for SEO/crawlers as invisible-by-default without a no-JS fallback
- ⚡ toggleActions 'play none none reverse' avoids re-triggering on every scroll direction change

---

## Anti-Patterns (Do NOT Use)

- ❌ Generic design
- ❌ No immersion

### Additional Forbidden Patterns

- ❌ **Emojis as icons** — Use SVG icons (Heroicons, Lucide, Simple Icons)
- ❌ **Missing cursor:pointer** — All clickable elements must have cursor:pointer
- ❌ **Layout-shifting hovers** — Avoid scale transforms that shift layout
- ❌ **Low contrast text** — 4.5:1 body, 3:1 at ≥24px or ≥18.66px bold, 3:1 non-text. Contrast is a (foreground, background) pair — check against the ground the colour actually lands on, not against the ink by default.
- ❌ **Dark-ground key colours on a light ground** — Use the light-ground column
- ❌ **Instant state changes** — Always use transitions (150-300ms)
- ❌ **Invisible focus states** — Focus states must be visible for a11y

---

## Brand override (NATURaL Remote / Crooks HUD)

The generated aerospace/clinical palette (`#0284C7` / `#16A34A` / `#F0F9FF`) is **not** used. ClusterFuck is NATURaL’s wrist/Mac remote — same FlexAIDΔS family as Shannon and NATURaL, **not** Exergy gold gauges.

Shipping tokens (`ClusterFuckTheme`):

| Role | Dark | Light | Quantity |
|------|------|-------|----------|
| Ink / dark HUD | `#08091A` | `#F4F6FB` | Surface |
| Card | `#111226` @92% | `#FFFFFF` | Surface |
| Closure CTA | `#45E0A8` mint | `#157F59` | ΔH |
| σ_irr ring | `#8B5CF6` violet | `#7E4AF5` | ΔS |
| Environment | `#00A2FF` aqua | `#0074B7` | ΔS_vib |
| Stats | `#FF9300` tangerine | `#A45F00` | ΔG |
| Baseline | `#DCDCE4` magnesium | `#6C6C8D` | apo / reference |
| Elevated | `#FF2F92` strawberry | `#DB0068` | Receptor / warn |
| Fail | `#F5232B` firetruck | `#BE123C` | T |
| Fail text (small) | `#FF6B6B` | `#BE123C` | `--state-fail-text` |

Firetruck is held to 12px and up; smaller failure labels use the fail-text lift.
Borders are violet alpha washes (35% dark / 25% light), never a neutral slate rule.

Orbitron/JetBrains map to **SF Pro / SF Mono**. Density 8 stays for the control HUD. Distinguish from NATURaL yoga (no pose catalog) and Exergy (no remaining-quota gold). Hits ≥44pt. Reduce Motion pauses ring trim. Unknown σ_irr renders `—`, never `0`.

---

## Pre-Delivery Checklist

Before delivering any UI code, verify:

- [ ] No emojis used as icons (SF Symbols only)
- [ ] Hits ≥44pt; 8pt gaps
- [ ] `accessibilityReduceMotion` respected
- [ ] Light and dark text contrast 4.5:1
- [ ] Color is never the only meaning (σ_irr number + band copy)
- [ ] Bottom nav ≤5 with labels
- [ ] Safe areas respected
