# Refilly

Philippine marketplace for water refilling stations, built to expand to rice, LPG and other daily essentials (products are generic, grouped by `categories`).

One Flutter app with role-based screens (roles: customer, owner, admin; riders have no accounts):
- **Customer**: map of all stations (OpenStreetMap), browse products, cart + checkout with map pin, Cash on Delivery (GCash/Maya hook ready), live order status and live rider tracking. Menu → **Verify my phone** (SMS OTP) and **Become a station owner** (apply with DTI/SEC or business permit + station photo).
- **Station owner** (great on Flutter web): station profile, products/prices, incoming orders, accept/reject, **assign a rider by name + mobile** → a private delivery link to copy or share by SMS/Messenger, sales dashboard.
- **Rider (no login)**: opens the link `<APP_URL>/#/rider/<token>`, sees the order, taps Start delivery (shares live GPS), Mark delivered. The link stops working once the order is delivered/cancelled, a new link is made, or after 48h.
- **Admin**: reviews owner applications (view documents, approve/reject). Approval runs `approve_owner_application`, which creates the station and makes the applicant an owner. Owners cannot create stations directly.

Stack: Flutter · Supabase (Auth, Postgres, RLS, Realtime) · flutter_map + OSM tiles · geolocator · fl_chart.

## Setup

1. **Install Flutter** (3.35+): https://docs.flutter.dev/get-started/install
2. **Create a Supabase project** at https://supabase.com.
3. **Run the schema**: in the Supabase dashboard → SQL Editor, paste and run `supabase/migrations/20261030000000_init.sql`, then `supabase/seed.sql` (sample Metro Manila stations + water products).
   Or with the CLI: `supabase link --project-ref <ref> && supabase db push` then run the seed.
4. (Dev) Auth → Providers → Email: disable "Confirm email" for quick testing.
5. **Configure the app**: `cp env.example.json env.json` and fill in your Project URL and anon/publishable key (Settings → API). `env.json` is git-ignored.
6. **Run**:
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=env.json            # phone/emulator
   flutter run -d chrome --dart-define-from-file=env.json  # owner dashboard on web
   flutter build web --dart-define-from-file=env.json      # deployable web build
   ```
7. **Make yourself admin** (SQL editor): `update profiles set role='admin' where id=(select id from auth.users where email='you@example.com');`
8. **Flow**: sign up (everyone starts as a customer) → apply as owner → admin approves → owner accepts orders, assigns a rider and shares the link → rider opens it on their phone, no login.
9. **Phone verification**: the app uses Supabase phone OTP. Configure an SMS provider (Twilio, MessageBird, Vonage or Textlocal) under Auth → Providers → Phone, then turn on the server-side gate:
   `update app_config set require_phone_verification = true;`
   While it is `false` (default, for testing) customers can order without a verified phone. When `true`, `place_order` rejects users whose `auth.users.phone_confirmed_at` is null and the app prompts for OTP at checkout.
10. Set `APP_URL` in `env.json` to where the web build is hosted so rider links point there (defaults to the current web origin).

## Data model
`profiles` (role: customer/owner/admin; users may only edit name/phone) · `owner_applications` + private Storage bucket `owner-docs` · `stations` (lat/lng) · `categories` · `products` · `orders` (status, payment_method cod/gcash/maya, payment_status, payment_ref) · `order_items` · `order_rider_links` (secret token, owner-only) · `rider_locations` (one row per order, Realtime) · `app_config`.\nRider actions go through token-checked RPCs `rider_get_order`, `rider_update_location`, `rider_set_status`; customers cancel with `cancel_order`.
Orders are created through the `place_order` RPC so prices are taken from the DB, not the client. Sales come from `station_sales` / `station_top_products` RPCs (Asia/Manila days, delivered orders only).

## Roadmap
- GCash/Maya via PayMongo (Edge Function sets `payment_status`/`payment_ref`)
- Push notifications (FCM) for new orders/status
- Background location for riders, ETA/routing
- Multi-station owners, delivery fees & zones, ratings
- Rice/LPG catalogs (categories already seeded)
