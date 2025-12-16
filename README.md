# App Scan QR

Scan any QR / barcode from the browser, review the payload, and ship it straight into Google Sheets through a Google Apps Script backend. Everything runs as a Flutter Progressive Web App (PWA) optimised for handheld devices.

---

## Feature Overview

- **Mobile-first camera UI** powered by [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) with lifecycle-aware pause/resume.
- **Submit flow with confirmation**: scan → preview → tap **Submit** to send to Sheets, keeping a one-line activity log.
- **Auth gate** controlled via env vars (`LOGIN_USERNAME` plus `LOGIN_PASSWORD` or `LOGIN_PASSWORD_HASH`). Sessions expire every 24 h and are stored locally via `shared_preferences`.
- **Env-configured Apps Script URL** (`APPS_SCRIPT_URL`). No hardcoded endpoints—safe for open-source deployments.
- **Optimised PWA metadata**: manifest, icons, Apple touch icon, and theme colours ready for “Add to Home Screen”.

---

## What You Need Before Running

| Item | Notes |
| --- | --- |
| Flutter SDK | v3.22.x or newer with web support enabled (`flutter config --enable-web`). |
| Google Sheet | Stores the scan results. The first column receives the scanned value. |
| Google Apps Script | Acts as the API layer. Must be deployed as a Web App with *Execute as Me* and *Who has access: Anyone*. |
| Login credentials | Provide `LOGIN_USERNAME` and either `LOGIN_PASSWORD` (plain) **or** `LOGIN_PASSWORD_HASH` (SHA-256 hex). |

---

## Configure Google Apps Script

1. In your spreadsheet, choose **Extensions ▸ Apps Script**.
2. Paste the contents of `code.gs` (or use the snippet below) and update `SHEET_ID` / `SHEET_NAME`.
3. Deploy: **Deploy ▸ Manage deployments ▸ New deployment ▸ Web app**.
   - **Execute as:** *Me*
   - **Who has access:** *Anyone*
4. Copy the Web App URL (`https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec`). This becomes the `APPS_SCRIPT_URL`.

```javascript
const SHEET_ID = 'YOUR_SPREADSHEET_ID';
const SHEET_NAME = 'Sheet1';

function doPost(e) {
  const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
  if (!sheet) throw new Error(`Sheet "${SHEET_NAME}" not found`);

  const payload = getPayload_(e);
  if (!payload.value) throw new Error('Missing "value" field');

  sheet.appendRow([payload.value]);
  return buildResponse_({
    status: 'success',
    received: payload,
    storedAt: new Date().toISOString(),
  });
}

function getPayload_(e) {
  if (e?.parameter && Object.keys(e.parameter).length) return e.parameter;
  if (e?.postData?.contents) return JSON.parse(e.postData.contents);
  return {};
}

function buildResponse_(body, statusCode) {
  const output = ContentService.createTextOutput(JSON.stringify(body))
    .setMimeType(ContentService.MimeType.JSON)
    .setHeader('Access-Control-Allow-Origin', '*')
    .setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept')
    .setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (statusCode) output.setResponseCode(statusCode);
  return output;
}
```

> Tip: Run `curl -X POST "https://script.google.com/macros/s/<ID>/exec" -d "value=HELLO"` to make sure the script appends a row before moving on.

---

## Local Development

Always provide the Apps Script endpoint using `--dart-define`:

```bash
flutter run -d chrome \
  --dart-define=APPS_SCRIPT_URL=https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec \
  --dart-define=LOGIN_USERNAME=<YOUR_USERNAME> \
  --dart-define=LOGIN_PASSWORD_HASH=<SHA256_HEX>
```

To produce a release bundle:

```bash
flutter build web \
  --dart-define=APPS_SCRIPT_URL=https://script.google.com/macros/s/<DEPLOYMENT_ID>/exec \
  --dart-define=LOGIN_USERNAME=<YOUR_USERNAME> \
  --dart-define=LOGIN_PASSWORD_HASH=<SHA256_HEX>
```

The default constant `kAppsScriptUrl` is intentionally empty—without the `--dart-define` the app refuses to send data.

### Generating a SHA-256 password hash

If you prefer not to store plaintext passwords, create a hash once and use `LOGIN_PASSWORD_HASH`:

```bash
echo -n 'your-password' | shasum -a 256 | awk '{print $1}'
```

Copy the resulting hex string into the env variable. The app will hash user input before comparing.

---

## How the UI Works

1. User logs in (session cached for 24 h).
2. Camera opens instantly; when a QR/barcode is detected the value is previewed and the **Submit** button is enabled.
3. Press **Submit** → request goes to Apps Script. Errors such as CORS restrictions are caught and explained in the inline log.
4. Camera keeps running so accidental scans can be overwritten immediately.

---

## Icons & Branding

All icons (manifest, favicon, Apple touch) point to a single asset: `web/icons/app_icon.png`.

1. Replace that file with your PNG (square, ≥512×512 recommended).
2. Rebuild or redeploy. No extra scripts or manifest edits needed.

---

## Deploying to Vercel

1. Push the repo to GitHub (or connect via Vercel’s import).
2. In **Build & Output Settings**:
   - **Build Command:** `bash scripts/ci_build.sh`
   - **Output Directory:** `build/web`
   - **Install Command:** disable (the build script handles Flutter download + `pub get`)
3. In **Environment Variables**, add at minimum:
   - `APPS_SCRIPT_URL`
   - `LOGIN_USERNAME`
   - Either `LOGIN_PASSWORD` **or** `LOGIN_PASSWORD_HASH`
4. (Optional) Set `FLUTTER_VERSION=3.32.1` inside the build command if Vercel should use a specific SDK (`FLUTTER_VERSION=3.32.1 bash scripts/ci_build.sh`).

`scripts/ci_build.sh` downloads Flutter for Linux inside the build container, marks the repo safe (`git config --global --add safe.directory`), runs `flutter pub get`, and builds the web bundle with the supplied `APPS_SCRIPT_URL`.

Once deployed you can attach a custom domain via **Settings ▸ Domains** or keep Vercel’s default `<project>.vercel.app`.

---

## Troubleshooting

- **“Load failed / Failed to fetch” but row still appears:** The browser blocked reading the response (CORS), but the POST succeeded. The app surfaces a log entry explaining this and clears the form.
- **Sheet not receiving data:** Re-check the Apps Script deployment URL (`Current web app URL`). Redeploy after editing `code.gs`.
- **Camera not starting:** Safari/iOS sometimes delays camera permissions on PWA installs. Open the site in Safari first, accept permissions, then “Add to Home Screen”.
- **Need more columns:** Expand `sheet.appendRow([payload.value]);` with extra fields and send them from `_sendToSpreadsheet` in `lib/main.dart`.

---

## Next Steps

- Automate row validation (e.g., restrict prefixes or check duplicates in Apps Script).
- Add push notifications or offline queueing by enhancing the service worker in `web/`.
- Integrate additional storage (Supabase/Firebase) by layering new HTTP calls inside `_sendToSpreadsheet`.

Read through this README once and you’ll have everything required to configure the backend, run locally, and deploy the Flutter PWA in production. Happy scanning!
