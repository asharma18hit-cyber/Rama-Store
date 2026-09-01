---
name: Rama Elite
colors:
  surface: '#f8f9fa'
  surface-dim: '#d9dadb'
  surface-bright: '#f8f9fa'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f4f5'
  surface-container: '#edeeef'
  surface-container-high: '#e7e8e9'
  surface-container-highest: '#e1e3e4'
  on-surface: '#191c1d'
  on-surface-variant: '#464555'
  inverse-surface: '#2e3132'
  inverse-on-surface: '#f0f1f2'
  outline: '#777587'
  outline-variant: '#c7c4d8'
  surface-tint: '#4d44e3'
  primary: '#3525cd'
  on-primary: '#ffffff'
  primary-container: '#4f46e5'
  on-primary-container: '#dad7ff'
  inverse-primary: '#c3c0ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#41485e'
  on-tertiary: '#ffffff'
  tertiary-container: '#586076'
  on-tertiary-container: '#d4dbf5'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2dfff'
  primary-fixed-dim: '#c3c0ff'
  on-primary-fixed: '#0f0069'
  on-primary-fixed-variant: '#3323cc'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#dae2fd'
  tertiary-fixed-dim: '#bec6e0'
  on-tertiary-fixed: '#131b2e'
  on-tertiary-fixed-variant: '#3f465c'
  background: '#f8f9fa'
  on-background: '#191c1d'
  surface-variant: '#e1e3e4'
typography:
  display-lg:
    fontFamily: Geist
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Geist
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Geist
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: '0'
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: '0'
  label-md:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1'
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1'
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  3xl: 64px
  container-max: 1280px
  gutter: 24px
---

## Brand & Style

The design system embodies an **Elite, High-Performance** persona, repositioning the brand as a premium destination for discerning customers. The aesthetic is a sophisticated blend of **Minimalism** and **Glassmorphism**, emphasizing clarity through expansive whitespace and technical precision.

The visual narrative is "Industrial Luxury":
- **Precision:** Tight micro-borders and strict grid alignment reflect reliability.
- **Depth:** Soft ambient shadows and frosted glass layers create a sense of physical space without clutter.
- **Energy:** High-octane indigo accents drive action against a serene, high-contrast light canvas.
- **Trust:** Solid charcoal typography provides a grounded, authoritative voice.

The interface should feel exceptionally fast, responsive, and tactile, using subtle motion and transparency to guide the user through a frictionless shopping experience.

## Colors

The palette is anchored by **Deep Electric Indigo**, used strategically for primary actions and brand presence. **Vivid Emerald** serves exclusively as a success and "High-Intent" CTA color (e.g., Buy Now, Checkout) to create a psychological "go" signal.

- **Surface Strategy:** Use absolute White (`#FFFFFF`) for primary card surfaces and interactive elements. Off-white (`#F9FAFB`) is reserved for the global background and section containers to create a subtle "layered" effect.
- **Typography:** Deep Charcoal (`#0F172A`) is used for all primary text to ensure maximum legibility and a premium feel.
- **Borders:** Use sleek, low-contrast Grey (`#E5E7EB`) for micro-borders. These should be 1px wide to define structure without adding visual weight.
- **Glassmorphism:** Navigation and persistent overlays use a white base with 80% opacity and a 12px background blur to maintain context while isolating the interaction.

## Typography

This design system utilizes a dual-font strategy to balance technical precision with extreme readability.

- **Geist (Headlines & Labels):** Chosen for its monolinear, developer-grade precision. It gives the brand a "High-Performance" edge. Use heavier weights (700+) for headlines to create a strong visual hierarchy.
- **Inter (Body):** Used for all long-form text and product descriptions. Its neutral, systematic nature ensures that product information is conveyed clearly without stylistic distraction.

**Hierarchy Rules:**
- Use **Display-LG** for hero section titles only.
- **Label-MD** and **Label-SM** should always be used for metadata (categories, stock status, SKU numbers) and are typically set in uppercase with slight tracking to enhance the premium feel.

## Layout & Spacing

The design system adheres to a **strict 8px baseline grid**. All margins, paddings, and component heights must be multiples of 8 (with 4px reserved for micro-adjustments in tight UI like labels or icons).

**Grid Model:**
- **Desktop:** 12-column fluid grid with 24px gutters and 48px side margins. Max-width capped at 1280px for optimal readability.
- **Tablet:** 8-column grid with 20px gutters and 24px side margins.
- **Mobile:** 4-column grid with 16px gutters and 16px side margins.

**Vertical Rhythm:**
- Sections should be separated by `2xl` (48px) or `3xl` (64px) spacing to maintain the premium, airy aesthetic. 
- Grouped elements within a card (e.g., Title and Price) should use `xs` (4px) or `sm` (8px) spacing.

## Elevation & Depth

Hierarchy is established through **Ambient Shadows** and **Tonal Layering**. The goal is a "natural light" feel where elements appear to float slightly above the off-white canvas.

- **Surface Level (0):** The `#F9FAFB` background.
- **Level 1 (Low):** Product cards and containers. Use a very soft, diffused shadow: `0 4px 12px rgba(15, 23, 42, 0.03)`. Add a 1px micro-border in `#E5E7EB`.
- **Level 2 (Hover):** On hover, cards lift. Increase shadow to `0 12px 24px rgba(15, 23, 42, 0.08)` and apply a subtle `-4px` Y-axis translation.
- **Level 3 (Overlay):** Sticky headers and navigation. Use a **Glassmorphism** effect with `backdrop-filter: blur(12px)` and a semi-transparent white background (`rgba(255, 255, 255, 0.8)`). 
- **Modals/Drawers:** Use a high-depth shadow `0 24px 48px rgba(0, 0, 0, 0.1)` and a `bg-black/20` backdrop blur to dim the underlying content.

## Shapes

The shape language is **Rounded**, providing a modern, approachable feel that softens the high-contrast technical typography.

- **Standard (Base):** 8px (`0.5rem`) for inputs, small buttons, and tags.
- **Large (LG):** 16px (`1rem`) for product cards, banners, and modals.
- **Extra Large (XL):** 24px (`1.5rem`) for large feature hero sections or promotional tiles.
- **Pill:** Use full rounding (9999px) for search bars and small status badges (e.g., "New Arrival").

## Components

### Buttons
- **Primary:** Solid `#4F46E5` fill with white text. 16px horizontal padding. Smooth scale down (0.98) on click.
- **Success/CTA:** Solid `#10B981` fill. Reserved for final conversion points (Checkout, Confirm).
- **Secondary:** White background with `#E5E7EB` border. Deep Charcoal text.

### Interactive Product Cards
- Cards must have a 1px border.
- **Hover State:** Image should subtly scale (1.05x) within its clipped container.
- **Shadow:** Transition from Level 1 to Level 2 elevation on hover.

### Inputs & Forms
- **Text Fields:** `#FFFFFF` background with a subtle `#E5E7EB` border. On focus, the border transitions to Primary Indigo with a 2px soft outer glow.
- **Search Bar:** Pill-shaped, featuring a glassmorphic blur when inside the sticky header.

### Navigation & Drawers
- **Sticky Header:** Glassmorphic container with a bottom micro-border.
- **Slide-over Drawers:** Use for Cart and Mobile Menus. Content should slide in from the right with a `cubic-bezier(0.16, 1, 0.3, 1)` transition for a "high-performance" feel.

### Chips & Badges
- Used for categories or status. Small Geist typography, semi-bold. Backgrounds should be very low-opacity tints of the status color (e.g., Success green at 10% opacity).