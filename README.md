# skillsense_ai

SkillSense AI Flutter Frontend (Web & Native Mobile).

## Unified Cross-Platform Auth Architecture (Clerk)

This project ships Flutter Web + iOS/Android from a single codebase. Rather than using a single SDK across targets, auth is split by platform underneath a unified facade:

### Why Split Platform SDKs?
1. **Header Conflict Bug on Web**: The Dart SDK (`clerk_flutter`/`clerk_auth`) sends both `Origin` and `Authorization` headers simultaneously during web HTTP requests, triggering Clerk's `origin_authorization_headers_conflict` security policy.
2. **Missing Dev-Browser Handshake**: `clerk_flutter` lacks the browser `__clerk_db_jwt` bootstrap handshake required by Clerk dev instances on web, causing `dev_browser_unauthenticated` errors.

### Implementation Architecture
- **Web (`kIsWeb`)**: Backed by Clerk's official JavaScript SDK (`clerk-js`) loaded via `<script>` tag in `web/index.html` and bound via `dart:js_interop` (`AuthServiceWeb` / `clerk_js_interop.dart`). `clerk-js` automatically handles the dev-browser handshake and browser cookie management.
- **Native (iOS/Android)**: Backed by `clerk_flutter` / `clerk_auth` Dart SDK (`AuthServiceNative`).
- **Unified Facade**: All UI screens interact exclusively with `AuthService` (`auth_service.dart`) / `AuthServiceInterface` (`auth_service_interface.dart`). Platform selection is performed at compile time via conditional imports (`auth_service_stub.dart`, `platform_app_stub.dart`).

> [!WARNING]
> **Do not attempt to "simplify" auth back into a single SDK.** Merging web back into `clerk_flutter` will reintroduce the header conflict and dev-browser unauthenticated errors.

### Sign-out Handling
Sign-out is defined on `AuthServiceInterface.signOut()` but is not yet called by any UI screen. When adding sign-out UI buttons in settings/profile screens, invoke `AuthService.signOut(context)`.

### Dev-Only Setting: Bot Sign-Up Protection (CAPTCHA)
When using headless sign-up flows (`signUp` / `attemptSignUp`), Clerk requires either a Turnstile CAPTCHA token or for **Bot sign-up protection** to be toggled off in the Clerk Dashboard for development:
- **Location**: Clerk Dashboard -> *Attack Protection* -> *Bot sign-up protection*
- **Dev Environment**: Must be toggled **OFF** to permit custom headless sign-up without embedded Turnstile widgets.
