# WUCO EXECUTIVE ACADEMY (WEA)
# MODULE 05 — LEARNER DASHBOARD & EXECUTIVE LEARNING EXPERIENCE

============================================================
READ FIRST — MANDATORY
============================================================

Before doing anything, read:

1. MASTERINSTRUCTIONS.md
2. PROJECT_SETUP.md
3. DESIGN_SYSTEM.md
4. PUBLIC_WEBSITE.md
5. AUTHENTICATION.md

DO NOT skip these files.

This is MODULE 05.

The objective is to build the complete authenticated LEARNER EXPERIENCE for WUCO Executive Academy.

The learner dashboard must feel like a premium executive education platform.

It must NOT look like:

- A generic school portal
- A basic Moodle clone
- A cheap course marketplace
- A generic SaaS dashboard
- A cluttered admin panel

It should feel:

PREMIUM
EXECUTIVE
INSTITUTIONAL
MODERN
INTELLIGENT
INTERNATIONAL
PAN-AFRICAN
ACADEMIC
PROFESSIONAL

============================================================
1. BRAND IDENTITY — CRITICAL
============================================================

The supplied WUCO Executive Academy logo is the authoritative brand reference.

The current brand direction is:

WHITE
WUCO BLUE
DEEP NAVY
LIGHT BLUE
SOFT GREY

DO NOT use the old black/gold theme.

DO NOT introduce gold.

DO NOT make black the dominant background.

Use the WUCO logo appropriately.

Do not distort, stretch, rotate or arbitrarily recolour the logo.

============================================================
2. PURPOSE OF THE LEARNER DASHBOARD
============================================================

The dashboard is the private learning environment for WEA learners.

A learner should be able to:

- View enrolled programmes
- View enrolled courses
- Continue learning
- View course progress
- Access lessons
- Watch course videos
- Read course materials
- Complete assessments
- View grades/results
- Track programme progress
- View upcoming learning activities
- View certificates
- View digital credentials
- Track CPD
- Receive notifications
- Manage profile
- Manage account settings
- Access WEA AI Mentor when Module 09 is implemented
- Access Professional Network when Module 10 is implemented

============================================================
3. ROUTE
============================================================

Primary route:

/learner

Additional routes:

/learner/dashboard

/learner/programmes

/learner/programmes/:programmeId

/learner/courses

/learner/courses/:courseId

/learner/courses/:courseId/learn

/learner/courses/:courseId/lessons/:lessonId

/learner/assessments

/learner/results

/learner/certificates

/learner/credentials

/learner/cpd

/learner/notifications

/learner/profile

/learner/settings

Prepare the routing architecture cleanly.

============================================================
4. ACCESS CONTROL
============================================================

Only authenticated users with:

UserRole.learner

may access the learner dashboard.

Unauthenticated users:

redirect to /login.

Users with other roles must not access learner-only pages unless the existing authorization architecture explicitly permits it.

Do not rely only on hiding navigation items.

Enforce access through route guards and authorization logic.

============================================================
5. DASHBOARD STRUCTURE
============================================================

Desktop layout:

------------------------------------------------------------
| WEA Logo | Search | Notifications | Profile             |
------------------------------------------------------------
| Sidebar  |                                           |
|          | Welcome back, [Learner]                    |
|          |                                            |
|          | Continue Learning                           |
|          |                                            |
|          | My Programmes                               |
|          |                                            |
|          | Progress                                    |
|          |                                            |
|          | Upcoming                                    |
|          |                                            |
------------------------------------------------------------

The dashboard must use a modern responsive sidebar.

============================================================
6. SIDEBAR
============================================================

Create a reusable learner sidebar.

Brand area:

WUCO EXECUTIVE ACADEMY

Navigation:

Dashboard

My Programmes

My Courses

Assessments

Results

Certificates

Credentials

CPD

Notifications

Professional Network

AI Mentor

Profile

Settings

Logout

Use icons with labels.

On desktop:

Persistent sidebar.

On tablet:

Collapsible sidebar.

On mobile:

Drawer navigation.

============================================================
7. SIDEBAR ACTIVE STATE
============================================================

Active navigation item:

Use WUCO blue.

Possible treatment:

Light blue background

Blue icon

Deep navy text

Subtle left accent indicator

Do not use excessively bright colours.

============================================================
8. HEADER
============================================================

Dashboard header should contain:

WEA logo/mark

Search

Notifications

Profile avatar

Profile name

Role:

Learner

Responsive menu button on smaller screens.

============================================================
9. SEARCH
============================================================

Create a global learner search interface.

Search should eventually support:

Courses

Programmes

Lessons

Resources

Certificates

Faculty

Events

For Module 05, implement the interface and architecture.

Search results can initially use local/mock data if backend functionality is not yet available.

Do not hard-code search logic into UI widgets.

Create a reusable search service/repository abstraction.

============================================================
10. WELCOME SECTION
============================================================

Dashboard hero:

Good morning, [First Name].

Continue your journey with WUCO Executive Academy.

Display a subtle supporting statement.

Example:

"Your next breakthrough may begin with the next lesson."

Do not use generic motivational clichés excessively.

============================================================
11. LEARNER SUMMARY
============================================================

Display compact executive metrics:

Active Programmes

Courses Completed

Learning Hours

Certificates Earned

CPD Points

Use premium statistic cards.

Example:

03

Active Programmes

Do not overcrowd the dashboard.

============================================================
12. CONTINUE LEARNING
============================================================

This is one of the most important sections.

Show the learner's most recently accessed course.

Card should display:

Programme

Course title

Course image

Course category

Lecturer/faculty

Progress percentage

Progress bar

Current lesson

Last accessed

Button:

CONTINUE LEARNING

Example:

Corporate Finance for Executives

68% complete

Continue:

Module 7 — Capital Structure & Valuation

============================================================
13. COURSE PROGRESS
============================================================

Progress should be represented clearly.

Use:

Percentage

Progress bar

Completed lessons

Total lessons

Estimated remaining time

Example:

68%

17 of 25 lessons completed

Approximately 4h 20m remaining

Avoid giant decorative progress indicators that waste screen space.

============================================================
14. MY PROGRAMMES
============================================================

Create:

/learner/programmes

Display all programmes the learner is enrolled in.

Each programme card should show:

Programme title

Programme category

Programme image

Duration

Delivery mode

Start date

Expected completion date

Progress

Status

Continue button

============================================================
15. PROGRAMME STATUS
============================================================

Support:

Not Started

In Progress

Completed

Awaiting Assessment

Certificate Available

Expired

Suspended

Use semantic visual indicators.

Do not rely only on colour.

============================================================
16. PROGRAMME DETAIL
============================================================

Create:

/learner/programmes/:programmeId

Display:

Programme title

Programme description

Programme image

Programme category

Duration

Delivery mode

Faculty

Programme start date

Programme end date

Overall progress

Course list

Assessments

Certificate status

CPD information

============================================================
17. PROGRAMME COURSE LIST
============================================================

Show the courses within a programme.

Each course row/card:

Course number

Course title

Short description

Lecturer

Duration

Progress

Status

Action

Example:

01
Executive Leadership & Governance

8 Modules

72%

CONTINUE

============================================================
18. MY COURSES
============================================================

Create:

/learner/courses

Allow filtering by:

All

In Progress

Not Started

Completed

Assessment Pending

Certificate Eligible

Search courses.

============================================================
19. COURSE CARD
============================================================

Course cards should include:

Course image

Course category

Course title

Programme

Faculty

Duration

Progress

Status

Continue button

Hover effect on desktop.

Hover effect must be subtle and premium.

Example:

Slight elevation

Slight image zoom

Soft shadow

Border transition

Do not create exaggerated animations.

============================================================
20. COURSE DETAIL
============================================================

Create:

/learner/courses/:courseId

Display:

Course title

Course image

Description

Lecturer

Programme

Duration

Learning objectives

Course progress

Modules

Resources

Assessment status

Certificate relevance

CPD points

Primary action:

CONTINUE COURSE

============================================================
21. LEARNING EXPERIENCE
============================================================

Create:

/learner/courses/:courseId/learn

This is the main learning interface.

Desktop:

------------------------------------------------------------
| Course modules | Main lesson content                     |
------------------------------------------------------------

Left:

Course curriculum.

Right:

Lesson content.

============================================================
22. COURSE CURRICULUM
============================================================

Display modules and lessons.

Example:

MODULE 01
Introduction to Executive Leadership

✓ Lesson 1
✓ Lesson 2
✓ Lesson 3

MODULE 02
Strategic Decision Making

✓ Lesson 4
▶ Lesson 5
🔒 Lesson 6

Use appropriate icons.

Completed lessons should be clearly identifiable.

Current lesson should be highlighted.

Locked lessons should appear disabled.

============================================================
23. LESSON TYPES
============================================================

Architecture should support:

Video

Text

PDF

Presentation

Audio

External resource

Quiz

Assignment

Case study

Live session

The learner UI must be prepared for future content types.

============================================================
24. VIDEO LESSON
============================================================

Create a professional video lesson player area.

Support:

Play

Pause

Seek

Volume

Fullscreen

Progress

Playback speed where supported

Video completion tracking should be supported by the architecture.

Do not automatically mark a lesson complete simply because it was opened.

============================================================
25. LESSON COMPLETION
============================================================

Provide:

MARK AS COMPLETE

or automatically mark complete only when the lesson completion criteria are satisfied.

Once completed:

Update course progress.

Update programme progress.

Update learner statistics.

Unlock subsequent content if configured.

============================================================
26. LESSON CONTENT
============================================================

Below the lesson content display:

Lesson title

Description

Learning objectives

Resources

Notes

Discussion placeholder

Previous lesson

Next lesson

Do not build full discussion functionality yet.

Prepare the UI for future implementation.

============================================================
27. NEXT LESSON
============================================================

At the bottom of every lesson:

PREVIOUS

NEXT LESSON

The next button should respect lesson unlocking rules.

If unavailable:

show a clear explanation.

============================================================
28. LEARNER NOTES
============================================================

Prepare support for personal notes.

Learner should eventually be able to:

Add note

Edit note

Delete note

View notes

For Module 05, create the UI and repository abstraction.

============================================================
29. BOOKMARKS
============================================================

Prepare support for:

Bookmark lesson

Remove bookmark

View bookmarked lessons

Implement if architecture permits without compromising the module scope.

============================================================
30. ASSESSMENTS
============================================================

Create:

/learner/assessments

Display:

Upcoming assessments

Available assessments

Completed assessments

Pending assessments

Assessment history

============================================================
31. ASSESSMENT CARD
============================================================

Show:

Assessment title

Course

Programme

Type

Due date

Duration

Attempts remaining

Status

Action

Examples:

Quiz

Final Examination

Case Study

Executive Assignment

Capstone

============================================================
32. RESULTS
============================================================

Create:

/learner/results

Display learner results.

Columns/cards:

Assessment

Course

Date

Score

Grade

Status

Use responsive cards on mobile.

============================================================
33. RESULT DETAIL
============================================================

Display:

Assessment title

Course

Score

Grade

Pass/fail status

Date

Feedback if available

Lecturer feedback

Do not expose results belonging to other learners.

============================================================
34. CERTIFICATES
============================================================

Create:

/learner/certificates

Display certificates earned.

Each certificate:

Programme

Certificate title

Issue date

Certificate ID

Status

View

Download

Verify

If the actual certificate generation system is not implemented yet, create the interface and repository contract.

============================================================
35. DIGITAL CREDENTIALS
============================================================

Create:

/learner/credentials

Prepare for:

Digital badges

Verified credentials

Certificate verification

Credential ID

Issue date

Expiry date if applicable

Share credential

Do not build a third-party credential integration unless explicitly specified.

============================================================
36. CPD
============================================================

Create:

/learner/cpd

Display:

Total CPD points

Current year

Completed activities

Courses contributing to CPD

CPD history

Progress toward target

The target should be configurable rather than hard-coded.

============================================================
37. NOTIFICATIONS
============================================================

Create:

/learner/notifications

Support notification categories:

Course

Assessment

Result

Certificate

Programme

System

Event

Professional Network

AI Mentor

============================================================
38. NOTIFICATION CARD
============================================================

Show:

Icon

Title

Message

Date/time

Read/unread state

Click action

Unread notifications should be visually distinct.

Provide:

Mark as read

Mark all as read

============================================================
39. PROFILE
============================================================

Learner profile:

/learner/profile

Display:

Profile image

First name

Last name

Email

Phone

Country

Professional title

Organisation

Bio

Areas of expertise

LinkedIn/social links where applicable

Do not make sensitive information public automatically.

============================================================
40. SETTINGS
============================================================

Create:

/learner/settings

Sections:

Account

Notifications

Privacy

Security

Learning preferences

Accessibility

============================================================
41. PROFILE COMPLETION
============================================================

Show profile completion percentage.

Example:

Profile 80% complete

Complete your profile to get the most from WEA.

Do not make profile completion annoying.

============================================================
42. AI MENTOR PLACEHOLDER
============================================================

The AI Mentor will be built in Module 09.

For Module 05, create a visually attractive entry point:

WEA AI Mentor

"Your intelligent learning companion."

Button:

ASK WEA AI MENTOR

Clicking it should navigate to the future AI Mentor route.

Do not implement AI functionality in Module 05.

Suggested route:

/learner/ai-mentor

Temporary placeholder is acceptable.

============================================================
43. PROFESSIONAL NETWORK PLACEHOLDER
============================================================

The Professional Network will be built in Module 10.

Create a navigation item:

WEA Professional Network

Suggested route:

/professional-network

For now display a polished placeholder:

"Connect with executives, faculty and fellow WEA professionals."

Do not build the network yet.

============================================================
44. UPCOMING ACTIVITIES
============================================================

Dashboard should show:

Upcoming assessments

Upcoming live classes

Programme milestones

Certificate availability

Events where applicable

Example:

Tomorrow
Executive Leadership Seminar

Friday
Strategic Management Assessment

============================================================
45. DEADLINES
============================================================

Show upcoming deadlines clearly.

Use:

Assessment title

Course

Due date

Time remaining

Action

Example:

3 days remaining

Do not use stressful visual treatments.

============================================================
46. LEARNING ACTIVITY
============================================================

Create a dashboard section:

Recent Learning Activity

Show:

Course accessed

Lesson completed

Assessment submitted

Certificate earned

CPD updated

Use a clean activity timeline.

============================================================
47. LEARNING STREAK
============================================================

Optionally display:

Current learning streak

Example:

7-day learning streak

Use subtle visual treatment.

Do not make this the primary metric.

============================================================
48. DASHBOARD PERSONALIZATION
============================================================

The dashboard should use the authenticated learner's:

First name

Profile image

Programme data

Course data

Progress

Notifications

Results

Certificates

CPD

Do not hard-code:

"John"

"Jane"

or fake learner information into the production UI.

============================================================
49. DATA ARCHITECTURE
============================================================

Do NOT put course data directly into widgets.

Create models/repositories/services.

Conceptually:

LearnerProfile

Programme

Course

CourseModule

Lesson

LessonProgress

Assessment

AssessmentResult

Certificate

Credential

CPDRecord

Notification

LearningActivity

============================================================
50. REPOSITORIES
============================================================

Use repository abstraction.

Examples:

LearnerRepository

ProgrammeRepository

CourseRepository

LessonRepository

ProgressRepository

AssessmentRepository

CertificateRepository

CredentialRepository

CPDRepository

NotificationRepository

Do not put backend calls directly inside presentation widgets.

============================================================
51. MOCK DATA
============================================================

If backend data is not yet available:

Use repository-level mock implementations.

Do NOT hard-code mock data throughout UI widgets.

The architecture must allow replacement with Supabase/backend repositories later.

============================================================
52. STATE MANAGEMENT
============================================================

Use the project's established state management architecture from Module 01.

Do not introduce a second state-management system.

Separate:

UI

State

Repository

Data models

Backend

============================================================
53. RESPONSIVE DESIGN
============================================================

Test:

360px

390px

430px

768px

1024px

1280px

1440px

1920px

Desktop:

Sidebar + content.

Tablet:

Collapsible sidebar.

Mobile:

Drawer navigation.

Cards should become responsive.

Tables should become:

Horizontal scrolling

OR responsive cards

depending on context.

No horizontal page overflow.

============================================================
54. MOBILE NAVIGATION
============================================================

Mobile header:

WEA mark/logo

Page title

Notifications

Menu button

Drawer contains all learner navigation.

Do not squeeze the desktop sidebar into mobile.

============================================================
55. RESPONSIVE DASHBOARD
============================================================

Desktop:

Multi-column dashboard.

Tablet:

Two-column where appropriate.

Mobile:

Single column.

Priority order on mobile:

Welcome

Continue Learning

Progress

Upcoming

Programmes

Activity

Other widgets

============================================================
56. COLOUR SYSTEM
============================================================

Use the Module 02 design tokens.

Do NOT create arbitrary colours.

Primary:

WUCO Blue

Secondary:

Deep Navy

Background:

White

Surface:

White

Soft surface:

Very Light Blue

Border:

Light Grey / Blue Grey

Text:

Deep Navy

Muted text:

Slate Grey

Success:

Accessible green

Warning:

Accessible amber

Error:

Accessible red

============================================================
57. TYPOGRAPHY
============================================================

Use the typography system from Module 02.

Do not use random fonts.

Do not mix too many typefaces.

Headings:

Premium institutional feel.

Body:

Highly readable.

Ensure:

Strong hierarchy

Proper line height

Good spacing

No text/background conflicts.

============================================================
58. IMAGES
============================================================

Use premium institutional imagery.

Potential imagery:

African executives

Leadership meetings

Executive classrooms

International business

African trade

Investment

Technology

Policy

Professional networking

Images should feel authentic and high quality.

Do not use random low-quality stock images.

Do not place images behind text unless there is sufficient contrast.

============================================================
59. HOVER EFFECTS
============================================================

Desktop cards should have subtle hover effects:

Slight elevation

Border transition

Small image scale

Soft shadow

Text/icon transition

Do not overanimate every element.

============================================================
60. ANIMATIONS
============================================================

Use subtle:

Fade-in

Slide-up

Staggered cards

Progress animation

Page transition

Skeleton loading

Hover transitions

Do not create distracting animations.

Animation should support usability.

============================================================
61. SKELETON LOADING
============================================================

Create reusable skeleton states for:

Dashboard

Courses

Programmes

Notifications

Certificates

Results

Profile

Do not show blank white screens while data loads.

============================================================
62. EMPTY STATES
============================================================

Create beautiful empty states.

Example:

No active programmes.

"You haven't enrolled in a programme yet."

Button:

EXPLORE PROGRAMMES

Other examples:

No certificates yet.

No notifications.

No assessments.

No CPD records.

Do not make empty states look like errors.

============================================================
63. ERROR STATES
============================================================

Create reusable error state.

Example:

We couldn't load your courses.

TRY AGAIN

Errors should be understandable.

Never show raw backend/database errors.

============================================================
64. OFFLINE / NETWORK
============================================================

If data cannot be loaded:

Show:

Unable to connect.

Please check your internet connection and try again.

Provide:

TRY AGAIN

============================================================
65. ACCESSIBILITY
============================================================

Implement:

Semantic labels

Keyboard navigation

Visible focus

Accessible colour contrast

Screen reader labels

Keyboard-accessible navigation

Accessible touch targets

Do not communicate status only through colour.

============================================================
66. SECURITY
============================================================

Learners must only access their own:

Courses

Progress

Results

Certificates

CPD

Notifications

Profile

Do not trust client-side filtering for security.

Backend authorization must be used when connected.

Never expose another learner's records.

============================================================
67. COURSE PROGRESS SECURITY
============================================================

Learners must not be able to manually alter:

Course progress

Grades

Results

Certificate status

CPD points

Completion status

These values must ultimately be controlled by authorized backend operations.

============================================================
68. CERTIFICATE SECURITY
============================================================

Learners cannot:

Create certificates

Edit certificates

Change certificate ID

Change issue date

Change verification status

They can only view/share/download credentials they legitimately earned.

============================================================
69. PERFORMANCE
============================================================

Optimize:

Images

Lists

Course cards

Video thumbnails

Dashboard rendering

Animations

Avoid unnecessary rebuilds.

Use lazy loading where appropriate.

Do not load every course image or lesson at once if unnecessary.

============================================================
70. DASHBOARD DESIGN
============================================================

The dashboard should have strong visual hierarchy.

Recommended:

Top:
Welcome + profile context

Next:
Learning statistics

Primary:
Continue Learning

Then:
My Programmes

Then:
Upcoming Activities

Then:
Recent Activity

Optional:
AI Mentor

Optional:
Professional Network

Do not overload the first screen.

============================================================
71. PREMIUM EXECUTIVE FEEL
============================================================

Use:

Generous spacing

Excellent typography

Strong alignment

Consistent cards

Subtle borders

High-quality images

Professional icons

Elegant micro-interactions

Clean information hierarchy

Avoid:

Excessive rounded corners

Excessive shadows

Neon colours

Huge text everywhere

Too many cards

Crowded dashboards

Conflicting colours

Cheap-looking gradients

============================================================
72. COMPONENTS
============================================================

Reuse Module 02 design components.

Create learner-specific components such as:

WEALearnerShell

WEALearnerSidebar

WEALearnerHeader

WEAWelcomeBanner

WEAStatCard

WEAContinueLearningCard

WEAProgrammeCard

WEACourseCard

WEAProgressBar

WEAActivityTimeline

WEAUpcomingCard

WEANotificationItem

WEACertificateCard

WEACredentialCard

WEACPDCard

WEAEmptyState

WEAErrorState

WEASkeleton

============================================================
73. FILE ORGANIZATION
============================================================

Follow the architecture established in Module 01.

Prefer feature-based organization.

Conceptually:

lib/
  features/
    learner/
      presentation/
        pages/
        widgets/
      application/
      domain/
      data/

Do not place the entire learner dashboard in one huge Dart file.

Each major screen should have its own file.

============================================================
74. MAIN DASHBOARD FILE
============================================================

Create a dedicated file such as:

learner_dashboard_page.dart

Do not put all subcomponents inside this file.

Keep it readable.

============================================================
75. COURSE FILES
============================================================

Use separate files for:

course_list_page.dart

course_detail_page.dart

learning_page.dart

lesson_page.dart

course_card.dart

course_progress.dart

curriculum_widget.dart

============================================================
76. PROGRAMME FILES
============================================================

Use separate files for:

programme_list_page.dart

programme_detail_page.dart

programme_card.dart

============================================================
77. ASSESSMENT FILES
============================================================

Use separate files for:

assessment_page.dart

assessment_detail_page.dart

result_page.dart

============================================================
78. CERTIFICATE FILES
============================================================

Use separate files for:

certificate_page.dart

certificate_detail_page.dart

credential_page.dart

============================================================
79. PROFILE FILES
============================================================

Use separate files for:

learner_profile_page.dart

learner_settings_page.dart

============================================================
80. NO LECTURER FUNCTIONALITY
============================================================

STRICTLY DO NOT BUILD:

Lecturer dashboard

Lecturer course creation

Lecturer grading interface

Faculty management

Lecturer analytics

These belong to future modules.

============================================================
81. NO ADMIN FUNCTIONALITY
============================================================

STRICTLY DO NOT BUILD:

Admin dashboard

Super Admin dashboard

User administration

Programme administration

Course administration

Hero image management

Certificate administration

These belong to future modules.

============================================================
82. NO AI IMPLEMENTATION
============================================================

Do not implement the AI Mentor in Module 05.

Only create a polished entry point and route placeholder.

Module 09 will build the actual AI Mentor.

============================================================
83. NO PROFESSIONAL NETWORK IMPLEMENTATION
============================================================

Do not implement:

Connections

Messaging

Feeds

Posts

Groups

Networking

These belong to Module 10.

Only provide navigation/placeholder.

============================================================
84. NOTIFICATION ARCHITECTURE
============================================================

Prepare for future notifications including:

Results posted

New course available

Programme enrollment

Certificate issued

New feature announcement

Upcoming assessment

Application status

Professional Network updates

AI Mentor updates

Use the existing notification architecture where available.

============================================================
85. FUTURE EMAIL INTEGRATION
============================================================

The learner dashboard must be compatible with future email notifications.

Do not implement email delivery directly inside learner widgets.

============================================================
86. FUTURE CERTIFICATE VERIFICATION
============================================================

Prepare certificate routes for eventual public verification.

Potential future route:

/verify-certificate/:certificateId

Do not implement the public verification system in Module 05.

============================================================
87. FUTURE PAYMENT INTEGRATION
============================================================

Do not implement payment processing in Module 05.

The architecture should allow programmes/courses to eventually have:

Price

Currency

Enrollment status

Payment status

============================================================
88. TESTING
============================================================

Create tests for:

Learner authentication guard

Dashboard loading

Programme list

Course list

Course progress

Lesson completion

Assessment list

Results

Certificates

CPD

Notifications

Profile

Role protection

Empty states

Error states

Responsive components where practical

============================================================
89. UI TESTING
============================================================

Run:

flutter run -d chrome

Inspect:

Desktop

Tablet

Mobile

Verify:

No overflow

No clipped text

No overlapping components

No broken images

No unreadable text

No conflicting colours

No excessive whitespace

No cramped mobile layout

============================================================
90. PERFORMANCE TESTING
============================================================

Check:

flutter analyze

flutter test

Ensure there are no unnecessary warnings.

Optimize large lists.

Optimize images.

Avoid excessive animation.

============================================================
91. FINAL QUALITY STANDARD
============================================================

The final learner dashboard must feel like a serious executive education platform.

Think:

Harvard Business School-level institutional presentation

Modern African executive education

Premium professional technology

But DO NOT copy another institution's design.

WEA must have its own visual identity.

============================================================
92. FINAL COPILOT TASK
============================================================

Implement MODULE 05 now.

First read:

.github/copilot/00_MASTER_INSTRUCTIONS.md
.github/copilot/01_PROJECT_SETUP.md
.github/copilot/02_DESIGN_SYSTEM.md
.github/copilot/03_PUBLIC_WEBSITE.md
.github/copilot/04_AUTHENTICATION.md
.github/copilot/05_LEARNER_DASHBOARD.md

Then inspect the existing repository.

Reuse the established architecture.

Reuse the WEA design system.

Reuse the WUCO logo.

Use the WUCO blue + deep navy + white identity.

DO NOT use black/gold.

Implement:

- Learner dashboard
- Learner shell
- Sidebar
- Header
- Profile
- My Programmes
- Programme details
- My Courses
- Course details
- Course learning interface
- Curriculum
- Lessons
- Progress tracking UI
- Assessments
- Results
- Certificates
- Digital credentials
- CPD
- Notifications
- Learning activity
- Upcoming activities
- Search interface
- AI Mentor entry point
- Professional Network entry point
- Settings
- Loading states
- Empty states
- Error states
- Responsive layouts
- Accessibility
- Route protection

Create clean feature-based files.

Do not create one giant Dart file.

Do not build lecturer or admin functionality.

Do not implement AI Mentor yet.

Do not implement Professional Network yet.

Do not redesign the public website.

Do not redesign authentication.

Run:

flutter pub get
flutter analyze
flutter test
flutter run -d chrome

Fix errors and warnings.

Inspect the running application.

Test:

360px
390px
430px
768px
1024px
1280px
1440px
1920px

Ensure the learner dashboard works properly across all screen sizes.

STOP after Module 05 is complete.

At the end report:

1. Files created
2. Files modified
3. Learner dashboard architecture
4. Routes created
5. Components created
6. Models created
7. Repositories created
8. Authentication integration
9. Responsive testing
10. Tests performed
11. Backend integration status
12. Remaining issues