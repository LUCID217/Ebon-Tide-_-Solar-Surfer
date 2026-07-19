# Orbit Rush 🛰️

One-tap endless orbit game. A dot orbits a ring — tap to release it in a
straight line into the next ring. Miss and the run ends. Android-first
HTML5 (canvas) wrapped in **Capacitor**, with AdMob (test IDs), UMP
consent hook, infinite levels, rebirth, streaks, unlocks, and missions.

```
orbit-rush/
├── www/index.html                  ← the entire game (inline CSS + JS)
├── package.json                    ← Capacitor + plugin dependencies
├── capacitor.config.json           ← app id/name, AdMob plugin config
├── ANDROID_MANIFEST_ADDITIONS.xml  ← manifest entries to merge (CRITICAL: AdMob App ID)
├── PRIVACY_POLICY.md               ← template for the Play Data-Safety form
└── README.md                       ← you are here
```

**Browser dev:** `npm run serve` → http://localhost:8080. All native
calls (ads, haptics, keep-awake) are feature-detected and no-op with a
console log in the browser, so the game is fully playable there — but
input, layout, and performance are tuned for a phone WebView.

---

## 0. Local browser preview

Don't rely on double-clicking `index.html`: over `file://` some browsers
restrict localStorage and script behavior, and Capacitor-related imports
can throw before the ad layer's no-op fallback gets a chance to run.
Serve it over http instead:

```bash
python3 -m http.server 8000 --directory www
```

then open http://localhost:8000. In this mode every AdMob call no-ops
and logs to the console (expected — there's no native plugin), while the
core game, unlocks, missions, rebirth, and localStorage persistence all
behave exactly as they will inside the Android WebView.

## 1. Android build — exact steps

### 1.1 Prerequisites (once)

1. Install **Node.js 20+** and **Android Studio** (Ladybug or newer).
2. In Android Studio → SDK Manager, install **Android SDK Platform 36**
   and the latest **Build-Tools** and **Platform-Tools**.
3. Make sure `JAVA_HOME` points at the JDK bundled with Android Studio
   (JDK 21) — Studio's embedded terminal has this preset.

### 1.2 Create the native project (once)

```bash
cd orbit-rush
npm install
npx cap add android          # generates android/
```

### 1.3 Apply the required native edits (once)

1. **Manifest:** merge everything in `ANDROID_MANIFEST_ADDITIONS.xml`
   into `android/app/src/main/AndroidManifest.xml`.
   ⚠️ The AdMob `APPLICATION_ID` `<meta-data>` tag is **mandatory — the
   app crashes on launch without it.**
2. **SDK levels:** in `android/variables.gradle` set
   `compileSdkVersion = 36` and `targetSdkVersion = 36`
   (Play requires target 36+ after **Aug 31 2026**).
3. **Orientation:** on `MainActivity` in the manifest add
   `android:screenOrientation="portrait"`.

### 1.4 Every build after a web change

```bash
npx cap sync android         # copies www/ + plugin config into android/
npx cap open android         # opens the project in Android Studio
```

### 1.5 Run on a device (debug)

1. Enable *Developer options → USB debugging* on the phone, plug it in.
2. In Android Studio pick the device in the toolbar → **Run ▶**.
   This installs a **debug APK** — fine for local testing only.

### 1.6 Release build — signed AAB (what Play requires)

1. **Create a keystore (once, keep it forever — losing it means you can
   never update the app):**
   Android Studio → *Build → Generate Signed App Bundle / APK →
   Android App Bundle → Create new…* → fill in path, passwords, alias,
   25+ year validity. Store the keystore **outside** the repo.
2. *Build → Generate Signed App Bundle / APK* → **Android App Bundle**
   → select your keystore → build variant **release** → *Create*.
3. Output: `android/app/release/app-release.aab` — upload this to Play
   Console. (**AAB for Play, APK only for sideload testing.**)
4. Before uploading, in `www/index.html` set the four ad IDs in the
   CONFIG block to your real AdMob IDs, update the App ID in
   `capacitor.config.json` **and** the manifest, then re-run
   `npx cap sync android` and rebuild.
5. Recommended track order: Internal testing → Closed → Production.

### 1.7 Command-line alternative (CI)

```bash
cd android && ./gradlew bundleRelease   # unsigned unless signingConfig is set
```
Configure signing via `keystore.properties` + `signingConfigs` in
`android/app/build.gradle` (standard Android docs pattern). Never commit
the keystore or its passwords.

---

## 2. AdMob — going live checklist

- [ ] Create the app + 3 ad units (banner / interstitial / rewarded) in
      the AdMob console.
- [ ] Replace the four IDs in the `CONFIG` block at the top of
      `www/index.html` (each is marked `// TODO: replace before release`).
- [ ] Replace the App ID in `capacitor.config.json` → `plugins.AdMob.appId`.
- [ ] Replace the App ID in the manifest `<meta-data>` tag.
- [ ] Set `ADS_TESTING_MODE: false` in the CONFIG block.
- [ ] Set up the UMP consent message in AdMob console → Privacy & messaging
      (the in-app flow is already wired).
- [ ] Host `PRIVACY_POLICY.md` publicly and link it in Play Console; fill
      the Data Safety form to match (see table inside the policy).
- [ ] **Billing:** create in-app products in Play Console → Monetize →
      In-app products matching the `IAP_*` IDs in the CONFIG block
      (4 consumable coin packs + non-consumable `orbit_rush_remove_ads`),
      then replace the placeholder IDs. Plugin: `@capgo/native-purchases`
      (pinned 7.19.3, Capacitor-7 line). Verify with License-testing
      accounts (Play Console → Settings → License testing) — including
      the Restore-purchases path after a reinstall.

## 3. Play Store asset checklist

- [ ] **App icon:** 512×512 PNG, 32-bit, ≤1 MB (Play Console) + adaptive
      icon in `android/app/src/main/res/mipmap-*` (foreground/background layers).
- [ ] **Feature graphic:** 1024×500 PNG/JPG, no transparency.
- [ ] **Phone screenshots:** minimum 2, ideally 4–8, 16:9 or 9:16,
      1080×1920 recommended (grab via Android Studio's device screenshot
      button during a run, a combo, and a game-over screen).
- [ ] Short description (≤80 chars) + full description (≤4000 chars).
- [ ] Content rating questionnaire, ads declaration = **Yes, contains ads**.

## 4. Tuning guide

Every knob lives in the single `CONFIG` block at the top of
`www/index.html`. The six most worth adjusting for addictiveness:

| Constant | Default | Effect / how to tune |
|---|---|---|
| `ORBIT_SPEED_BASE` / `ORBIT_SPEED_GROWTH` | 2.0 / 0.045 | Base rad/s and per-ring growth. This IS the difficulty curve. Raise growth → runs end sooner, sessions feel spikier; lower → longer flow-state runs. Tune so an average first session dies at score 5–10. |
| `TARGET_R_MIN` | 30 | Floor for target shrink (the chaos clamp). Smaller → late game demands real precision; too small feels unfair on 5" screens — never go below ~24 CSS px. |
| `PERFECT_FRACTION` | 0.38 | How central a hit must be to count as PERFECT. Lower → combos rarer and more prized; higher → constant dopamine. 0.3–0.45 is the sweet band. |
| `FLIP_CHANCE_MAX` | 0.35 | Cap on random rotation-flip probability. The "gotcha" knob — this creates the misses that feel like *your* fault. Above ~0.45 it reads as random cruelty. |
| `BASE_XP` / `XP_LEVEL_EXPONENT` | 90 / 1.5 | XP needed = `BASE_XP · level^1.5`. Lower BASE_XP → faster early levels (better D1 retention); exponent controls the long-tail grind. 1.4–1.6 keeps rebirth attractive without stalling. |
| `NEAR_MISS_SHOW_PX` | 30 | Show "missed by Npx" up to this margin. The single cheapest "one more run" trigger — generous values (25–40) make most deaths feel near. |

And the two for **ad-revenue vs retention balance**:

| Constant | Default | Trade-off |
|---|---|---|
| `ADS_INTERSTITIAL_EVERY_N_DEATHS` | 3 | Interstitial frequency. 2 ≈ +40–50% impressions but measurably worse D1/D7 retention; 4–5 is gentle. Also respects `ADS_INTERSTITIAL_MIN_INTERVAL_S` so rapid deaths don't chain-fire ads. |
| `REWARDED_DOUBLE_XP_MULT` | 2 | Payout of the "double XP" rewarded ad. Rewarded ads are retention-*positive* when the payout is worth 30s of attention — raise this (2.5–3×) before ever raising interstitial frequency. |

Tuning workflow: `npm run serve`, play in Chrome device-mode, edit
CONFIG, refresh — then verify feel on a real phone (`npx cap sync` +
Run), because touch latency and screen size change everything.
