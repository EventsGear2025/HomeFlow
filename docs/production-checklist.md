# Production Checklist

## Verified In Repo

- Vercel is configured to build Flutter web from `build/web` via `vercel.json`.
- Flutter web builds successfully from the repo root.
- Google OAuth now uses the deployed web origin on web and the app deep link on mobile.
- App-wide scroll drag is enabled for touch, mouse, and trackpad input.

## Manual Release Checks

- Open the production Vercel URL and confirm the app shell loads without console errors.
- Refresh a deep link and confirm it resolves back to the app instead of a 404.
- Verify email sign up, OTP verification, sign in, and sign out flows.
- Verify Google sign-in on the production domain.
- In Supabase Auth settings, add the production site URL and redirect URLs for:
  - the Vercel production domain
  - any custom domain
  - `com.example.myapp://login-callback/`
- Confirm any Google OAuth provider configuration in Supabase includes the same web redirect URLs.
- Smoke-test one authenticated data path each for dashboard, supplies, shopping, and admin access.
- Check the production browser console and network panel for failing requests.

## iOS Simulator Checks

- Confirm long lists and forms drag-scroll with mouse or trackpad in the simulator.
- Confirm modal sheets and auth forms remain scrollable with the keyboard open.
- Confirm no layout overflow warnings appear in the debug console on smaller iPhone simulators.