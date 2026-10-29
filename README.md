# Refilly

Philippine marketplace for water refilling stations, built to expand to rice, LPG and other daily essentials (products are generic, grouped by `categories`).

One Flutter app with role-based screens:
- **Customer**: map of all stations (OpenStreetMap), browse products by category, cart + checkout with delivery address & map pin, Cash on Delivery (GCash/Maya hook ready), live order status and live rider tracking.
- **Rider**: assigned deliveries, start/finish delivery, broadcasts GPS to Supabase while delivering, call customer.
- **Station owner** (works great as Flutter web): station profile & map location, products/prices/availability, incoming orders with customer details, accept/reject, assign riders, rider roster, sales dashboard (today / 7 / 30 days revenue, order counts, avg order, daily chart, top products).

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
7. **Try the roles**: sign up three accounts (Customer, Rider, Station owner — role chosen on sign-up).
   - Owner: create a station (or claim a seeded one: `update stations set owner_id='<owner uuid>' where name like 'AquaPure%';`), add products.
   - Rider: sign up with a phone number; the owner adds the rider by phone in **Riders**.
   - Customer: pick a station on the map, order, then the owner accepts and assigns the rider; the rider taps **Start delivery** and the customer sees the rider move live.

## Data model
`profiles` (role: customer/rider/owner, rider's `station_id`) · `stations` (lat/lng) · `categories` · `products` · `orders` (status, payment_method cod/gcash/maya, payment_status, payment_ref) · `order_items` · `rider_locations` (Realtime).
Orders are created through the `place_order` RPC so prices are taken from the DB, not the client. Sales come from `station_sales` / `station_top_products` RPCs (Asia/Manila days, delivered orders only).

## Roadmap
- GCash/Maya via PayMongo (Edge Function sets `payment_status`/`payment_ref`)
- Push notifications (FCM) for new orders/status
- Background location for riders, ETA/routing
- Multi-station owners, delivery fees & zones, ratings
- Rice/LPG catalogs (categories already seeded)
- Role is self-selected at sign-up for the MVP — add owner/rider verification before launch
