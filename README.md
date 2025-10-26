# dPOS

dPOS is a modern, offline-friendly Point of Sale system for restaurants.

It’s built for multi-branch / multi-tenant restaurant operators and gives you:
- Fast in-person billing
- Kitchen ticket routing (KOT)
- GST invoices
- Cash drawer management
- Shift/audit tracking
- Basic inventory & recipe costing
- Easy Android tablet app + Windows desktop app

This repo contains:
- **Backend API** (FastAPI + SQLAlchemy/Postgres-style models)
- **Frontend app** (Flutter)
- **Distributable builds** for Android (`.apk`) and Windows (`.exe` inside a zip)


---

## ✨ Core Features

### 1. Multi-tenant isolation
- Every restaurant (tenant) only sees its own data.
- A tenant can have multiple branches.
- All sensitive tables include `tenant_id` and sometimes `branch_id` so data never leaks across restaurants.

### 2. POS / Order flow
- Open order (DINE_IN / TAKEAWAY / DELIVERY / ONLINE)
- Add items & variants
- Add modifiers (like "extra cheese", "no onion")
- Track pax / table
- Update status: `OPEN → KITCHEN → READY → SERVED → CLOSED`  
- Record payments (cash, card, UPI, wallet, coupon)
- Generate GST invoice and print

### 3. Kitchen tickets (KOT)
- Send items to specific kitchen stations (“Indian”, “Chinese”, etc.)
- Track ticket status: `NEW → IN_PROGRESS → READY → DONE`
- Reprint / cancel KOT with reason logging

### 4. Printing & cash drawer
- Support for **billing printer** and **kitchen printer**
- Cash drawer pop via billing printer
- Per-branch printer config

### 5. Branch & restaurant settings
- Branch info: GSTIN, FSSAI, address, state code (for tax rules)
- Restaurant display name, invoice footer, logo
- Service charge / packing charge config
- GST inclusive vs exclusive

### 6. Shifts & cash control
- Open / close cashier shift per branch
- Track cash float, pay-ins, pay-outs
- Record expected vs actual cash on close

### 7. Inventory (basic)
- Ingredients with unit of measure
- Recipe BOM per menu item
- Purchase entries and stock movements (purchase / sale / wastage / adjust)
- Low stock report
- Daily stock snapshot

### 8. Reports
- Daily sales snapshot per branch/channel/provider
- Tax breakdown (CGST / SGST / IGST)
- Discounts, net, gross

### 9. Users / Roles / Permissions
- Users belong to a tenant
- Role-based access control (e.g. `ADMIN`, `CASHIER`, etc.)
- Permissions like `DISCOUNT`, `VOID`, `REPRINT`, `SETTINGS_EDIT`, `MANAGER_APPROVE`
- `/auth/me` returns user profile, tenant_id, and a default branch_id, plus granted permissions

### 10. Offline-ish POS flow (device id based)
- Orders carry `source_device_id`
- There's a sync subsystem (`sync_event`, `sync_checkpoint`) so devices can push/pull changes

---

## 🏗 Tech Stack

**Backend**
- FastAPI (Python)
- SQLAlchemy ORM
- Pydantic schemas
- Auth: custom JWT token (`/auth/login` → `/auth/me`)
- RBAC via join tables (`user_role`, `role_permission`)
- Models encode multi-tenancy explicitly using `tenant_id`, `branch_id`

**Frontend**
- Flutter
- Riverpod for state
- Dio + `http` for API calls
- Runs on:
  - Android tablets / phones
  - Windows desktops (Flutter Windows runner)

**Printing / POS features**
- Talks to local printers via configured URLs (e.g. `http://192.168.x.x:9100/agent`)
- Can open cash drawer using printer escape codes

---

## 📱 App Screens / Flows (high level)

- **Login**  
  Mobile + password _or_ mobile + PIN.

- **Main POS screen**  
  - Pick table / pax (for dine-in)
  - Add menu items (with variants + modifiers)
  - View running bill / tax / total
  - Send to kitchen, print bill, take payment, close order

- **Kitchen View / KOT**  
  - See pending tickets per station
  - Mark ticket as READY / DONE
  - Reprint / cancel ticket

- **Settings**
  - Restaurant profile
  - Printers & kitchen stations
  - Charges (service/packing)
  - GST mode (inclusive vs exclusive)
  - Logo upload for invoice header

- **Reports**
  - Daily sales summary
  - Low stock

---

## 🔐 Auth model

### `/auth/login`
- You send `mobile` + either `password` or `pin`.
- Returns `access_token` (JWT).

### `/auth/me`
Returns:
```json
{
  "id": "user-id",
  "tenant_id": "tenant-id",
  "branch_id": "branch-id",
  "name": "Admin",
  "mobile": "9999999999",
  "email": "admin@example.com",
  "active": true,
  "roles": ["ADMIN"],
  "permissions": [
    "DISCOUNT",
    "VOID",
    "REPRINT",
    "SETTINGS_EDIT",
    "MANAGER_APPROVE"
  ]
}
```

The frontend uses:

* `tenant_id` and `branch_id` for all further API calls (so you only ever fetch/create data for *your* restaurant/branch).
* `permissions` to unlock/lock UI actions (like giving discount, reprinting bills, etc).

---

## 🧱 Project Layout (simplified)

```text
root/
 ├─ backend/
 │   ├─ app/
 │   │   ├─ models/core.py        # SQLAlchemy models (Tenant, Branch, User, Menu, Orders...)
 │   │   ├─ deps.py               # auth deps (require_auth)
 │   │   ├─ routers/              # FastAPI routers (/auth, /menu, /orders, etc)
 │   │   ├─ util/security.py      # password hashing, JWT issue/verify
 │   │   └─ db.py                 # SessionLocal / Base
 │   └─ main.py                   # FastAPI app startup
 │
 ├─ waah_frontend/ (Flutter app, renamed to dPOS)
 │   ├─ lib/
 │   │   ├─ data/
 │   │   │   ├─ api_client.dart   # all HTTP calls
 │   │   │   └─ models.dart       # shared models/enums
 │   │   ├─ ui/                   # screens/widgets
 │   │   └─ main.dart
 │   ├─ android/
 │   ├─ windows/
 │   └─ pubspec.yaml
 │
 └─ README.md                     # (this file)
```

*If you cloned this and still see `waah_frontend/`, we're in the process of renaming to `dPOS`.*

---

## ▶️ Running Backend (dev)

1. Create and activate a Python venv.
2. Install deps.
3. Run FastAPI.

Example:

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You’ll need a database (typically Postgres in real deployment).
During dev you can use SQLite just to get going, but production should be Postgres/MySQL.

There is also an `/admin/dev-bootstrap` route that:

* creates a demo tenant
* creates a branch
* creates an admin user with known password/pin
* seeds printers/stations/roles/permissions

That’s meant for local/dev only.

---

## ▶️ Running Frontend (dev)

```bash
cd dPOS   # (or waah_frontend if not renamed yet)

flutter pub get
flutter run -d windows   # for Windows desktop
flutter run -d chrome    # if you added web
flutter run -d <android-device-id>  # for Android
```

Make sure the app knows the backend base URL (your API host / LAN IP).
The `ApiClient` in `lib/data/api_client.dart` is initialized with `baseUrl`.

---

## 📦 Building Release Artifacts

### Android (signed APK)

1. Generate `release.keystore` using `keytool`.
2. Add signing info in `android/app/build.gradle.kts` under `buildTypes.release`:

   ```kotlin
   signingConfig = signingConfigs.create("release") {
       storeFile = file("release.keystore")
       storePassword = "your-keystore-password"
       keyAlias = "upload"
       keyPassword = "your-keystore-password"
   }
   ```
3. Build:

   ```powershell
   flutter build apk --release
   ```
4. Output:
   `build/app/outputs/flutter-apk/app-release.apk`

That APK is what you distribute/install on Android.

> Keep `release.keystore` + the passwords SAFE.
> You need the same key to publish updates in the future.

---

### Windows (.exe)

1. Build:

   ```powershell
   flutter build windows --release
   ```
2. Go to:
   `build/windows/runner/Release/`
3. Zip the entire contents (including all `.dll`s), e.g.:
   `dPOS-windows-x64.zip`

Windows users can unzip and run `dPOS.exe`.
Because the exe is not code-signed yet, Windows SmartScreen may say “unrecognized app”. They can click “More info → Run anyway”.

---

## 🚀 Distributing via GitHub Releases

We publish official builds as GitHub Releases:

* Tag: `v0.1.0`, `v0.2.0`, etc.
* Assets:

  * `dPOS-v0.1.0-android.apk`
  * `dPOS-v0.1.0-windows-x64.zip`

In GitHub:

* Go to **Releases → Draft a new release**
* Create a new tag
* Add release notes
* Upload both binaries
* Publish

Users then download from the Releases tab.

---

## 🔮 Roadmap / Next steps

* Better tenant isolation enforcement at API layer (every query AND every create/update).
* Role-based UI: hide buttons if user lacks permission.
* More polished reports and exports.
* Online provider integration (Swiggy / Zomato bridge).
* Automatic backup upload (S3 / GDrive) using `backup_config`.

---

## ⚖️ License

This project is currently not licensed for public/commercial reuse.
All rights reserved by the author(s).
(If you intend to fork / deploy commercially, please contact the owner.)

---

## 🙌 Credits

* Flutter for multi-platform client
* FastAPI + SQLAlchemy for a clean, testable backend
* Everyone who tested bills in real restaurants and yelled at us about printer configs

dPOS is aiming to be “restaurant-first, not accounting-first”: fast billing, fast KOT, and very little nonsense.
::contentReference[oaicite:0]{index=0}
```
❤️Moti
