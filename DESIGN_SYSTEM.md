# WUCO EXECUTIVE ACADEMY (WEA)
# MODULE 02 — EXACT VISUAL DESIGN SYSTEM & PREMIUM UI FOUNDATION

## CRITICAL INSTRUCTION

Read these files FIRST:

1. .github/copilot/00_MASTER_INSTRUCTIONS.md
2. .github/copilot/01_PROJECT_SETUP.md

This module RESTARTS the visual design implementation.

Do not assume the previous Module 02 design system is correct.

Inspect the current repository and refactor/rebuild the visual foundation so it follows the supplied WEA reference design.

The supplied reference image is the PRIMARY VISUAL REFERENCE.

The goal is NOT to create a generic black-and-gold website.

The goal is to reproduce the same visual character, proportions, spacing, typography, navigation treatment, grid background, gold accents, restrained colours and premium editorial appearance of the supplied reference.

The design must remain original to WUCO Executive Academy.

==================================================
1. BRAND
==================================================

Brand:

WUCO EXECUTIVE ACADEMY

Short name:

WEA

Tagline:

Empowering Africa's Leaders. Shaping Global Excellence.

Institutional backing:

World United Consumer Organisation

WEA must feel like:

- A prestigious executive education institution
- A serious professional certification institution
- A policy and leadership institution
- An international African institution
- A premium executive brand

It must NOT feel like:

- Udemy
- Coursera clone
- Generic LMS
- School management software
- Gaming website
- Cryptocurrency website
- Cheap black-and-gold template
- Overly flashy website

==================================================
2. PRIMARY VISUAL REFERENCE
==================================================

Use the supplied reference image as the visual benchmark.

The reference establishes:

- Header height
- Logo placement
- Navigation spacing
- Black background
- Thin borders
- Grid pattern
- Gold accent
- Serif headline
- Typography scale
- Hero width
- Content positioning
- Button treatment
- Bottom information strip
- Overall whitespace
- Minimalism
- Executive editorial style

DO NOT redesign these elements into a different style.

DO NOT add excessive cards, gradients, glowing effects or decorative elements.

WEA should be visually restrained.

Premium does NOT mean crowded.

==================================================
3. COLOUR SYSTEM
==================================================

Create centralized WEA colour tokens.

Primary:

Black:
#050505

Deep Black:
#080808

Surface:
#0B0B0B

Card:
#111111

Elevated:
#161616

Border:
#262626

Gold:
#C8A84D

Primary Gold:
#C8A84D

Bright Gold:
#DDBB55

Dark Gold:
#927225

White:
#FFFFFF

Off White:
#F2F2F2

Secondary Text:
#B8B8B8

Muted Text:
#777777

Do NOT introduce bright colours into the core branding.

Semantic colours may exist internally for system states:

Success
Warning
Error
Info

But they should not dominate the public visual identity.

==================================================
4. STRICT COLOUR BALANCE
==================================================

Follow approximately:

75–85% black/dark surfaces

10–15% white/grey typography

5–10% gold accents

Gold is an accent.

Gold must NOT dominate the interface.

Do not turn every border gold.

Do not make every heading gold.

Do not make every card gold.

Do not use gold backgrounds everywhere.

==================================================
5. TYPOGRAPHY
==================================================

Use:

Playfair Display

for major editorial headings.

Use:

Inter

for:

- Navigation
- Body
- Buttons
- Labels
- Forms
- Dashboard UI
- Metadata

The hero heading must visually resemble the reference.

Use large, elegant serif typography.

Avoid unnecessarily heavy or rounded fonts.

==================================================
6. HERO HEADLINE
==================================================

The primary homepage hero headline is:

Where Africa's
Leaders Are Formed

Desktop should visually resemble:

Where Africa's
Leaders Are Formed

The line break should be intentional.

Do not allow random wrapping.

On mobile, adapt intelligently while retaining the editorial character.

==================================================
7. HERO SUPPORTING TEXT
==================================================

Use:

Executive certificate programmes of the highest academic rigour,
backed by the institutional authority of the World United Consumer Organisation.

Use restrained grey/white typography.

The text must remain extremely readable.

==================================================
8. HERO ACCENT
==================================================

Above the hero headline:

A small thin horizontal gold line.

It should look like:

──────

Do not make it oversized.

Do not animate it aggressively.

==================================================
9. HERO BUTTON
==================================================

Primary CTA:

EXPLORE PROGRAMMES

Style:

Transparent/dark background.

Thin gold border.

Gold uppercase text.

Letter spacing.

On hover:

- Gold background
- Black text
- Slight elevation
- Smooth transition

No exaggerated animation.

==================================================
10. HERO IMAGE SYSTEM
==================================================

IMPORTANT:

The hero is NOT a permanently static image.

The hero must support exactly THREE hero images.

The three images must be uploaded and managed by the SUPER ADMIN.

The public homepage should retrieve the currently active three hero images from the backend.

Conceptually:

Hero Image 1
Hero Image 2
Hero Image 3

The Super Admin must eventually be able to:

- Upload image
- Replace image
- Delete image
- Reorder images
- Enable/disable image
- Preview image
- Set image duration
- Set overlay strength
- Save changes

Do NOT hard-code the three final images into the application.

The architecture must prepare for Super Admin management.

==================================================
11. HERO IMAGE SLIDER
==================================================

The three images should automatically rotate.

Example:

Image 1
↓
Image 2
↓
Image 3
↓
Image 1

Use a slow, elegant transition.

Preferred transition:

Crossfade / fade transition.

Avoid aggressive horizontal carousel movement.

The transition should feel like a premium institutional website.

Suggested duration:

6–8 seconds per image.

Transition:

800–1200ms.

Make these values configurable.

==================================================
12. HERO IMAGE POSITION
==================================================

The hero image must fill the hero background.

Use:

BoxFit.cover

Images must not distort.

The image should adapt across:

- Desktop
- Laptop
- Tablet
- Mobile

The image positioning must remain intelligent.

Allow future Super Admin configuration of focal position if practical.

==================================================
13. HERO COLOUR OVERLAY
==================================================

THIS IS CRITICAL.

The hero images must NEVER destroy the WEA black/gold visual identity.

Place a dark colour overlay above the image.

The overlay should combine:

Black

and a subtle WEA Gold tint where appropriate.

The objective is:

IMAGE
↓
DARK / BLACK-GOLD COLOUR OVERLAY
↓
TEXT
↓
CTA

The image should remain visible.

But the typography must always remain dominant and readable.

==================================================
14. HERO OVERLAY DESIGN
==================================================

Use a layered overlay rather than one flat opaque colour.

Suggested conceptual structure:

Layer 1:
Black opacity approximately 45–60%

Layer 2:
Directional black gradient

Layer 3:
Optional subtle gold tint at approximately 5–12%

Layer 4:
Bottom darkening gradient

The exact values may be adjusted visually.

Do NOT make the image disappear.

Do NOT make the gold overlay look orange.

The result should remain:

Black + Gold + Editorial Photography.

==================================================
15. TEXT SAFETY
==================================================

The hero text must remain readable regardless of which of the three images is active.

If an uploaded image is bright:

Automatically strengthen the overlay.

If practical, calculate or configure image overlay intensity.

At minimum provide:

Light Overlay
Medium Overlay
Strong Overlay

Default:

Medium/Strong.

The text must never sit directly on a bright part of an image without protection.

==================================================
16. HERO CONTENT POSITION
==================================================

Desktop:

Keep the hero content aligned similarly to the supplied reference.

Do NOT center everything just because it is a modern website.

The reference uses a strong editorial left-aligned composition.

Maintain:

- Large left margin
- Controlled maximum content width
- Large heading
- Supporting text beneath
- CTA beneath

==================================================
17. HERO HEIGHT
==================================================

Desktop:

Hero should occupy a substantial portion of the viewport.

Target approximately:

75–85vh

depending on navigation height.

Do not make it unnecessarily tall.

Mobile:

Use a sensible adaptive height.

Do not force 85vh if that makes the mobile hero unusable.

==================================================
18. HERO SLIDER INDICATOR
==================================================

Provide a very subtle indicator for the three images.

Example:

● ─ ○

or:

01 / 03

Keep it minimal.

It should use the WEA gold/grey system.

Do not create large carousel controls.

Optional:

Small previous/next controls may appear on desktop.

They must remain subtle.

==================================================
19. HERO ADMIN ARCHITECTURE
==================================================

Prepare a model such as:

HeroSlide

Fields conceptually:

id
imageUrl
title
subtitle
isActive
sortOrder
duration
overlayStrength
createdAt
updatedAt

Do not build the full Super Admin interface in Module 02.

However, structure the architecture so Module 07/08 can implement:

Super Admin → Website Management → Hero Slides

==================================================
20. NAVIGATION
==================================================

The navigation must follow the supplied reference very closely.

Desktop structure:

WEA LOGO

Home
Programmes
Faculty
About
Admissions
Research
Events
Professional Network

Login

APPLY

The exact number of links may be refined in Module 03.

But Home MUST be present.

Home is the first navigation item.

==================================================
21. NAVIGATION VISUAL STYLE
==================================================

Header:

Black / near-black.

Very thin bottom border.

No huge navigation bar.

Logo on the left.

Navigation on the right.

Small uppercase or refined compact navigation typography.

Active link:

Gold.

Hover:

Gold transition.

Do not use giant dropdown menus at this stage.

==================================================
22. APPLY BUTTON
==================================================

The APPLY button must resemble the reference.

Thin gold border.

Dark background.

Gold text.

Compact.

On hover:

Gold background.

Black text.

Subtle transition.

Do not use a giant pill button.

Avoid excessive border radius.

==================================================
23. HEADER RESPONSIVENESS
==================================================

Desktop:

Full navigation.

Tablet:

Reduce spacing intelligently.

Mobile:

Show:

WEA logo

Menu icon

Do not squeeze desktop navigation into mobile.

Create a premium mobile menu drawer.

==================================================
24. MOBILE MENU
==================================================

The mobile menu should contain:

Home
Programmes
Faculty
About
Admissions
Research
Events
Professional Network
Login
Apply

Use:

Black background.

Gold active state.

Smooth slide/fade animation.

No unnecessary visual clutter.

==================================================
25. BACKGROUND GRID
==================================================

The supplied reference has a subtle grid.

Reproduce this visual language.

Create:

WEAGridBackground

Use very thin low-opacity lines.

Horizontal + vertical grid.

The grid must be subtle.

Approximate effect:

Black background
+
barely visible dark grey grid.

Do NOT use bright lines.

Do NOT use gold grid lines.

==================================================
26. GRID RESPONSIVENESS
==================================================

The grid must adapt to screen size.

It must never become visually overwhelming on mobile.

Mobile may use a larger grid cell size or reduced opacity.

==================================================
27. BOTTOM INFORMATION STRIP
==================================================

Reproduce the reference's bottom strip.

Four items:

BACKED BY WUCO

RIGOROUS CURRICULUM

RESPECTED FACULTY

PAN-AFRICAN REACH

Use:

Black/dark surface.

Thin separators.

Small refined uppercase typography.

Gold/grey accents.

==================================================
28. BOTTOM STRIP RESPONSIVENESS
==================================================

Desktop:

Four horizontal columns.

Tablet:

Two columns × two rows.

Mobile:

Vertical or two-column layout depending on available width.

Do not allow text collisions.

==================================================
29. GLOBAL SPACING
==================================================

Use a refined spacing system.

Base:

4
8
12
16
24
32
40
48
64
80
96
120

The reference uses generous whitespace.

Do not cram sections together.

==================================================
30. GLOBAL MAX WIDTH
==================================================

Create a reusable:

WEAContainer

Content should have a maximum width.

Use generous side margins on desktop.

Do not stretch text from one edge of a 1920px monitor to the other.

==================================================
31. COMPONENT SYSTEM
==================================================

Create reusable components:

WEANavigation
WEAMobileNavigation
WEAContainer
WEAGridBackground
WEAHero
WEAHeroSlider
WEAHeroOverlay
WEAButton
WEAOutlinedButton
WEATextButton
WEASection
WEASectionHeading
WEACard
WEAImageCard
WEAStatStrip
WEABadge
WEAImage
WEAAvatar
WEASkeleton
WEAEmptyState
WEAErrorState
WEADialog
WEATextField
WEASearchField

Use these components throughout future modules.

==================================================
32. CARD DESIGN
==================================================

Cards should be restrained.

Use:

Dark surface.

Very subtle border.

Small/moderate radius.

Generous padding.

Avoid:

Huge rounded cards.

Bright gold backgrounds.

Excessive shadows.

==================================================
33. CARD HOVER
==================================================

Desktop:

On hover:

- Slight lift
- Border becomes subtly gold
- Optional image zoom
- Slight shadow

Transition:

200–350ms.

No bouncing.

No dramatic rotation.

No layout shift.

==================================================
34. IMAGE SYSTEM
==================================================

Create reusable image components.

Support:

- Local image
- Network image
- Loading
- Error
- Aspect ratio
- Overlay
- Rounded corners
- Hover zoom
- Fade-in

Images throughout future pages must be visually consistent.

==================================================
35. ANIMATION PHILOSOPHY
==================================================

Animations must communicate:

Elegance.

Not entertainment.

Use:

- Fade
- Slide
- Crossfade
- Scale
- Subtle hover
- Stagger

Avoid:

- Bounce
- Excessive rotation
- Flashing
- Large zoom
- Fast transitions

==================================================
36. REDUCED MOTION
==================================================

Respect accessibility preferences for reduced motion where practical.

If reduced motion is enabled:

- Reduce hero transitions
- Reduce scroll animations
- Remove unnecessary parallax
- Keep essential transitions short

==================================================
37. SCROLL REVEAL
==================================================

Create reusable scroll reveal utilities.

Future sections should be able to use:

Fade Up

Fade In

Slide In

Stagger

Do not make the entire page animate excessively.

==================================================
38. HOVER SYSTEM
==================================================

Create:

WEAHover

or equivalent reusable interaction utilities.

Support:

HoverLift
HoverBorder
HoverGlow
HoverScale
HoverImageZoom
HoverIconMove

Keep all effects subtle.

==================================================
39. BUTTON DESIGN
==================================================

Buttons must remain consistent with the reference.

Primary:

Gold outline or gold filled state depending on context.

Secondary:

Dark + gold outline.

Text button:

Minimal.

Do not use excessive pill-shaped buttons.

==================================================
40. FORM DESIGN
==================================================

Create:

WEATextField
WEAPasswordField
WEADropdown
WEATextArea
WEASearchField

Dark fields.

Subtle borders.

Gold focus.

White text.

Grey placeholder.

Error state clearly visible.

==================================================
41. DASHBOARD FOUNDATION
==================================================

Create only the reusable foundation for:

WEADashboardShell
WEASidebar
WEATopBar

Do not build the learner, lecturer or admin dashboards yet.

Future dashboards must still inherit the same WEA visual identity.

==================================================
42. DESIGN SHOWCASE
==================================================

Create development-only route:

/design-system

It must visually demonstrate:

1. WEA colours
2. Typography
3. Navigation
4. Buttons
5. Cards
6. Hero
7. Hero image slider
8. Hero overlays
9. Grid background
10. Statistics strip
11. Forms
12. Loading
13. Empty states
14. Error states
15. Hover effects
16. Animations
17. Responsive layouts

This showcase becomes the visual testing ground for WEA.

==================================================
43. HERO DESIGN SHOWCASE
==================================================

The design showcase MUST contain three sample hero images.

Use temporary images if the final Super Admin images are not yet available.

Demonstrate:

Image 1
→ crossfade
→ Image 2
→ crossfade
→ Image 3

Display:

- Overlay
- Heading
- Subtitle
- CTA
- Indicator

Demonstrate that text remains readable over every image.

==================================================
44. RESPONSIVENESS
==================================================

Test:

360px
390px
430px
768px
1024px
1280px
1440px
1920px

There must be:

NO

- Horizontal overflow
- Cropped headings
- Broken navigation
- Overlapping buttons
- Text collision
- Broken image aspect ratio
- Unreadable text
- Excessive spacing
- Tiny touch targets

==================================================
45. EXACT DESIGN PRINCIPLE
==================================================

When making a design decision, ask:

"Does this look like the supplied WEA reference?"

If NO:

Do not add it.

The visual system must be:

Minimal.

Editorial.

Premium.

Black.

Gold.

White.

Sophisticated.

==================================================
46. DO NOT OVERDESIGN
==================================================

STRICTLY AVOID:

- Excessive gradients
- Neon gold
- Gold everywhere
- Giant rounded cards
- Excessive glassmorphism
- Excessive shadows
- Floating blobs
- Random decorative circles
- Excessive icons
- Emoji as design elements
- Bright backgrounds
- Random colour accents
- Huge animations
- Generic SaaS dashboard appearance

==================================================
47. PERFORMANCE
==================================================

Hero images may be large.

Therefore:

- Optimize image loading.
- Use caching where appropriate.
- Avoid loading all huge-resolution images unnecessarily.
- Preload the next hero image where appropriate.
- Do not freeze the UI during image transitions.

The hero slider must remain smooth.

==================================================
48. ARCHITECTURE FOR FUTURE SUPER ADMIN
==================================================

Prepare interfaces/repositories for:

Hero slide management.

Future flow:

SUPER ADMIN
↓
Website Management
↓
Hero Slides
↓
Upload / Edit / Delete / Reorder
↓
Publish

Do not implement this management UI yet.

==================================================
49. QUALITY CHECK
==================================================

After implementation run:

flutter pub get

flutter analyze

flutter test

flutter run -d chrome

Fix all errors.

Fix all warnings introduced by this module.

==================================================
50. VISUAL QA
==================================================

Inspect the actual running website.

Do NOT rely only on code correctness.

Verify:

Header

Hero

Grid

Typography

Button

Hero images

Overlay

Image transitions

Bottom strip

Mobile navigation

Responsive behaviour

Hover behaviour

Text contrast

==================================================
51. FINAL REQUIREMENT
==================================================

This module is complete only when the running application visually establishes the WEA identity.

The first impression should be:

"An elite African executive education institution."

Not:

"Another LMS."

==================================================
52. DO NOT START MODULE 03
==================================================

Stop after Module 02.

Do NOT build:

- Full public website
- Programme catalogue
- About page
- Faculty page
- Admissions page
- Events page
- Research page
- Authentication
- Learner dashboard
- Lecturer dashboard
- Admin dashboard
- AI Mentor
- Professional Network

Those come later.

==================================================
53. FINAL COPILOT TASK
==================================================

Now implement Module 02.

Read:

.github/copilot/00_MASTER_INSTRUCTIONS.md

.github/copilot/01_PROJECT_SETUP.md

Then inspect the existing repository.

Rebuild/refactor the visual foundation as required.

The supplied reference image is the primary visual reference.

The design should closely reproduce its visual language.

The hero must additionally support three rotating images with dark black/gold overlays, while preserving the exact typography and visual hierarchy.

Actually create and modify the Flutter files.

Do not merely describe the implementation.

Run:

flutter pub get
flutter analyze
flutter test
flutter run -d chrome

Fix issues.

Test desktop, tablet and mobile.

Do NOT start Module 03.

Stop when Module 02 is complete.

Finally report:

- Files created
- Files modified
- Dependencies added
- Components created
- Hero slider architecture
- Overlay implementation
- Responsive testing
- Tests performed
- Remaining issues