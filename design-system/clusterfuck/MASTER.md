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

| Role | Hex | CSS Variable |
|------|-----|--------------|
| Primary / σ_irr | `#8B5CF6` | `--color-primary` |
| On Primary | `#FFFFFF` | `--color-on-primary` |
| Secondary / env | `#00A2FF` | `--color-secondary` |
| Accent/CTA | `#45E0A8` | `--color-accent` |
| Background (dark HUD) | `#08091A` | `--color-background` |
| Light paper | `#F8FAFC` | `--color-background-light` |
| Foreground | `#E4E3F5` | `--color-foreground` |
| Muted | `#8D8CB0` | `--color-muted` |
| Border | `#334155` | `--color-border` |
| Destructive | `#F5232B` | `--color-destructive` |
| Warning | `#FF2F92` | `--color-warning` |
| Ring | `#8B5CF6` | `--color-ring` |

**Color Notes:** Same FlexAIDΔS family as NATURaL / Shannon. Not Exergy gold remaining rings. Generated aerospace `#0284C7` / `#16A34A` / `#F0F9FF` is unused.

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
  background: #45E0A8;
  color: white;
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
  color: #8B5CF6;
  border: 2px solid #8B5CF6;
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
  background: #08091A;
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
  border: 1px solid #E2E8F0;
  border-radius: 8px;
  font-size: 16px;
  transition: border-color 200ms ease;
}

.input:focus {
  border-color: #8B5CF6;
  outline: none;
  box-shadow: 0 0 0 3px #8B5CF620;
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
- ❌ **Low contrast text** — Maintain 4.5:1 minimum contrast ratio
- ❌ **Instant state changes** — Always use transitions (150-300ms)
- ❌ **Invisible focus states** — Focus states must be visible for a11y

---

## Brand override (NATURaL Remote / Crooks HUD)

The generated aerospace/clinical palette (`#0284C7` / `#16A34A` / `#F0F9FF`) is **not** used. ClusterFuck is NATURaL’s wrist/Mac remote — same FlexAIDΔS family as Shannon and NATURaL, **not** Exergy gold gauges.

Shipping tokens (`ClusterFuckTheme`):

| Role | Hex | Quantity |
|------|-----|----------|
| Ink / dark HUD | `#08091A` | Surface |
| Light paper | `#F8FAFC` | Light appearance |
| Closure CTA | `#45E0A8` mint | ΔH |
| σ_irr ring | `#8B5CF6` violet | ΔS |
| Environment | `#00A2FF` aqua | ΔS_vib |
| Elevated | `#FF2F92` strawberry | Receptor / warn |
| Fail | `#F5232B` firetruck | T |

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
