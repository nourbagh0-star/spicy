---
name: Epicurean Harmony
colors:
  surface: '#fff8f3'
  surface-dim: '#e0d9d2'
  surface-bright: '#fff8f3'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#faf2ec'
  surface-container: '#f4ece6'
  surface-container-high: '#efe7e0'
  surface-container-highest: '#e9e1db'
  on-surface: '#1e1b17'
  on-surface-variant: '#59413c'
  inverse-surface: '#33302c'
  inverse-on-surface: '#f7efe9'
  outline: '#8d716b'
  outline-variant: '#e0bfb8'
  surface-tint: '#ad321c'
  primary: '#aa301a'
  on-primary: '#ffffff'
  primary-container: '#cb4830'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb4a5'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e4e2e1'
  on-secondary-container: '#656464'
  tertiary: '#5c5c58'
  on-tertiary: '#ffffff'
  tertiary-container: '#757571'
  on-tertiary-container: '#fefcf7'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad3'
  primary-fixed-dim: '#ffb4a5'
  on-primary-fixed: '#3e0400'
  on-primary-fixed-variant: '#8b1906'
  secondary-fixed: '#e4e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474747'
  tertiary-fixed: '#e4e2dd'
  tertiary-fixed-dim: '#c8c6c2'
  on-tertiary-fixed: '#1b1c19'
  on-tertiary-fixed-variant: '#474744'
  background: '#fff8f3'
  on-background: '#1e1b17'
  surface-variant: '#e9e1db'
typography:
  display-lg:
    fontFamily: Playfair Display
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Playfair Display
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Playfair Display
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Playfair Display
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
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
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 120px
---

## Brand & Style

The design system is centered on a "Sophisticated Warmth" narrative, tailored for a premium restaurant e-commerce experience. The objective is to create an interface that recedes into the background, allowing high-resolution food photography to become the primary interface element. 

The aesthetic blends **Modern Minimalism** with **Tactile Refinement**. It leverages generous whitespace (macro-spacing) to evoke a sense of luxury and calm, while using soft, organic depth to make UI elements feel touchable and approachable. The emotional response should be one of "effortless indulgence"—where ordering a high-end meal feels as curated as the dining experience itself.

## Colors

This design system utilizes a palette designed to stimulate appetite and signify premium quality:

- **Primary (Terracotta):** Used for primary actions, price points, and active states. It provides a warm, savory energy that complements grilled and cooked food tones.
- **Secondary (Charcoal):** Used for primary text and grounding elements. It provides deep contrast against the lighter background.
- **Tertiary (Warm Cream):** The primary surface color. Unlike pure white, this cream tone feels more organic and high-end, reducing eye strain and making food photography appear more vibrant.
- **Neutral (Earth Grey):** Used for secondary text, borders, and disabled states.

Avoid using pure blacks or vibrant blues, as they can suppress appetite or clash with the organic nature of food imagery.

## Typography

The typographic hierarchy relies on the tension between the editorial elegance of **Playfair Display** and the functional clarity of **Inter**. 

Headlines should use Playfair Display to signal the "Chef's voice"—use it for dish names, category titles, and brand messaging. For all functional UI, price displays, and descriptions longer than two lines, use Inter to ensure legibility during the ordering process. Tighten letter-spacing on larger display types to maintain a cohesive, "locked-in" look.

## Layout & Spacing

The design system employs a **Fluid-Fixed Hybrid** model. On mobile, it uses a 4-column grid with 20px margins. On desktop, it transitions to a 12-column grid with a max-width of 1280px to prevent food imagery from becoming overbearingly large.

Spacing is governed by an 8px linear scale. Use "lg" (40px) and "xl" (64px) values liberally between sections to emphasize the minimalist, upscale feel. Vertical rhythm is critical; ensure that text descriptions are vertically centered relative to their corresponding imagery when viewed in list formats.

## Elevation & Depth

Depth is communicated through **Ambient Shadows** and **Tonal Layering**. Avoid harsh, black shadows.

1.  **Level 0 (Base):** The Warm Cream surface (#F9F7F2).
2.  **Level 1 (Cards):** Subsurface elements using a thin, 1px border of #6B6661 at 10% opacity.
3.  **Level 2 (Floating):** Used for active food cards and "Add to Cart" modals. These use a diffused shadow: `0px 10px 30px rgba(44, 44, 44, 0.05)`.
4.  **Level 3 (Sticky):** Navigation bars and checkout summaries. These use a light backdrop-blur (10px) with 90% opacity of the Tertiary color to maintain context of the content scrolling beneath.

## Shapes

The shape language is consistently **Rounded**, reflecting the organic nature of food and ingredients. 

- Standard components (inputs, small buttons) use `rounded` (0.5rem).
- Large containers, food item cards, and imagery use `rounded-lg` (1rem).
- Interactive pill elements like "Vegetarian" or "Spicy" chips use `rounded-xl` (1.5rem).

All image containers must have a radius; never use sharp corners for food photography as it feels too clinical and less "appetizing."

## Components

- **Primary Buttons:** High-contrast Terracotta background with White text. Rounded (0.5rem). Minimum height of 48px for touch targets.
- **Product Cards:** Cream background with a Level 2 shadow on hover. Imagery should bleed to the top and sides, with text content padded by "md" (24px) spacing at the bottom.
- **Quantity Selector:** A pill-shaped (rounded-xl) component with a subtle border. Use Haptic feedback for increment/decrement actions.
- **Price Labels:** Set in Inter Bold. When associated with a CTA, the price should be integrated into the button or placed immediately adjacent in a secondary charcoal color.
- **Filtering Chips:** Outlined in the neutral color when inactive; filled with charcoal when active to provide immediate visual feedback without competing with the primary terracotta CTA.
- **Checkout Bar:** A sticky bottom element with a subtle Level 3 elevation, ensuring the path to purchase is always accessible.