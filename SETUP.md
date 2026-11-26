# Tutobridge: Supabase + Flutter setup

## 1. Database
Apply `supabase/migrations/20261125120000_roles_profiles_bookings.sql` (`supabase db push`, or paste it into the
SQL editor). It supersedes the earlier prototype migration `20261125000000_mera_ustaad_teachers.sql` and
`supabase/seed.sql`; delete those two if you never applied them.

In the dashboard, check **Authentication > Providers > Email**. If "Confirm email" is on, new users must confirm
before they get a session (the app tells them to check their email).

## 2. Run the app
```
cd mobile
flutter create .          # adds android/ ios/ folders; keeps lib/ and pubspec.yaml
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```
Needs Flutter 3.22 or newer. Add the usual platform permissions for `image_picker` and `file_picker` (iOS
`NSPhotoLibraryUsageDescription`), and for `url_launcher` on Android 11+ add `tel` and `https` to `<queries>`.

## 3. Try the whole flow
1. Register as a teacher in the app and finish the 4-step wizard.
2. Verify that teacher (admins are made in SQL, never from the app):
   ```sql
   update public.profiles set role = 'admin' where id = '<your admin user uuid>';   -- once
   update public.teacher_profiles set verification_status = 'verified', is_star_teacher = true
     where id = '<teacher uuid>';                                                     -- SQL editor or an admin
   ```
3. Sign up as a parent on a second device or emulator. The teacher appears on the board. Send a request.
4. It appears live on the teacher's dashboard. Accept it to reveal the parent's phone number.

## Notes
- `profiles.phone_number` is not selectable from the client. Read your own profile with `rpc('get_my_profile')`;
  select explicit columns when reading other profiles (`select()` with no columns is refused).
- Teachers cannot change `verification_status`, `is_star_teacher`, `rating_avg` or `reviews_count`.
- Storage paths start with the user id: `avatars/<uid>/avatar`, `teacher_documents/<uid>/cnic.jpg`.

## Teacher portraits and banner
- `lib/core/portrait.dart`: `TeacherPortrait` (image with initials placeholder, fade-in, error fallback), `TeacherAvatar`,
  `PortraitCard` (grids, nearby and centre listings), `PortraitPin` (map previews), `TeacherProfileHeader`.
- `lib/core/teacher_banner.dart`: `TeacherBannerWidget`, already placed above the search bar on the parent home.
- The existing `Avatar` widget now uses `TeacherAvatar`, so the dashboard and onboarding get the same loading behaviour.
- Add five portraits as `mobile/assets/teachers/teacher_1.jpg` to `teacher_5.jpg` (any generator you hold the rights to).
  Until then the banner shows initials. Real teachers' uploaded photos are used first.
- Use bundled AI portraits only for the banner or marketing, labelled as illustrative. Do not show one as a specific
  teacher's photo: parents would be misled about who is coming to their home.

## Addresses, location and fees (migration 20261126080000)
Apply `supabase/migrations/20261126080000_location_and_rates.sql` after the first migration.
- Sign-up (parent and teacher) now asks for an address and a current location (label plus optional GPS). Both go in the
  sign-up metadata and the `handle_new_user` trigger saves them to `profiles` (`address`, `current_location_label`,
  `current_lat`, `current_lng`). A teacher's "current address" is the same `address` column.
- Address and coordinates are not readable by other users. A teacher sees a parent's address and location only after
  accepting that parent's request (`teacher_bookings()`).
- Hourly rates are gone. Teachers set `rate_type` (`per_day` or `per_month`) and `rate_amount` for home tuition, plus an
  optional `current_salary`.
- `LocationField(requireCoordinates: true)` makes GPS mandatory instead of optional.
- Permissions for "Use Current Location":
  - Android: add `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` to `AndroidManifest.xml`.
  - iOS: add `NSLocationWhenInUseUsageDescription` to `Info.plist`.
  - Web: the browser asks; the label then shows coordinates because address lookup is not available on web.

## Home navigation, chat and account (migration 20261126100000)
Apply `supabase/migrations/20261126100000_chat_addresses_subscriptions.sql` after the two earlier ones. It adds
`conversations`, `messages` (realtime), `saved_addresses`, `subscriptions` and four functions:
`start_conversation`, `my_conversations`, `use_saved_address`, `nearby_teacher_distances`.

- Parent home: Search view plus a bottom bar (Search, Account). Account opens the side drawer with Chats, Address,
  Subscription, General (Help Center) and Terms and Policies. Teachers get the same drawer from the account icon on
  their dashboard.
- Connect creates (or reopens) a conversation with that teacher and opens the chat. Messages arrive live.
- Teachers are sorted by approximate distance (rounded to 0.5 km by the database) once the parent has a saved location.
- With no verified teachers, three clearly labelled sample profiles appear (`lib/data/mock_teachers.dart`). They cannot
  be contacted. Delete that file's use in `search_view.dart` when you no longer want them.
- Plans, prices and features are placeholders in `lib/core/plans.dart`. No payment provider is connected, so a paid plan
  is recorded as a request (`pending_payment`); an admin activates it in SQL:
  `update public.subscriptions set status = 'active' where user_id = '<uuid>';`
- Terms and Privacy text is a starting draft in `lib/account/terms_screen.dart`. Have it reviewed and set a real
  support email (`kSupportEmail`).

## Demo prototype
`prototype/index.html` is a single-file web demo of all the flows above (sign-up with address and location, per day / per
month fees, Search with Connect and chat, the Account drawer and its five screens, and the teacher wizard and
dashboard). It uses sample data only and is not connected to Supabase.

## App name
The app is called Tutobridge. After `flutter create .`, set the name shown under the app icon:
Android `android/app/src/main/AndroidManifest.xml` (`android:label`) and iOS `ios/Runner/Info.plist` (`CFBundleDisplayName`).
The package name in `pubspec.yaml` is `tutobridge`. The support email (support@tutobridge.com) in `lib/account/terms_screen.dart` is a guess at your mailbox: change it to a real one.

## Map on both home screens (migration 20261126140000)
Apply `supabase/migrations/20261126140000_map_and_requests.sql` after the three earlier ones, then run `flutter pub get`
(adds `flutter_map` and `latlong2`).

- **Parents** see verified teachers and tuition centres around them on a map at the top of Search. "Tuition centre /
  home tutor" means a teacher who offers lessons at their own place. Tap a pin to connect (chat) or post a request.
- **Teachers** see open requests from parents on a map at the top of the dashboard (verified teachers only) and can
  connect to start a chat with the parent.
- **Privacy:** pins are snapped to a ~1 km grid by the database (`map_teachers()`, `map_requests()`), requests show only
  the parent's first name, and a parent may have up to 3 open requests. Addresses and phone numbers are never returned.
- **Map tiles** come from OpenStreetMap's public tile server, fine for development. Before launch, switch to a tile
  provider with a usage plan and update the `TileLayer` in `lib/core/nearby_map.dart`.
- **Android:** make sure `android/app/src/main/AndroidManifest.xml` has `<uses-permission android:name="android.permission.INTERNET"/>`
  (needed in release builds for map tiles).

## Teaching modes, availability and expertise (migration 20261126170000)

Run `supabase/migrations/20261126170000_teaching_modes_expertise.sql` after the earlier four migrations. It adds to `teacher_profiles`:

- `teaching_modes text[]` (`online`, `home_academy`, `private_home`)
- `is_immediately_available boolean`
- `expertise_categories text[]` (early_years, primary, middle_school, high_school, higher_secondary, university_test_prep, quran_nazra, sports, aitchison_prep)

GIN indexes serve the array filters; a partial index serves the home page board. A trigger keeps the older `available_at_teacher_home` / `available_at_student_home` flags in sync, so existing booking rules and the map keep working. Bookings now accept `online`.

App: Search uses `.overlaps()` on both arrays (any selected mode or category matches). Quick category chips and the Featured Online Teachers carousel are on the Search home.
