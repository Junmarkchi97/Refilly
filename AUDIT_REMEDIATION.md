# Refilly security and reliability remediation

## Deployment order

1. Back up the Supabase database and test migrations on staging first.
2. Apply `supabase/migrations/20261031030000_order_security.sql` before deploying the corresponding Flutter client.
3. Confirm direct authenticated updates to `orders` are denied.
4. Confirm an owner can only move orders through authorized status transitions using `owner_set_order_status`.
5. Confirm an anonymous rider can update delivery status only with a valid unexpired link.
6. Verify COD orders remain `unpaid` after a status change until payment collection is confirmed through a future audited flow.
7. Deploy Flutter, then test customer checkout, owner assignment, live rider sharing, owner approval, and cancellation.

## Security follow-ups requiring infrastructure or product decisions

- Rider URLs are bearer credentials; for higher assurance require rider phone verification or authenticated rider accounts before allowing delivery completion.
- Rider GPS tracking currently requires foreground execution and is **not** guaranteed when the browser sleeps, the app is backgrounded, or the phone is locked.
- Configure deployment HTTP `Referrer-Policy: no-referrer` and `Cache-Control: no-store` for pages handling delivery tokens. Verify your hosting provider supports these headers.
- Online payments are deliberately blocked until PayMongo/GCash/Maya server-side payment verification is implemented.
- Integrate transaction-safe payment collection confirmation rather than deriving `payment_status` from delivery status.
- Add database RLS/RPC integration tests using a staging Supabase project with distinct owner, customer, rider, and administrator principals.

## Quality gate

Run `flutter pub get`, `flutter analyze`, and `flutter test`. The included GitHub Actions workflow runs these checks when a PR opens. It does not deploy database migrations automatically.
