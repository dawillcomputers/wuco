# WUCO EXECUTIVE ACADEMY (WEA)
# MODULE 04 — AUTHENTICATION, IDENTITY & ACCESS CONTROL

============================================================
READ FIRST — MANDATORY
============================================================

Before doing anything, read:

1. .github/copilot/00_MASTER_INSTRUCTIONS.md
2. .github/copilot/01_PROJECT_SETUP.md
3. .github/copilot/02_DESIGN_SYSTEM.md
4. .github/copilot/03_PUBLIC_WEBSITE.md

DO NOT skip these files.

This is Module 04.

The objective is to implement the complete authentication and identity foundation for WUCO Executive Academy.

============================================================
1. BRAND REFERENCE — CRITICAL
============================================================

The supplied WUCO Executive Academy logo is the authoritative visual reference.

The logo contains:

- WUCO globe
- WUCO lettering
- EXECUTIVE ACADEMY
- Blue institutional identity
- Deep navy typography
- Clean white presentation

The authentication experience MUST match this identity.

DO NOT use the previous black/gold design.

DO NOT introduce gold.

DO NOT introduce a black-dominant interface.

The authentication system must use:

WHITE
WUCO BLUE
DEEP NAVY
LIGHT BLUE
SOFT GREY

The visual feeling must be:

Institutional
Executive
Premium
Trustworthy
Modern
Professional
African
International

============================================================
2. AUTHENTICATION OBJECTIVE
============================================================

Build a secure, scalable authentication system for:

WUCO Executive Academy.

Users should be able to:

- Register
- Login
- Logout
- Verify email
- Reset password
- Change password
- Maintain profile
- Update profile information
- Manage session
- Access the correct dashboard based on role

Authentication must be designed so it can later support:

Learners
Lecturers
Administrators
Super Administrators
Applicants
Professional Network Members

============================================================
3. DO NOT BREAK EXISTING ARCHITECTURE
============================================================

Inspect Module 01 and the existing repository first.

Use the backend/authentication architecture already selected in the project.

If Supabase Authentication was established in Module 01:

USE SUPABASE AUTH.

Do not introduce Firebase or another authentication provider.

If another authentication architecture was explicitly established in Module 01:

FOLLOW THAT ARCHITECTURE.

Do not replace the project's backend architecture unnecessarily.

============================================================
4. AUTHENTICATION ROUTES
============================================================

Implement:

/login

/register

/forgot-password

/reset-password

/verify-email

/change-password

/profile

/logout

/auth/callback

If the project architecture requires different route names, maintain the same functionality.

============================================================
5. LOGIN PAGE
============================================================

Create a premium WEA login page.

Desktop layout:

LEFT:
Brand / visual area

RIGHT:
Login form

OR use a sophisticated centered institutional layout where appropriate.

The page must remain clean.

Logo:

WUCO EXECUTIVE ACADEMY

Use the supplied WEA logo.

Do not distort the logo.

============================================================
6. LOGIN PAGE CONTENT
============================================================

Display:

Welcome back

Sign in to continue to WUCO Executive Academy.

Fields:

Email Address

Password

Options:

Remember me

Forgot password?

Primary button:

SIGN IN

Additional:

Don't have an account?

CREATE ACCOUNT

============================================================
7. LOGIN VISUAL DESIGN
============================================================

Background:

White or extremely light blue.

Use deep navy for headings.

Use WUCO blue for:

- Buttons
- Links
- Focus states
- Accent lines
- Active states

Use subtle blue gradients only when they improve the design.

Avoid excessive gradients.

============================================================
8. LOGIN HERO IMAGE
============================================================

The login page may include a large institutional image.

Suggested imagery:

African executives

Executive classroom

African leadership conference

Professional networking

International business environment

The image should be professionally treated.

Use a subtle blue overlay.

The image must never overpower the form.

============================================================
9. LOGIN FORM
============================================================

Inputs must be:

White background

Subtle grey border

Dark navy text

Grey placeholder

Blue focus border

Blue focus glow should be extremely subtle.

Rounded corners should be professional and restrained.

Do not create excessively rounded pill inputs.

============================================================
10. PASSWORD VISIBILITY
============================================================

Password field must have:

Show password

Hide password

Use an accessible icon button.

============================================================
11. LOGIN VALIDATION
============================================================

Validate:

Email format

Required email

Required password

Display errors clearly.

Examples:

Please enter your email address.

Please enter your password.

Please enter a valid email address.

Invalid email or password.

Do not reveal sensitive authentication information.

============================================================
12. LOGIN LOADING STATE
============================================================

When signing in:

Disable submit button.

Display a loading indicator.

Example:

Signing in...

Do not allow multiple login submissions.

============================================================
13. SUCCESS LOGIN FLOW
============================================================

After successful login:

Retrieve the authenticated user's profile and role.

Route the user to the correct destination.

Learner:

/learner

Lecturer:

/lecturer

Admin:

/admin

Super Admin:

/super-admin

Applicant:

/application

Professional Network member:

/professional-network/member

These dashboards may not exist yet.

Prepare the routing architecture so Module 05 onward can implement them.

============================================================
14. ROLE-BASED REDIRECTION
============================================================

Do NOT simply redirect every authenticated user to one dashboard.

Authentication must understand roles.

Initial roles:

APPLICANT

LEARNER

LECTURER

ADMIN

SUPER_ADMIN

PROFESSIONAL_MEMBER

The architecture must allow additional roles later.

============================================================
15. REGISTER PAGE
============================================================

Create:

/register

Heading:

Create your WEA account.

Supporting text:

Join WUCO Executive Academy and begin your executive learning journey.

Fields:

First Name

Last Name

Email

Phone Number

Country

Password

Confirm Password

Terms acceptance checkbox

Button:

CREATE ACCOUNT

============================================================
16. REGISTRATION EXPERIENCE
============================================================

Keep registration simple.

Do NOT ask learners to fill out an enormous form during account creation.

Additional information can be collected later during onboarding.

============================================================
17. PASSWORD REQUIREMENTS
============================================================

Password should have configurable security requirements.

Recommended:

Minimum 8 characters.

Require at least:

One uppercase letter

One lowercase letter

One number

One special character

Display password strength while typing.

Use a visual strength indicator.

============================================================
18. CONFIRM PASSWORD
============================================================

Confirm password must match.

Display:

Passwords do not match.

Do not submit invalid registration.

============================================================
19. TERMS
============================================================

Registration must require acceptance of:

Terms and Conditions

Privacy Policy

Use a checkbox.

Links:

/terms

/privacy

============================================================
20. EMAIL VERIFICATION
============================================================

After registration:

Show a dedicated verification screen.

Heading:

Verify your email.

Message:

We've sent a verification link to your email address.

Options:

RESEND EMAIL

CHANGE EMAIL

BACK TO LOGIN

Do not expose sensitive system information.

============================================================
21. RESEND VERIFICATION
============================================================

Implement resend verification functionality.

Prevent abuse with:

Cooldown timer.

Example:

Resend available in 45 seconds.

Do not allow unlimited rapid requests.

============================================================
22. FORGOT PASSWORD
============================================================

Build:

/forgot-password

Heading:

Reset your password.

Message:

Enter your email address and we'll send you instructions to reset your password.

Field:

Email Address

Button:

SEND RESET LINK

============================================================
23. RESET PASSWORD
============================================================

Build:

/reset-password

Fields:

New Password

Confirm New Password

Button:

UPDATE PASSWORD

Validate password strength.

Confirm successful reset.

Provide:

RETURN TO LOGIN

============================================================
24. CHANGE PASSWORD
============================================================

Authenticated users should eventually access:

/change-password

Fields:

Current Password

New Password

Confirm New Password

Button:

UPDATE PASSWORD

This should be accessible from the user profile/settings area.

============================================================
25. PROFILE
============================================================

Create a basic authenticated profile screen.

Route:

/profile

Show:

Profile image

First name

Last name

Email

Phone

Country

Role

Account status

Email verification status

Buttons:

EDIT PROFILE

CHANGE PASSWORD

LOG OUT

Do not build full learner profile functionality yet.

============================================================
26. SESSION MANAGEMENT
============================================================

Authentication must properly manage:

Login session

Session restoration

Session expiration

Logout

Token refresh where supported by the backend

App restart

Browser refresh

Do not store sensitive passwords locally.

============================================================
27. AUTH STATE
============================================================

Create a central authentication state manager/service.

Conceptually:

AuthState

States:

Initial

Loading

Unauthenticated

Authenticated

EmailUnverified

Error

Do not scatter authentication logic across individual widgets.

============================================================
28. AUTH SERVICE
============================================================

Create a centralized service such as:

AuthService

Responsibilities:

signIn()

signUp()

signOut()

sendPasswordReset()

resetPassword()

resendVerification()

changePassword()

getCurrentUser()

refreshSession()

isAuthenticated()

getUserRole()

============================================================
29. USER MODEL
============================================================

Create a user profile model appropriate to the existing architecture.

Conceptually:

UserProfile

Fields:

id

firstName

lastName

email

phone

country

avatarUrl

role

status

emailVerified

createdAt

updatedAt

============================================================
30. ROLE ENUM
============================================================

Use a strongly typed role representation.

Example:

UserRole.applicant

UserRole.learner

UserRole.lecturer

UserRole.admin

UserRole.superAdmin

UserRole.professionalMember

Do not scatter raw role strings throughout the application.

============================================================
31. ACCOUNT STATUS
============================================================

Support:

Active

Pending

Suspended

Disabled

PendingApproval

This will later support lecturer/admin approval workflows.

============================================================
32. ROUTE GUARDS
============================================================

Create authentication route guards.

Examples:

RequireAuthentication

RequireGuest

RequireRole

RequireEmailVerification

Unauthenticated user attempting:

/learner

must be redirected to:

/login

Authenticated user attempting:

/login

may be redirected to the appropriate dashboard.

============================================================
33. ROLE PROTECTION
============================================================

A learner MUST NOT be able to access:

/lecturer

/admin

/super-admin

A lecturer MUST NOT be able to access:

/admin

/super-admin

An admin MUST NOT automatically have Super Admin privileges.

Super Admin access must be explicitly granted.

Never rely only on hidden UI buttons for security.

Enforce permissions at the route/service/backend level.

============================================================
34. SUPER ADMIN
============================================================

Super Admin is the highest privileged account.

Super Admin will eventually manage:

Users

Lecturers

Programmes

Courses

Hero images

Website content

Events

Research

Certificates

Professional Network

Platform settings

Roles and permissions

Do not build the Super Admin dashboard yet.

Only prepare the access-control foundation.

============================================================
35. LECTURER APPROVAL
============================================================

Architecture must support lecturer accounts being:

PendingApproval

Approved

Suspended

Rejected

Do not automatically grant lecturer privileges simply because a user selects "Lecturer" during registration.

Lecturer access must require administrative approval.

============================================================
36. ADMIN APPROVAL
============================================================

Administrative roles must never be self-assigned through normal registration.

Only authorized Super Admins can grant:

ADMIN

SUPER_ADMIN

LECTURER

roles.

============================================================
37. APPLICANT ACCOUNT
============================================================

Applicants may create an account before applying to a programme.

Their account can later connect to:

Application

Programme

Admission status

Enrollment

Do not build the full application system yet.

============================================================
38. ERROR HANDLING
============================================================

Create reusable authentication error handling.

Handle:

Invalid credentials

Email already exists

Weak password

Expired reset link

Invalid reset link

Network failure

Server failure

Session expired

Email not verified

Account suspended

Account disabled

Unknown error

Never display raw backend errors to users.

============================================================
39. NETWORK ERROR
============================================================

If network connectivity fails:

Show:

Unable to connect.

Please check your internet connection and try again.

Provide:

TRY AGAIN

============================================================
40. ACCOUNT STATUS MESSAGES
============================================================

Suspended:

Your account has been temporarily suspended. Please contact WEA support.

Disabled:

Your account is currently disabled. Please contact WEA support.

Pending approval:

Your account is awaiting administrative approval.

============================================================
41. LOGOUT
============================================================

Logout must:

- Clear authentication session
- Clear sensitive local state
- Return to public homepage or login
- Prevent access to protected pages using browser back navigation

============================================================
42. LOGOUT CONFIRMATION
============================================================

For dashboard logout:

Display a subtle confirmation dialog:

Sign out?

Are you sure you want to sign out of your WEA account?

Buttons:

CANCEL

SIGN OUT

============================================================
43. AUTHENTICATION DESIGN SYSTEM
============================================================

Reuse Module 02 components.

Use:

WEAContainer

WEAButton

WEAOutlinedButton

WEATextField

WEASectionHeading

WEAImage

WEADialog

WEASkeleton

WEAErrorState

Do NOT create duplicate button/input systems.

============================================================
44. AUTHENTICATION COLOURS
============================================================

Use the WUCO logo identity.

Primary:

WUCO Blue

Secondary:

Deep Navy

Background:

White

Soft background:

Very Light Blue

Borders:

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

Semantic colours should be used only for system states.

============================================================
45. BLUE GRADIENT
============================================================

A subtle blue gradient may be used for:

Hero image overlays

Primary CTA emphasis

Decorative background shapes

Login visual panel

But use gradients carefully.

Do not turn the entire website into a gradient interface.

============================================================
46. LOGO
============================================================

Use the supplied WUCO Executive Academy logo.

Do not:

- Stretch it
- Rotate it
- Change its proportions
- Add effects that distort it
- Recolour the logo arbitrarily

Provide:

Light-background version

Dark-background version only if the logo supports it.

The default authentication interface should use the logo on white/light surfaces.

If the supplied logo has a transparent background, preserve it.

============================================================
47. AUTH PAGE BRANDING
============================================================

Every authentication page should have a consistent brand header.

Example:

[ WUCO EXECUTIVE ACADEMY LOGO ]

Small navigation:

Back to WEA

============================================================
48. LOGIN DESKTOP LAYOUT
============================================================

Recommended layout:

--------------------------------------------------
|                                                |
| WEA visual / image | Login form                |
|                    |                           |
| Executive learning | Welcome back              |
| African leadership | Sign in...                |
|                    |                           |
|                    | Email                     |
|                    | Password                  |
|                    | Forgot password?          |
|                    |                           |
|                    | SIGN IN                   |
|                    |                           |
|                    | Create account            |
--------------------------------------------------

Keep it balanced.

Do not make the visual panel excessively large.

============================================================
49. MOBILE LOGIN
============================================================

On mobile:

Logo

Welcome text

Form

CTA

Register link

The image panel may:

- Move above the form
- Become a compact banner
- Or disappear if needed for usability

Do not force desktop split-screen into a small phone.

============================================================
50. AUTH PAGE ANIMATIONS
============================================================

Use subtle:

Fade in

Slide up

Staggered form entry

Button transition

Input focus animation

Page transition

Do not use dramatic animation.

Authentication should feel fast and trustworthy.

============================================================
51. LOADING UI
============================================================

Create:

WEAAuthLoadingScreen

Use when checking the current authentication state.

It should display:

WEA logo

Subtle loading indicator

Optional:

Loading your account...

Avoid a blank screen.

============================================================
52. AUTHENTICATED REDIRECT
============================================================

When the application opens:

Check session.

If authenticated:

Retrieve profile.

Determine role.

Determine account status.

Determine email verification.

Then route accordingly.

Do not briefly display the login page before redirecting.

============================================================
53. SECURITY
============================================================

Follow secure authentication practices.

Never:

Store plaintext passwords.

Expose tokens unnecessarily.

Log passwords.

Log sensitive authentication credentials.

Hard-code service keys.

Put secret keys in Flutter source code.

Do not rely on client-side role checks alone.

============================================================
54. ENVIRONMENT VARIABLES
============================================================

Use environment configuration for:

Backend URL

Public API keys

Supabase URL/key if applicable

Other non-secret environment configuration

Never commit private service-role keys.

============================================================
55. PROFILE SECURITY
============================================================

Users can edit only their own profile.

Users cannot change their own role.

Users cannot promote themselves.

Users cannot change account status.

Users cannot access another user's profile unless authorized by their role.

============================================================
56. RESPONSIVENESS
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

Authentication pages must have:

No horizontal scrolling

No clipped text

No overlapping fields

No oversized forms

No broken images

No inaccessible buttons

============================================================
57. ACCESSIBILITY
============================================================

Implement:

Semantic labels

Keyboard navigation

Visible focus states

Accessible error messages

Sufficient contrast

Accessible buttons

Screen-reader-friendly form labels

Appropriate touch targets

Do not communicate errors only through colour.

============================================================
58. FORMS
============================================================

Use appropriate keyboard types:

Email:

email

Phone:

phone

Password:

password

Use autofill where appropriate.

Support browser password managers where possible.

============================================================
59. AUTHENTICATION FEEDBACK
============================================================

Every action should provide appropriate feedback.

Examples:

Signing in...

Creating account...

Sending reset link...

Updating password...

Signing out...

Do not freeze the interface without feedback.

============================================================
60. TESTING
============================================================

Create authentication tests for:

Registration

Login

Logout

Invalid login

Duplicate email

Password validation

Password mismatch

Forgot password

Reset password

Role detection

Route guard

Unauthenticated access

Unauthorized role access

Session restoration

Account status

Email verification state

============================================================
61. MOCK/DEVELOPMENT MODE
============================================================

If backend authentication is not yet connected or configured:

Create clean repository interfaces and mock implementations.

DO NOT hard-code fake authentication directly inside UI widgets.

The UI should communicate through:

AuthRepository / AuthService

so the real backend can be connected without rebuilding the UI.

============================================================
62. FUTURE DASHBOARD INTEGRATION
============================================================

Prepare routing for:

/learner

/lecturer

/admin

/super-admin

/application

/professional-network/member

These destinations may currently display temporary placeholder screens.

DO NOT build their actual dashboards.

Module 05 onward will build them.

============================================================
63. DESIGN SHOWCASE
============================================================

Extend the existing development design showcase if appropriate.

Add authentication states:

Login

Register

Forgot Password

Reset Password

Email Verification

Loading

Validation Error

Network Error

Suspended Account

Pending Approval

Success

Make sure every state follows the WUCO visual identity.

============================================================
64. NO DASHBOARDS YET
============================================================

STRICTLY DO NOT BUILD:

Learner dashboard

Lecturer dashboard

Admin dashboard

Super Admin dashboard

Course management

AI Mentor

Professional Network functionality

Certificate system

Payment system

These are future modules.

============================================================
65. NO PUBLIC WEBSITE REDESIGN
============================================================

Do not redesign Module 03.

Do not replace the public website.

Only ensure authentication pages integrate naturally with the existing public WEA experience.

============================================================
66. FINAL QUALITY STANDARD
============================================================

The authentication system should feel like it belongs to a serious international executive academy.

The first impression should be:

Trusted.

Professional.

Institutional.

Modern.

Premium.

Clean.

African.

Global.

============================================================
67. REQUIRED TESTING
============================================================

Run:

flutter pub get

flutter analyze

flutter test

flutter run -d chrome

Test:

Registration

Login

Logout

Password reset

Email verification

Route protection

Role-based routing

Session persistence

Responsive layout

============================================================
68. FINAL COPILOT TASK
============================================================

Implement Module 04 now.

First read:

.github/copilot/00_MASTER_INSTRUCTIONS.md

.github/copilot/01_PROJECT_SETUP.md

.github/copilot/02_DESIGN_SYSTEM.md

.github/copilot/03_PUBLIC_WEBSITE.md

Then inspect the existing repository.

Use the existing architecture.

Use the existing WEA design system.

Use the WUCO Executive Academy logo and its white/blue/navy identity as the authoritative visual reference.

Do not use the previous black/gold theme anywhere in the authentication experience.

Actually create and modify the Flutter files.

Implement:

- Login
- Registration
- Email verification
- Forgot password
- Reset password
- Change password
- Profile
- Logout
- Authentication state
- Session management
- Route guards
- Role-based routing
- Account status handling
- Authentication error handling
- Responsive authentication UI
- Accessibility
- Authentication tests

Do not build the dashboards yet.

Do not build Module 05.

Run:

flutter pub get

flutter analyze

flutter test

flutter run -d chrome

Fix all errors and warnings introduced by Module 04.

Inspect the running UI.

Verify the authentication pages at mobile, tablet and desktop sizes.

STOP after Module 04 is complete.

At the end report:

1. Files created
2. Files modified
3. Authentication architecture
4. Routes created
5. Roles implemented
6. Route guards implemented
7. Backend integration status
8. Responsive testing
9. Tests performed
10. Remaining issues

