# WEA LMS — MODULE 01

# PROJECT SETUP, ARCHITECTURE & FOUNDATION

## READ FIRST

Before doing anything, read:

`.github/copilot/00_MASTER_INSTRUCTIONS.md`

The master instruction is mandatory.

Do not violate the WEA branding, architecture, responsiveness, animation, accessibility, UI quality, or coding standards defined there.

---

# 1. OBJECTIVE

Build the foundational Flutter application for:

# WUCO EXECUTIVE ACADEMY

**WEA**

**Empowering Africa's Leaders. Shaping Global Excellence.**

This module is ONLY for establishing the project's technical foundation.

Do NOT build the complete public website yet.

Do NOT build learner, lecturer, or administrator dashboards yet.

Do NOT build the AI Mentor yet.

Do NOT build the Professional Network yet.

Those will be implemented in later modules.

The purpose of this module is to create a clean, scalable foundation on which all future modules will be built.

---

# 2. FIRST ACTION — INSPECT THE PROJECT

Before modifying anything:

1. Inspect the entire repository.
2. Check whether a Flutter project already exists.
3. Inspect `pubspec.yaml`.
4. Inspect `lib/`.
5. Inspect existing assets.
6. Inspect existing routes.
7. Inspect existing theme files.
8. Inspect existing widgets.
9. Inspect existing configuration.
10. Identify anything that can be reused.

If the project is empty, initialize the Flutter project correctly.

If the project already contains code, do NOT destroy existing work.

Preserve useful existing work where possible.

---

# 3. FLUTTER TARGET

The application should support:

* Flutter Web
* Android
* iOS

Keep the architecture compatible with:

* Windows
* macOS
* Linux

Primary development priority:

**Flutter Web**

The web experience must be excellent on:

* Mobile browsers
* Tablets
* Laptops
* Desktop browsers
* Large screens

---

# 4. ARCHITECTURE

Implement a scalable feature-first architecture.

Use:

**Clean Architecture principles**

Organize the project approximately as:

```text
lib/
│
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── app_theme.dart
│       ├── app_colors.dart
│       ├── app_typography.dart
│       └── app_dimensions.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── helpers/
│   ├── responsive/
│   ├── services/
│   └── utils/
│
├── shared/
│   ├── animations/
│   ├── components/
│   ├── layouts/
│   └── widgets/
│
├── features/
│   ├── home/
│   ├── about/
│   ├── programmes/
│   ├── admissions/
│   ├── authentication/
│   ├── learner/
│   ├── lecturer/
│   ├── admin/
│   ├── courses/
│   ├── assessments/
│   ├── certificates/
│   ├── ai_mentor/
│   ├── professional_network/
│   ├── events/
│   ├── research/
│   ├── notifications/
│   └── profile/
│
└── data/
    ├── models/
    ├── repositories/
    └── services/
```

Do not create every feature implementation yet.

Create the foundational folders only where appropriate.

---

# 5. DEPENDENCIES

Use current stable packages compatible with the installed Flutter/Dart version.

Prefer:

### State Management

`flutter_riverpod`

### Routing

`go_router`

### Animation

`flutter_animate`

### Responsive Layout

Use a reliable responsive solution such as:

`responsive_framework`

or an equivalent modern approach if the current Flutter ecosystem makes another approach preferable.

### Fonts

Use:

`google_fonts`

### Icons

Use high-quality iconography.

Prefer:

`lucide_icons`

or another polished icon package if compatible.

### Backend Readiness

Prepare architecture for:

`supabase_flutter`

Do not require live Supabase credentials during this module.

### Utility

Use appropriate packages only when genuinely required.

Do NOT install unnecessary dependencies.

---

# 6. PUBSPEC CONFIGURATION

Configure:

* App name
* Description
* Assets
* Fonts if needed
* Required dependencies
* Development dependencies

Use proper dependency versions compatible with the current Flutter SDK.

Do not blindly copy outdated package versions.

---

# 7. APPLICATION ENTRY POINT

Create a clean:

`lib/main.dart`

Responsibilities should be minimal.

It should:

1. Initialize Flutter.
2. Initialize required services.
3. Start the application.

Do not place business logic in `main.dart`.

---

# 8. APP ROOT

Create:

`lib/app/app.dart`

This should contain the root application configuration.

Use:

`MaterialApp.router`

Connect:

* Theme
* Router
* Localization-ready architecture
* Responsive configuration

Prepare the application for future authentication and role-based navigation.

---

# 9. ROUTING FOUNDATION

Create:

`lib/app/router.dart`

Use GoRouter.

Initially create routes for:

```text
/
 /about
 /programmes
 /programmes/:id
 /admissions
 /faculty
 /events
 /research
 /contact
 /login
 /register

/learner
/lecturer
/admin
```

At this stage, routes can point to temporary foundation screens.

Do not build their complete interfaces yet.

Prepare route architecture for future:

* Authentication guards
* Role-based access
* Redirects
* Deep linking
* 404 handling

---

# 10. 404 PAGE

Create a polished WEA 404 page.

It should have:

**404**

**Page Not Found**

A short professional message.

Button:

**Return Home**

The design must use the WEA black/gold identity.

It must be responsive.

Add a subtle animation.

---

# 11. DESIGN TOKEN FOUNDATION

Create centralized design tokens.

Do NOT scatter colors throughout the application.

Create:

`app_colors.dart`

Use:

```text
Background:
#050505

Secondary Background:
#0B0B0B

Surface:
#111111

Card:
#171717

Elevated:
#1D1D1D

Primary Gold:
#C8A84D

Bright Gold:
#E5C55C

Deep Gold:
#9A7625

Primary Text:
#FFFFFF

Secondary Text:
#D7D7D7

Muted Text:
#9A9A9A

Border:
#2A2A2A
```

Also define semantic colors for:

* Success
* Warning
* Error
* Information

---

# 12. TYPOGRAPHY FOUNDATION

Create:

`app_typography.dart`

Establish a consistent typography hierarchy.

Prepare styles for:

* Display
* Hero
* H1
* H2
* H3
* H4
* Body
* Body Small
* Caption
* Button
* Label
* Navigation

Use Google Fonts where appropriate.

Recommended combination:

Heading:

**Playfair Display**

Body:

**Inter**

Keep typography responsive.

Do not hard-code massive font sizes that break mobile.

---

# 13. THEME

Create:

`app_theme.dart`

Create the WEA dark theme using Material 3.

The theme should include:

* Color scheme
* Typography
* Buttons
* Cards
* Input fields
* Dialogs
* Navigation
* Chips
* Progress indicators
* Dividers
* Tooltips

The theme should be centralized.

Avoid defining the same style repeatedly inside screens.

---

# 14. RESPONSIVE FOUNDATION

Create reusable responsive utilities.

The system should recognize:

```text
Mobile
Tablet
Desktop
Large Desktop
```

Create reusable utilities/widgets such as:

```text
ResponsiveBuilder
ResponsiveContainer
ResponsiveGrid
```

or an equivalent architecture.

The purpose is to prevent developers from writing random MediaQuery conditions throughout the application.

---

# 15. RESPONSIVE CONTAINER

Create a reusable maximum-width content container.

Large desktop pages should not stretch content from edge to edge.

Use appropriate max-widths.

Example conceptual behaviour:

```text
Mobile:
full width + safe horizontal padding

Tablet:
constrained content

Desktop:
large centered content area

Ultra-wide:
maximum content width
```

---

# 16. ANIMATION FOUNDATION

Create:

`lib/shared/animations/`

Prepare reusable animation utilities for future modules.

Examples:

```text
FadeIn
SlideIn
ScaleIn
StaggeredList
HoverScale
HoverLift
AnimatedGoldBorder
```

Use `flutter_animate` where appropriate.

Animations must be:

* Smooth
* Subtle
* Premium
* Fast
* Professional

Do not over-animate the foundation.

---

# 17. HOVER FOUNDATION

Because WEA is primarily a web platform, create reusable hover functionality.

Prepare support for:

* Hover scale
* Hover lift
* Gold border
* Gold glow
* Image zoom
* Button hover

Hover effects should not affect layout dimensions unexpectedly.

Do not cause content to jump when hovering.

---

# 18. IMAGE FOUNDATION

Create:

```text
assets/
├── images/
│   ├── hero/
│   ├── programmes/
│   ├── faculty/
│   ├── events/
│   ├── leadership/
│   ├── trade/
│   ├── finance/
│   ├── technology/
│   └── general/
│
├── icons/
│
└── fonts/
```

Prepare reusable image components.

Examples:

```text
WEAImage
WEAHeroImage
WEAImageCard
```

Support:

* Rounded corners
* Aspect ratio
* Fit modes
* Overlay
* Loading state
* Error state
* Fade-in
* Responsive sizing

Do not use random image URLs everywhere in the codebase.

---

# 19. BRAND COMPONENT

Create a reusable WEA brand/logo component.

It should support:

* Full logo
* Compact logo
* WEA text mark
* Light/dark context

For now, use an appropriate placeholder if the actual logo asset has not yet been supplied.

Do NOT permanently embed a fake logo.

Make it easy to replace later.

---

# 20. BASIC SHARED COMPONENTS

Create the foundation for reusable components:

```text
WEAButton
WEAOutlinedButton
WEATextButton
WEACard
WEASection
WEAContainer
WEABadge
WEAChip
WEAStatCard
WEAImage
WEAAvatar
WEALoading
WEAEmptyState
WEAErrorState
```

Do not overbuild these components.

They should be reusable and customizable.

---

# 21. BASIC APP SHELL

Create a basic responsive shell.

Desktop:

```text
WEA Logo

Navigation

Content
```

Mobile:

```text
WEA Logo       Menu
```

Do NOT build the complete public navigation yet.

Only create the foundation required for future modules.

---

# 22. INITIAL HOME SCREEN

Create a VERY SIMPLE placeholder home screen only to verify the architecture.

It should show:

**WUCO EXECUTIVE ACADEMY**

**WEA**

**Empowering Africa's Leaders. Shaping Global Excellence.**

Button:

**Explore Programmes**

This is NOT the final homepage.

Do not spend significant time designing the homepage yet.

The full premium homepage will be built in:

`03_PUBLIC_WEBSITE.md`

---

# 23. THE INITIAL HOME SCREEN MUST STILL BE BEAUTIFUL

Even though it is temporary, it must:

* Use the WEA theme
* Be responsive
* Have good spacing
* Have correct text contrast
* Use a subtle animation
* Have a professional layout

Do not create an ugly developer placeholder.

---

# 24. ENVIRONMENT CONFIGURATION

Prepare the project for:

```text
Development
Staging
Production
```

Do not put:

* API keys
* Supabase keys
* OpenAI keys
* Payment secrets

directly into Dart source files.

Create an appropriate configuration approach.

---

# 25. SUPABASE PREPARATION

Prepare the architecture for Supabase.

Do NOT build the complete backend yet.

Create appropriate abstraction such as:

```text
SupabaseService
```

or equivalent.

The rest of the application should eventually communicate through repositories/services rather than directly accessing Supabase from UI widgets.

---

# 26. ERROR HANDLING

Create a foundation for:

* App errors
* Network errors
* Authentication errors
* Validation errors
* Unknown errors

Create a consistent error model.

Do not expose technical stack traces to users.

---

# 27. CODE QUALITY

Use:

* Const constructors
* Strong typing
* Immutable models where appropriate
* Small widgets
* Reusable components
* Clear naming
* Proper folder organization

Avoid:

* Giant files
* Giant widgets
* Duplicate code
* Magic numbers
* Hard-coded colors
* Hard-coded typography
* Hard-coded spacing everywhere

---

# 28. TESTING FOUNDATION

Create initial tests for:

* App startup
* Theme
* Routing
* Responsive utilities
* Basic reusable components

Tests do not need to cover future features yet.

---

# 29. ANALYSIS

After implementation, run:

```bash
flutter pub get
flutter analyze
flutter test
```

If web is enabled, also test:

```bash
flutter run -d chrome
```

Fix all errors.

Do not simply report errors.

---

# 30. RESPONSIVE TEST

Check the foundation at:

```text
360px
390px
430px
768px
1024px
1280px
1440px
1920px
```

Look specifically for:

* Overflow
* Cropped text
* Incorrect padding
* Broken navigation
* Unreadable text
* Incorrect card sizes
* Alignment problems

Fix anything discovered.

---

# 31. VISUAL QUALITY CHECK

Before finishing this module, verify:

### Background

No text disappears into the black background.

### Gold

Gold is used as an accent, not everywhere.

### Typography

Text is readable and elegant.

### Spacing

There is sufficient breathing room.

### Responsive

Mobile is not simply a compressed desktop layout.

### Animation

Animations are smooth and subtle.

### Architecture

Future modules can be added without restructuring the entire application.

---

# 32. DO NOT IMPLEMENT YET

Do NOT implement:

* Full homepage
* Programme catalogue
* Programme detail pages
* Login functionality
* Registration functionality
* Learner dashboard
* Lecturer dashboard
* Admin dashboard
* Course builder
* AI Mentor
* Professional Network
* Payment system
* Certificate engine
* Full Supabase database
* Full analytics

These belong to later modules.

---

# 33. COMPLETION REQUIREMENTS

This module is complete only when:

* Flutter project runs
* Dependencies are installed
* Architecture exists
* Theme exists
* Black/gold design tokens exist
* Typography exists
* Responsive foundation exists
* Animation foundation exists
* Hover foundation exists
* Routing exists
* Basic app shell exists
* Basic home screen exists
* 404 screen exists
* Asset structure exists
* Supabase architecture is prepared
* No analyzer errors exist
* Tests pass
* Web runs correctly
* Mobile layout works
* No overflow exists

---

# 34. FINAL COPILOT INSTRUCTION

Now perform Module 01.

IMPORTANT:

Do not just explain what should be done.

Actually create and modify the required files.

Inspect the existing project first.

Do not overwrite useful existing work.

Use the architecture and standards defined in:

`.github/copilot/00_MASTER_INSTRUCTIONS.md`

After implementation:

1. Run `flutter pub get`.
2. Run `flutter analyze`.
3. Run `flutter test`.
4. Run the web application if possible.
5. Fix all errors and warnings that you introduced.
6. Verify responsive behaviour.
7. Verify the black/gold theme.
8. Verify text contrast.
9. Verify routing.
10. Verify the application starts successfully.

At the end, provide a concise summary containing:

* Files created
* Files modified
* Dependencies added
* Architecture implemented
* Tests performed
* Any remaining issues

Do NOT start Module 02 or any later module automatically.

Stop after Module 01 is complete.
