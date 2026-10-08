# Building and releasing Pebble Routines

This guide is for the app owner. You don't need a Mac or any coding. Everything happens in a web browser, and a phone browser works too. If a page looks cramped on your phone, open the browser menu and tick **Desktop site**.

There are two robots:

| Robot | What it does | When it runs | Cost |
|---|---|---|---|
| **GitHub CI** (`.github/workflows/ci.yml`) | Checks the code: analysis and tests, plus a test Android build when started by hand. Shows a green tick or a red cross. | Automatically, on every pull request. | Free (see limits below) |
| **Codemagic** (`codemagic.yaml`) | Makes the real, signed builds: iPhone to TestFlight, Android `.aab` for Google Play. | Only when you press **Start new build**. | Free tier (see limits below) |

---

## Free-tier limits (checked October 2026)

**Codemagic** (personal account, *not* a Team):
- **500 free build minutes a month**, on the macOS M2 machine only. They reset on the 1st of each month.
- Linux and Windows machines have **no** free minutes. That's why the Android build also runs on the Mac.
- Teams get no free minutes. Stay on your **personal account** and don't create a Team.
- Each build can run for at most 120 minutes. Ours stop themselves after 60.
- Rough cost: an iPhone build takes about 20–30 minutes, and an Android build about 10–15. So 500 minutes is around 12–15 iPhone builds a month, or more if you mix in Android builds.
- If you don't add a payment card, Codemagic stops building when the minutes run out. It doesn't charge you.

**GitHub Actions** (the CI checks):
- Public repositories are free with no limit.
- Private repositories get **2,000 Linux minutes a month** on the Free plan. The test Android build is the slowest check, so it only runs when started by hand (Actions tab → **CI** → **Run workflow**).
- With no payment method, GitHub stops running checks when the minutes run out. It doesn't charge you.

---

## Before you start

You need these first. They are in `IOS_SETUP_CHECKLIST.md`.

1. The Apple Developer Program membership is active.
2. The App ID `com.vix.pebbleroutines` is registered with **Sign in with Apple** ticked.
3. The app record "Pebble Routines" exists in App Store Connect.
4. RevenueCat has the App Store app, so you have an `appl_…` key.

For Android you need the **upload keystore** file (`upload-keystore.jks`) and its passwords. This is the key that signed build 28. See step 5 if you no longer have it.

---

## Step 1: Connect GitHub to Codemagic

1. Go to **codemagic.io** and choose **Sign up** → **Sign up with GitHub**. Allow access.
2. When asked, pick your **personal account**. Don't create a Team.
3. Click **Add application**.
4. Choose **GitHub** as the Git provider. If the repository isn't listed, click the link to **configure the GitHub App** and give it access to the Pebble repository.
5. Select the Pebble repository. For the project type choose **Flutter App**, then **Finish: Add application**.
6. Codemagic finds `codemagic.yaml` in the repository by itself. You'll see two workflows: **iOS - TestFlight** and **Android - signed App Bundle**.

## Step 2: Create the App Store Connect API key, then add it to Codemagic

This key lets Codemagic sign the app and upload it to TestFlight for you.

**In App Store Connect** (appstoreconnect.apple.com):
1. Go to **Users and Access** → **Integrations** tab → **App Store Connect API**.
   - The first time, Apple may show **Request Access**. Click it and accept. Only the Account Holder can do this.
2. Under **Team Keys**, click **+** (Generate API Key).
3. Name: `Codemagic`. Access: **App Manager**. Click **Generate**.
4. Click **Download API Key**. You get a file ending in `.p8`. **You can download it only once**, so keep it safe (for example in your Google Drive).
5. Write down two values from this page:
   - the **Issuer ID**, shown above the table
   - the **Key ID** of the new key

**In Codemagic:**
1. Click your account picture → **Team settings**. On a personal account this page is still called "Team settings".
2. Open **Team integrations** → **Developer Portal** → **Connect** (or **Manage keys**).
3. Click **Add key** and fill in:
   - **App Store Connect API key name:** `pebble_asc_key`. It must be exactly this, because `codemagic.yaml` uses this name.
   - **Issuer ID** and **Key ID** from above.
   - **API key:** upload the `.p8` file.
4. Click **Save**.

That's all iOS signing needs. On the first iPhone build, Codemagic creates the Apple distribution certificate and the provisioning profile on its own.

## Step 3: Find the app's Apple ID number

1. In App Store Connect, go to **Apps** → **Pebble Routines** → **General** → **App Information**.
2. Copy the number labelled **Apple ID** (about 10 digits). This is not your email.
3. You'll paste it as `APP_STORE_APPLE_ID` in the next step. Codemagic uses it to make each TestFlight build number one higher than the last.

## Step 4: Create the `pebble_production` variable group

These are the production settings that get baked into the app. You add them one at a time.

1. In Codemagic, open **Apps** → **Pebble Routines** → **Environment variables** tab.
2. For each row in the table below:
   - **Variable name:** type it exactly as shown, in capitals with underscores.
   - **Variable value:** paste the value with no spaces before or after.
   - **Select group:** type `pebble_production`. The first time, choose **Create "pebble_production"**. After that, pick it from the list.
   - **Secret:** tick it. You can tick it for every variable; the build works the same. Secret values are hidden in logs, and you can't view them again later. To change one, delete it and add it again.
   - Click **Add**.

| Variable name | Needed for | Where to find the value |
|---|---|---|
| `SUPABASE_URL` | both, **required** | Supabase dashboard → the **production** project → **Project Settings** → **Data API** → Project URL. It looks like `https://xxxx.supabase.co`. It must **not** be the staging project `lxvrvrrxdjbrjwsxzppl`; the build refuses that one. |
| `SUPABASE_ANON_KEY` | both, **required** | Same Supabase project → **Project Settings** → **API Keys** → the **anon / public** key (a long `eyJ…` text). Never use the `service_role` key. |
| `SUPABASE_GOOGLE_WEB_CLIENT_ID` | Android **required**, iOS recommended | Google Cloud Console → **APIs & Services** → **Credentials** → OAuth 2.0 Client IDs → the **Web client** → Client ID (ends in `.apps.googleusercontent.com`). This is the same value the old `PEBBLE_PROD_GOOGLE_WEB_CLIENT_ID` setting used. |
| `SUPABASE_GOOGLE_IOS_CLIENT_ID` | iOS, optional | The **iOS** OAuth client from `IOS_SETUP_CHECKLIST.md` step 5. Until it's set, the Google button is hidden on iPhone, and Apple and email sign-in still work. |
| `GOOGLE_IOS_REVERSED_CLIENT_ID` | iOS, optional | Usually leave this out. The build works it out from the iOS client ID. Add it only if Google shows a different "iOS URL scheme" (`com.googleusercontent.apps.…`). |
| `REVENUECAT_IOS_API_KEY` | iOS **required** | RevenueCat → your project → **Project settings** → **API keys** → the **App Store** app's public SDK key. It starts with `appl_`. |
| `REVENUECAT_ANDROID_API_KEY` | Android **required** | Same page → the **Play Store** app's public SDK key. It starts with `goog_`. Never use a secret key (`sk_…`). |
| `APP_STORE_APPLE_ID` | iOS, recommended | The number from step 3. It isn't secret. |
| `SENTRY_DSN` | optional | Sentry → your project → **Settings** → **Client Keys (DSN)**. If you leave it out, crash reporting is off. |
| `PEBBLE_ACCOUNT_DELETION_URL` | optional | The public web page where people can request account deletion, if you have one. |
| `REVENUECAT_ENTITLEMENT_ID` | optional | Leave this out. It defaults to `personal_premium`. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS` | optional | Only for automatic Google Play upload. See the optional section at the end. |

You don't set `APP_ENV`. The workflows always build with `APP_ENV=production`.

## Step 5: Upload the Android upload keystore

1. In Codemagic, go to **Team settings** → **codemagic.yaml settings** → **Code signing identities** → **Android keystores** tab.
2. Upload `upload-keystore.jks` and fill in:
   - **Reference name:** `pebble_upload_keystore`. It must be exactly this.
   - **Keystore password**
   - **Key alias**: usually `upload`.
   - **Key password**: often the same as the keystore password.
3. Click **Add keystore**.

**If you've lost the original keystore** (build 28 was made on a machine that no longer exists):
- Google Play can accept a new upload key. Go to Play Console → **Pebble Routines** → **Test and release** → **App integrity** → **App signing** → **Request upload key reset**.
- Ask Claude in a session to create a new keystore and the `.pem` certificate that Google asks for.
- Keep two backups of the new `.jks` file and its passwords, for example in Google Drive and in a password manager.
- Google usually takes a day or two to approve the reset.

## Step 6: Put your email address in `codemagic.yaml`

Codemagic emails you when a build passes or fails.

1. On github.com, open the repository → `codemagic.yaml` → the **pencil** (Edit) icon.
2. Replace both `you@example.com` lines with your email address.
3. Click **Commit changes…** → **Commit changes**.

## Step 7: Start a build

1. In Codemagic, open **Apps** → **Pebble Routines** → **Start new build**.
2. **Branch:** `main`. **Workflow:** **iOS - TestFlight** or **Android - signed App Bundle**.
3. Click **Start new build**.
4. You can watch each step tick off.
   - If a step goes red, tap it to read the log.
   - The first step, **Check production settings**, stops in under a minute if a setting is missing or wrong. It tells you in plain words what to fix, for example "REVENUECAT_IOS_API_KEY must be … starting with appl_".
5. You don't type build numbers. Codemagic reads the latest number from TestFlight or Google Play and adds one, and it never goes below 32.

**iPhone:** when the build finishes, Codemagic uploads it to App Store Connect. Apple then "processes" it for about 5–30 minutes and emails you when it's ready in TestFlight.

**Android:** open the finished build → **Artifacts** → download the `.aab` file. The email has a link too. Then:
1. Play Console → **Pebble Routines** → **Test and release** → **Testing** → **Internal testing** → **Create new release**.
2. Upload the `.aab`, add release notes, **Next** → **Save and publish** (or **Start rollout**).

## Step 8: Install the iPhone build with TestFlight on a borrowed iPhone

TestFlight builds install with the **iPhone owner's own Apple ID**. You don't sign anything in on their phone.

**Option A: internal tester (fastest, no Apple review)**
1. App Store Connect → **Users and Access** → **+**. Add the iPhone owner's name and Apple ID email, with the role **Customer Support** (it can't change anything important). They accept the email invite.
2. App Store Connect → **Apps** → **Pebble Routines** → **TestFlight** → **Internal Testing** → **+** to create a group (for example "Testers"). Tick **Enable automatic distribution**, then add that person.
3. Every new build now reaches them as soon as Apple has processed it.

**Option B: external tester (no App Store Connect access)**
1. **TestFlight** → **External Testing** → **+** to create a group. Add the person's email, or switch on **Public Link**.
2. Add the build to the group and fill in the short "What to Test" note.
3. The first build goes through **Beta App Review**, which usually takes under a day. Later builds are often instant.

**On the iPhone:**
1. Install **TestFlight** from the App Store.
2. Open the invite email or the public link on that iPhone → **Accept** → **Install**.
3. Updates show up in TestFlight. Each build works for 90 days.

You don't need to answer any encryption questions on upload. The app already declares "no non-exempt encryption".

---

## Reading GitHub CI: green tick or red cross

- On github.com, open the repository. Next to the latest commit there's a small icon:
  - **green tick ✓**: all checks passed
  - **red cross ✗**: something failed
  - **yellow dot**: still running
- Tap the icon → **Details**, or open the **Actions** tab, to see which check failed:
  - **Analyze and test**: code analysis plus the automated tests.
  - **Android debug build**: makes sure the Android project still compiles. It's not a release build and uses no secrets. It only runs when started by hand (Actions tab → **CI** → **Run workflow**), so on pull requests it shows as skipped.
- On a pull request, the same checks appear at the bottom under **Checks**.
- GitHub emails whoever pushed the change when a check fails.
- **Golden tests (informational):** these compare screenshots pixel by pixel and depend on the computer they were recorded on. If they fail, that one step shows as failed inside the run, but the run itself stays green.
- If a newer change is pushed while a check is still running, the old run is cancelled to save minutes. That's normal.

A red cross in CI doesn't block Codemagic. Still, don't start a release build from a commit with a red cross.

---

## Optional: automatic upload to Google Play

When this is on, every Android build goes straight to the **internal testing** track. Codemagic also reads the true latest build number from Play.

1. **Google Cloud Console** (console.cloud.google.com):
   1. Open the project linked to Play, or create one.
   2. **APIs & Services** → **Library** → enable **Google Play Android Developer API**.
2. **IAM and Admin** → **Service accounts** → **Create service account**:
   1. Name it `codemagic`.
   2. Role: **Service Account User**.
   3. Click **Done**.
3. Open the new account → **Keys** → **Add key** → **Create new key** → **JSON** → **Create**. A `.json` file downloads. Copy the service account email address (`…@….iam.gserviceaccount.com`).
4. **Play Console** → **Users and permissions** → **Invite new users**:
   1. Paste that email.
   2. Under **App permissions**, add Pebble Routines.
   3. Tick the **Releases** permissions (release to testing tracks).
   4. Click **Invite user**.
5. **Codemagic** → Environment variables:
   1. Add `GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS` to the `pebble_production` group, ticked **Secret**.
   2. For the value, open the `.json` file and paste **all of its text**.
6. On github.com, edit `codemagic.yaml`. Near the bottom, remove the `# ` at the start of the five `google_play:` lines. Keep the indentation exactly as it is, then commit.

Google needs the app's first upload to be done by hand. That's already done, since build 28 is in Play.

---

## Troubleshooting

| You see | What to do |
|---|---|
| `SUPABASE_URL is missing from the pebble_production group` (or another variable name) | Add that variable in step 4. Check the spelling and that it's in the `pebble_production` group. |
| `… starting with appl_` / `… starting with goog_` | You pasted the wrong RevenueCat key. Use the public SDK key for that store. |
| `Android keystore not found` | Step 5. The reference name must be exactly `pebble_upload_keystore`. |
| iOS fails at **Set up code signing**, or mentions "No matching profiles" | Check the API key name is exactly `pebble_asc_key`, its access is **App Manager**, and the App ID `com.vix.pebbleroutines` exists. |
| Apple says there are too many certificates | Apple Developer → **Certificates** → revoke an old, unused **Apple Distribution** certificate, then rebuild. |
| Play Console says "version code already used" | Rebuild. If it happens again, add `GOOGLE_PLAY_SERVICE_ACCOUNT_CREDENTIALS` (optional section) so Codemagic can read Play's latest number. |
| Codemagic says you're out of minutes | Wait until the 1st of next month, or add billing in Codemagic (about $0.095 per Mac minute). |

## For whoever maintains this

- Flutter is pinned to **3.47.6** in both `ci.yml` (`FLUTTER_VERSION`) and `codemagic.yaml` (`environment.flutter`). Bump both together.
- The builds pass the same `--dart-define` values as `build_production_aab.ps1`, plus `REVENUECAT_IOS_API_KEY` and `SUPABASE_GOOGLE_IOS_CLIENT_ID` for iOS. `ios/Flutter/GoogleSignIn.xcconfig` is written at build time.
- Build number = max(latest in TestFlight or Play + 1, floor). The floor is 32 for iOS and 39 for Android. If the store can't be read, it falls back to `floor - 1 + Codemagic build counter`. Change `BUILD_NUMBER_FLOOR` in `codemagic.yaml` to raise the floor.
- The `dart format` check is off in CI because the codebase isn't fully formatted yet. Run `dart format lib test` in a dedicated change, then uncomment the step in `ci.yml`.
