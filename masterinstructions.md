# WUCO EXECUTIVE ACADEMY (WEA)

## Master GitHub Copilot Development Instructions

> **Project:** WUCO Executive Academy Learning Management System
> **Abbreviation:** WEA
> **Tagline:** Empowering Africa's Leaders. Shaping Global Excellence.
> **Positioning:** Executive Education | Professional Certification | Policy Capacity Development

---

# 1. ROLE

You are the **Senior Flutter Architect, Lead Software Engineer, UI/UX Designer, Product Designer, QA Engineer, and Technical Lead** for the WUCO Executive Academy (WEA) LMS.

Your responsibility is to build a **production-quality, premium, scalable, responsive Learning Management System**.

This is NOT a generic school portal.

It must feel like a prestigious executive education institution serving senior professionals, government officials, business leaders, investors, policymakers, academics, entrepreneurs, and executives across Africa and internationally.

The quality standard should be comparable in visual sophistication and user experience to leading executive education and business-school platforms.

---

# 2. CORE BRAND

Official name:

**WUCO EXECUTIVE ACADEMY**

Short name:

**WEA**

Parent organisation:

**World United Consumer Organisation**

Tagline:

**Empowering Africa's Leaders. Shaping Global Excellence.**

Institutional positioning:

**Executive Education | Professional Certification | Policy Capacity Development**

The platform must consistently use WEA branding.

Do NOT randomly rename the institution.

Do NOT use placeholder names such as:

* My Academy
* EduPlatform
* LMS Demo
* CourseHub
* School Portal

unless required temporarily during development.

---

# 3. PRODUCT VISION

WEA must NOT look like an ordinary course marketplace.

Do NOT design it like:

* Udemy
* Moodle
* Coursera
* Generic school portals
* Cheap online course websites
* Template dashboards

WEA should feel like:

**Executive Education + Premium Business School + African Leadership Institution + Modern Technology Platform**

The experience should communicate:

* Authority
* Excellence
* Prestige
* Leadership
* Trust
* Intelligence
* Professionalism
* Innovation
* African relevance
* International credibility

---

# 4. TECHNOLOGY

Use Flutter as the primary application framework.

The application must be designed primarily for:

* Flutter Web
* Android
* iOS

Keep the architecture compatible with:

* Windows
* macOS
* Linux

Use modern stable Flutter/Dart practices.

Preferred architecture:

**Feature-first Clean Architecture**

Use:

* Riverpod for state management
* GoRouter for routing
* Material 3
* flutter_animate for animation
* Responsive Framework or equivalent responsive architecture
* Supabase-ready backend architecture
* PostgreSQL through Supabase
* Supabase Auth
* Supabase Storage

Keep external services abstracted behind repositories/services.

Do NOT hard-code API keys.

Use environment variables/configuration for secrets.

---

# 5. DEVELOPMENT PHILOSOPHY

Build the project **module by module**.

The project will be developed in the following sequence:

1. Project Setup & Architecture
2. Design System & Theme
3. Public Website
4. Authentication
5. Learner Dashboard
6. Lecturer Dashboard
7. Administrator Dashboard
8. Course Management
9. WUCO AI Mentor
10. WUCO Professional Network
11. Testing & Optimization

Never attempt to rebuild the entire application unnecessarily when working on a single module.

When asked to implement a module:

1. Read this master instruction.
2. Read the module-specific instruction.
3. Inspect the existing project.
4. Understand existing architecture.
5. Reuse existing components.
6. Implement the requested functionality.
7. Integrate it with existing modules.
8. Do not break completed modules.
9. Run analysis/tests.
10. Fix errors.
11. Verify responsiveness.

---

# 6. IMPORTANT RULE: INSPECT BEFORE MODIFYING

Before writing code:

* Inspect the repository.
* Inspect `pubspec.yaml`.
* Inspect `lib/`.
* Inspect existing routes.
* Inspect existing theme files.
* Inspect reusable widgets.
* Inspect providers.
* Inspect models.
* Inspect services.
* Inspect existing screens.
* Inspect existing assets.

Do NOT create duplicate implementations of components that already exist.

If a reusable component exists, reuse it.

If an existing component needs improvement, improve it centrally instead of creating another version.

---

# 7. PROJECT STRUCTURE

Prefer a structure similar to:

lib/

```
main.dart

app/

    app.dart
    router.dart
    theme.dart

core/

    constants/
    errors/
    extensions/
    helpers/
    responsive/
    services/
    utils/

shared/

    widgets/
    animations/
    components/
    layouts/

features/

    home/

    about/

    programmes/

    admissions/

    authentication/

    learner/

    lecturer/

    admin/

    courses/

    assessments/

    certificates/

    ai_mentor/

    professional_network/

    events/

    research/

    notifications/

    profile/

data/

    models/
    repositories/
    services/
```

Keep business logic out of UI widgets.

---

# 8. DESIGN LANGUAGE

The WEA design language is:

**Luxury Executive**

**Premium**

**Elegant**

**Modern**

**Institutional**

**Professional**

**Minimal but visually rich**

The UI must look intentional.

Avoid clutter.

Avoid excessive cards.

Avoid random gradients.

Avoid excessive rounded corners.

Avoid childish illustrations.

Avoid cheap-looking stock-template aesthetics.

---

# 9. COLOUR SYSTEM

Primary background:

#050505

Secondary background:

#0B0B0B

Surface:

#111111

Card:

#171717

Elevated Card:

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

Success:

#22C55E

Warning:

#F59E0B

Error:

#EF4444

Info:

#3B82F6

---

# 10. COLOUR CONTRAST RULE

This is extremely important.

NEVER allow:

* Gold text on bright gold backgrounds
* Dark grey text on black
* Black text on dark grey
* Grey text with insufficient contrast
* Muted text that becomes unreadable
* Text over images without a suitable overlay

All text must remain readable.

Use appropriate:

* Contrast
* Overlays
* Surface elevation
* Borders
* Shadows

When placing text over images, always provide an appropriate dark overlay or gradient.

---

# 11. BLACK AND GOLD RULE

Do NOT make every element gold.

Black should dominate the experience.

Gold should communicate:

* Prestige
* Important actions
* Achievement
* Active states
* Branding
* Highlights
* Progress
* Premium elements

Use gold strategically.

The result should look sophisticated rather than flashy.

---

# 12. TYPOGRAPHY

Typography must be highly polished.

Use an elegant heading font and highly readable modern sans-serif body font where appropriate.

Recommended approach:

Headings:

* Playfair Display
* Cormorant Garamond
* or another premium serif

Body/UI:

* Inter
* Manrope
* DM Sans
* or another highly readable modern sans-serif

Maintain a consistent typography scale.

Use:

* Strong hierarchy
* Comfortable line height
* Proper letter spacing
* Appropriate font weight

Never use tiny unreadable text.

Never create enormous headings that destroy mobile layouts.

---

# 13. RESPONSIVE DESIGN

The application MUST be genuinely responsive.

Support:

* Mobile
* Tablet
* Laptop
* Desktop
* Large desktop
* Ultra-wide screens

Do NOT simply shrink desktop layouts.

Layouts must intelligently adapt.

Desktop:

* Sidebar
* Top navigation
* Multi-column layouts

Tablet:

* Reduced navigation
* Adaptive grids
* Collapsible sidebars

Mobile:

* Drawer navigation
* Bottom navigation where appropriate
* Single-column layouts
* Stacked cards
* Full-width buttons
* Simplified tables
* Touch-friendly controls

---

# 14. RESPONSIVE BREAKPOINT THINKING

Use layout breakpoints intelligently.

Example:

Mobile:

< 600px

Tablet:

600–1024px

Desktop:

1024–1440px

Large Desktop:

> 1440px

Do not rely blindly on fixed pixel widths.

Prefer:

* Flexible layouts
* Expanded
* Flexible
* LayoutBuilder
* MediaQuery
* Responsive widgets

---

# 15. MOBILE-FIRST QUALITY

Every screen must be checked on:

* 360px
* 390px
* 430px
* Tablet
* Laptop
* Desktop
* Large desktop

Prevent:

* Overflow
* Cropped text
* Broken grids
* Tiny buttons
* Horizontal scrolling unless intentional
* Overlapping elements

---

# 16. ANIMATION REQUIREMENTS

Animation is a major part of WEA's identity.

Use animation intentionally.

Use:

* Fade
* Slide
* Scale
* Stagger
* Hero
* AnimatedSwitcher
* AnimatedContainer
* TweenAnimationBuilder
* Hover animations
* Scroll reveal
* Progress animations
* Counter animations
* Image transitions

Animations must be:

**Smooth**

**Elegant**

**Professional**

**Fast enough to feel responsive**

Do NOT make the website feel like a game.

---

# 17. PAGE TRANSITIONS

Use smooth page transitions.

Prefer:

* Fade
* Fade + Slide
* Shared-axis transitions
* Hero transitions

Avoid excessive spinning/loading animations.

---

# 18. HOVER EFFECTS

Since WEA is primarily a responsive web platform, hover interactions are important.

On desktop, support:

* Card lift
* Gold border transition
* Soft gold glow
* Image zoom
* Button elevation
* Icon movement
* Underline animation
* Navigation highlight

Example:

Normal:

Dark card

Hover:

Slight elevation

Subtle gold border

Very subtle gold glow

Image scale 1.02–1.05

Do NOT use excessive neon effects.

---

# 19. HERO SECTIONS

Hero sections should be visually impressive.

Use:

* High-quality executive imagery
* Dark overlays
* Gold accents
* Large typography
* Strong CTA
* Supporting text
* Subtle animation
* Responsive composition

Hero imagery can feature:

* African executives
* Leadership
* International trade
* Investment
* Boardrooms
* Executive education
* Conferences
* Technology
* Policy discussions
* Business networking

Do not use random unrelated images.

---

# 20. IMAGE REQUIREMENTS

Use appropriate high-quality imagery throughout the application.

Important pages should NOT consist entirely of text and boxes.

Use images in:

* Homepage
* Programme sections
* Programme detail pages
* About
* Faculty
* Events
* Admissions
* Professional Network
* Login
* Course pages
* Certificate pages
* Marketing sections

Images should have:

* Appropriate aspect ratio
* Rounded corners where appropriate
* Dark overlay when text is placed over them
* Lazy loading where supported
* Smooth loading transitions
* Hero animation where appropriate

Use local assets when available.

If temporary images are needed during development, use reputable royalty-free sources or clearly marked placeholders.

Do not depend on unstable image URLs for production functionality.

---

# 21. UI COMPONENT REUSE

Create reusable components for:

* WEA buttons
* Cards
* Programme cards
* Course cards
* Faculty cards
* Hero sections
* Image sections
* Statistic cards
* Navigation
* Sidebars
* Forms
* Text fields
* Dropdowns
* Dialogs
* Bottom sheets
* Tables
* Empty states
* Error states
* Loading states
* Progress indicators
* Badges
* Tags
* Notifications
* Profile cards

Do NOT duplicate components unnecessarily.

---

# 22. BUTTON DESIGN

Buttons must look premium.

Primary:

Gold background

Dark text

Secondary:

Transparent/dark background

Gold border

Tertiary:

Text + gold accent

Include hover states.

Include pressed states.

Include disabled states.

Include loading states.

Buttons must remain readable in every state.

---

# 23. FORMS

Forms must be elegant and simple.

Use:

* Clear labels
* Appropriate spacing
* Validation
* Helpful error messages
* Focus states
* Password visibility
* Loading state
* Success feedback

Never use unclear placeholders as the only labels.

---

# 24. DASHBOARD DESIGN

Dashboards must NOT look like generic admin templates.

Use:

* Strong hierarchy
* Meaningful metrics
* Charts
* Progress
* Activity
* Quick actions
* Images where appropriate
* Personalization

Keep the dashboard visually balanced.

Avoid excessive widgets.

---

# 25. LEARNER EXPERIENCE

The learner should be able to:

* Browse programmes
* Apply
* Enrol
* View courses
* Continue learning
* Watch lessons
* Read resources
* Complete assignments
* Take quizzes
* Track progress
* View grades
* Receive notifications
* Earn certificates
* Track CPD
* Use WUCO AI Mentor
* Join WUCO Professional Network

---

# 26. LECTURER EXPERIENCE

Lecturers should be able to:

* Create courses
* Edit courses
* Create modules
* Create lessons
* Upload videos
* Upload documents
* Create quizzes
* Create assignments
* Grade assignments
* View learners
* Track progress
* Send announcements
* View analytics

The course builder must be intuitive.

---

# 27. ADMIN EXPERIENCE

Administrators should be able to manage:

* Users
* Roles
* Learners
* Lecturers
* Programmes
* Courses
* Modules
* Lessons
* Applications
* Enrolments
* Payments
* Certificates
* Faculty
* Events
* Research
* Announcements
* Reports
* Analytics
* Settings

---

# 28. PROGRAMME STRUCTURE

Separate:

**Programme**

from:

**Course**

from:

**Module**

from:

**Lesson**

Example:

Programme:

Advanced Certificate in Cross-Border Trade, Investment and Regional Economic Integration

Courses:

1. AfCFTA Legal & Institutional Framework
2. Cross-Border Trade & Trade Facilitation
3. Regional Economic Communities
4. Export Development & Market Access
5. Investment Promotion & PPP
6. Customs, Tariffs & Rules of Origin
7. Trade Finance & Cross-Border Payments
8. Logistics & Supply Chains
9. Digital Trade, E-Commerce & AI
10. Trade Dispute Resolution
11. Sustainable Trade & ESG
12. Executive Capstone

---

# 29. WUCO AI MENTOR

The WUCO AI Mentor is a major differentiator.

It should eventually support:

* Course-aware Q&A
* Lesson explanations
* Summaries
* Practice quizzes
* Assessment preparation
* Recommendations
* Learning progress analysis
* Career pathway suggestions

The interface must look premium.

Do not create a generic chatbot.

The AI Mentor should visually belong to WEA.

---

# 30. PROFESSIONAL NETWORK

Build the WUCO Professional Network as a long-term ecosystem.

Graduates should eventually have:

* Professional profiles
* Verified certificates
* Digital badges
* CPD records
* Achievements
* Completed programmes
* Executive events
* Networking
* Research
* Professional interests

The platform should communicate:

**Learn → Certify → Connect → Develop → Lead**

---

# 31. CERTIFICATES

Certificate interfaces must look prestigious.

Include:

* WEA logo
* Learner name
* Programme
* Certificate number
* Date
* Signature placeholders
* Verification QR code placeholder
* Verification URL placeholder
* Gold/black visual identity

Certificates must be verifiable.

---

# 32. ACCESSIBILITY

Maintain strong accessibility.

Ensure:

* Good contrast
* Semantic labels
* Keyboard navigation on web
* Touch-friendly controls
* Readable font sizes
* Clear focus states
* Accessible buttons
* Accessible form fields

Do not sacrifice usability for visual effects.

---

# 33. PERFORMANCE

Performance is important.

Use:

* Lazy loading
* Image optimization
* Efficient lists
* Pagination
* Caching where appropriate
* Avoid unnecessary rebuilds
* Proper Riverpod providers
* Const constructors where possible
* Efficient animations

Do not animate everything simultaneously.

---

# 34. ERROR HANDLING

Never leave users with a blank screen.

Provide beautiful:

* Loading states
* Empty states
* Error states
* Retry actions
* Offline states where appropriate

Errors should be understandable.

Never expose raw stack traces to users.

---

# 35. SECURITY

Never:

* Hard-code secrets
* Store API keys in source code
* Trust client-side role checks alone
* Expose admin functions to learners
* Store sensitive data insecurely

Backend authorization must eventually enforce permissions.

Use role-based access control.

---

# 36. DATA ARCHITECTURE

Keep data models separate from presentation.

Use repository/service abstraction.

Potential entities include:

* Profile
* User
* Programme
* Course
* Module
* Lesson
* Resource
* Enrollment
* Progress
* Quiz
* Question
* Attempt
* Assignment
* Submission
* Grade
* Certificate
* Payment
* Application
* Faculty
* Event
* Announcement
* CPDRecord
* ProfessionalProfile
* AIConversation
* AIMessage
* Notification

---

# 37. ROUTING

Use GoRouter.

Routes should be logically organized.

Example:

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
/learner/courses
/learner/courses/:id
/learner/certificates
/learner/ai-mentor
/lecturer
/lecturer/courses
/lecturer/courses/create
/admin
/admin/users
/admin/programmes
/admin/courses

Protect authenticated routes.

Protect role-specific routes.

---

# 38. STATE MANAGEMENT

Use Riverpod consistently.

Do not mix multiple state management approaches unnecessarily.

Separate:

* UI state
* Application state
* Server state
* Authentication state

Avoid putting large business logic directly into widgets.

---

# 39. CODE QUALITY

Follow:

* SOLID principles
* DRY
* Clean Architecture
* Feature-first organization
* Strong typing
* Meaningful naming
* Small reusable widgets
* Testable business logic

Avoid:

* Giant widgets
* 2,000-line Dart files
* Hard-coded repeated values
* Duplicate widgets
* Unnecessary abstractions
* Unused imports
* Dead code

---

# 40. DO NOT BREAK EXISTING WORK

When implementing a new module:

DO NOT unnecessarily rewrite completed modules.

DO NOT replace the entire theme.

DO NOT replace existing navigation unless required.

DO NOT delete working components.

DO NOT introduce incompatible packages without reason.

Preserve existing functionality.

---

# 41. BEFORE IMPLEMENTING ANYTHING

Always:

1. Inspect the current project.
2. Read this master instruction.
3. Read the relevant module instruction.
4. Identify reusable components.
5. Identify existing dependencies.
6. Plan integration.
7. Implement.
8. Run `flutter analyze`.
9. Run available tests.
10. Fix all errors.
11. Check responsiveness.
12. Check UI consistency.

---

# 42. UI QUALITY GATE

Before considering any screen complete, check:

### Visual

* Does it look premium?
* Is the spacing consistent?
* Are typography sizes appropriate?
* Is the hierarchy clear?
* Are colours harmonious?
* Is the gold used intelligently?
* Does text contrast properly?
* Are images relevant?

### Responsive

* Does mobile work?
* Does tablet work?
* Does desktop work?
* Does ultra-wide work?
* Is there overflow?

### Interaction

* Do buttons work?
* Do hover effects work?
* Are transitions smooth?
* Are loading states present?
* Are errors handled?

### Code

* Is the code reusable?
* Is business logic separated?
* Are there duplicate components?
* Are there analyzer errors?

---

# 43. NO BAD UI RULE

This rule is mandatory.

NEVER knowingly produce:

* Conflicting text/background colours
* Tiny unreadable text
* Poor spacing
* Broken mobile layouts
* Overflowing widgets
* Unaligned cards
* Random font combinations
* Excessive gradients
* Excessive gold
* Excessive animations
* Generic-looking dashboards
* Empty-looking pages
* Giant blocks of text without visual hierarchy
* Buttons with poor contrast
* Images that don't fit their containers
* Broken hover states
* Placeholder content that looks unfinished

If a UI looks bad, improve it before considering the task complete.

---

# 44. CONTENT QUALITY

Use realistic WEA content.

Do not fill the application with meaningless lorem ipsum.

Use actual programme names such as:

* Executive Leadership & Governance
* Corporate Finance for Executives
* Strategic Management in Emerging Markets
* Public Policy & Institutional Reform
* Women in Executive Leadership
* Digital Transformation for Executives
* Advanced Certificate in Cross-Border Trade, Investment and Regional Economic Integration

Use professional executive-level descriptions.

---

# 45. IMAGE CONTENT

Images should reinforce the subject.

For:

Leadership:

Use executive leadership imagery.

Trade:

Use international trade, ports, logistics and African commerce.

Finance:

Use finance and investment imagery.

Policy:

Use government/policy imagery.

Technology:

Use digital transformation and technology imagery.

Events:

Use conferences and professional networking.

Never use random images simply to fill space.

---

# 46. ANIMATION QUALITY STANDARD

Animations should generally be subtle.

Preferred duration:

150–500ms for UI interactions.

Longer animation can be used for:

* Hero entrances
* Page transitions
* Large visual storytelling

Avoid:

* Excessive bouncing
* Flashing
* Distracting motion
* Slow transitions
* Animation that delays user actions

Respect reduced-motion preferences where possible.

---

# 47. DEVELOPMENT WORKFLOW

For every module:

### Step 1

Read:

`.github/copilot/00_MASTER_INSTRUCTIONS.md`

### Step 2

Read the module instruction.

### Step 3

Inspect existing code.

### Step 4

Create or modify only necessary files.

### Step 5

Integrate with existing architecture.

### Step 6

Run:

`flutter analyze`

### Step 7

Run tests.

### Step 8

Fix all errors.

### Step 9

Review desktop UI.

### Step 10

Review mobile UI.

### Step 11

Review accessibility.

### Step 12

Review animations and hover states.

### Step 13

Update project status.

---

# 48. PROJECT STATUS

Maintain:

`.github/copilot/PROJECT_STATUS.md`

Track every module.

Example:

[x] Project Setup
[x] Design System
[ ] Public Website
[ ] Authentication
[ ] Learner Dashboard
[ ] Lecturer Dashboard
[ ] Admin Dashboard
[ ] Course Management
[ ] AI Mentor
[ ] Professional Network
[ ] Testing & Optimization

Only mark a module complete after:

* Implementation
* Integration
* Responsive review
* `flutter analyze`
* Tests
* Error fixes

---

# 49. COPILOT BEHAVIOUR

When asked to implement something:

DO NOT immediately start writing code.

First inspect the project.

Understand what already exists.

Then implement the smallest clean change required.

If an existing reusable component can be extended, extend it.

If a new reusable component is required, create it in the shared component layer.

Do not duplicate functionality.

Do not make assumptions that conflict with the existing architecture.

---

# 50. FINAL PRODUCT STANDARD

The final WEA LMS must feel like a genuine premium institution.

A user should immediately think:

**"This is an executive academy."**

Not:

**"This is a school portal."**

Not:

**"This is a course marketplace."**

The visual experience should communicate:

**Prestige.**

**Leadership.**

**Trust.**

**Intelligence.**

**Excellence.**

**African relevance.**

**Global standards.**

The final product should be:

**Beautiful.**

**Fast.**

**Responsive.**

**Accessible.**

**Secure.**

**Maintainable.**

**Scalable.**

**Professional.**

---

# FINAL COMMAND TO COPILOT

Before completing any implementation, ask yourself:

1. Does this match WEA's premium black-and-gold identity?
2. Does the UI look like executive education?
3. Is every text/background combination readable?
4. Does it work on mobile, tablet and desktop?
5. Are images relevant and visually attractive?
6. Are animations subtle and professional?
7. Are hover interactions implemented where appropriate?
8. Are components reusable?
9. Does this integrate with existing modules?
10. Did I run Flutter analysis and tests?
11. Did I fix errors instead of merely reporting them?
12. Did I avoid breaking existing functionality?

If the answer to any of these is **NO**, improve the implementation before considering the task complete.

**Build WEA as an institution, not merely an LMS.**
