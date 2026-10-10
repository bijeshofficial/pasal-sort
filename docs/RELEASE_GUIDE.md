# Pasal Sort: Release Checklist (closed testing first)

Everything needed to get **Pasal Sort: Sort & Renovate** into a Google Play
closed test, then production, then the App Store.

**How to use it:** tick an item by changing `[ ]` to `[x]`. If you're unsure
whether something is finished, leave it unticked and add `?` after the box
(`- [ ] ? AdMob payments`). Tell me when you've updated the file and I'll
pick up the next items.

- **(you)** means only you can do it: consoles, accounts, passwords, keys.
- **(Claude)** means I do it in the code or the website. Just tell me to go.
- **(check)** means it was right as of October 2026. Store rules change often,
  so confirm it in the console.

**Key IDs and links**

| What | Value |
|---|---|
| Package / bundle ID | `com.neuronnest.pasalsort` (permanent after the first upload) |
| App name | Pasal Sort: Sort & Renovate (27 of 30 characters) |
| Privacy policy | https://www.neuronnest.com/pasal-sort/privacy (to be created, section 3) |
| app-ads.txt | https://www.neuronnest.com/app-ads.txt (already live for Aksyatra; the same file covers this app) |
| AdMob publisher | `pub-7387045424284544` |
| AdMob app IDs | Android `ca-app-pub-…~…` · iOS `ca-app-pub-…~…` (fill in, section 2) |
| Rewarded ad units | Android `ca-app-pub-…/…` · iOS `ca-app-pub-…/…` (fill in, section 2) |
| Support email | info@neuronnest.com |
| Code | https://github.com/bijeshofficial/pasal-sort |

**The order that matters**

1. AdMob apps and ad units (you) → send me the IDs.
2. Privacy page plus AdMob and the release build (Claude).
3. Upload key (you) → test build on your phone (both).
4. Play Console: create the app, fill in every form, upload to **Closed testing** (you).
5. 12+ testers for 14 days → apply for production (you).

---

## 0. Decisions before you start

- [ ] **Target audience.** Recommended: **13 and over**.
  - A cartoon candy game can look like it's for children. If you include
    under-13s, the Families policy applies: child-directed ads only, no
    personalised ads, and extra review.
  - With 13+, keep the listing aimed at "puzzle fans", not kids, and don't
    use words like "kids" or "children".
  - If Google later says the app "appeals to children", tell me. I'll switch
    the ads to child-directed mode and we answer "mixed audience".
- [ ] **iOS version 1: purchases or not?** In-app purchases are mocked in the
  code. They show a "TEST PURCHASE" dialog and charge nothing. Pick one:
  - **A (simplest):** iOS 1.0 ships with ads only, like Android. I turn the
    store off on iOS too.
  - **B:** I integrate real StoreKit plus **Restore Purchases**, which Apple
    requires for the one-time Starter Pack. You create the 5 products in App
    Store Connect.
  - Android is unaffected either way (no merchant account in Nepal).

## 1. Accounts

### Google Play Console (you)
- [x] Developer account exists (same one as CallBreak Score and Aksyatra)
- [ ] Check the account's **Home** page. Personal accounts created after
  13 Nov 2023 must run a closed test with **12+ testers for 14 continuous
  days** before production **(check)**. The app's Dashboard will say so once
  the app exists.
- [ ] Contact email and phone verified, and the developer page shows
  https://www.neuronnest.com as the website (AdMob reads app-ads.txt from it)

### AdMob (you)
- [x] Account exists; payments are set up for Aksyatra and are shared
  across apps
- [ ] Payments: address, payee name, W-8BEN tax form and bank all done. This
  is the same list as in Aksyatra's guide, so do it once for both.

### Apple (later, after the Play closed test is running)
- [ ] Apple Developer Program (US$99/year)
- [ ] App Store Connect → Business: Free Apps agreement active. **Paid Apps
  Agreement** with banking and tax too, only if you chose option B in
  section 0.

---

## 2. AdMob: create the apps and ad units (you)

Do this now. The apps don't need to be on a store yet.

**Android app**
- [ ] AdMob → **Apps → Add app** → Platform **Android**
- [ ] "Is the app listed on a supported app store?" → **No** (link it after
  launch, section 9)
- [ ] App name: `Pasal Sort` → Add app
- [ ] Copy the **App ID** (`ca-app-pub-7387045424284544~XXXXXXXXXX`, with a `~`)
- [ ] **Ad units → Add ad unit → Rewarded**
  - Name: `Rewarded main`
  - Reward: amount `1`, item `reward` (the game decides the real reward:
    coins, a life, +5 moves…)
  - Leave server-side verification off
- [ ] Copy the **Ad unit ID** (`ca-app-pub-7387045424284544/XXXXXXXXXX`, with a `/`)

**iOS app:** the same steps with Platform **iOS**
- [ ] App ID copied
- [ ] Rewarded ad unit `Rewarded main` created and its ID copied

**Privacy & messaging** (AdMob left menu)
- [ ] **European regulations (GDPR):** open the existing Aksyatra message and
  add the two Pasal Sort apps (or create a new message for them). Privacy
  policy URL: https://www.neuronnest.com/pasal-sort/privacy. Publish.
- [ ] **US state regulations:** same, add the two apps, publish
- [ ] **IDFA explainer** (iOS app only): create it and publish. It shows
  before Apple's tracking prompt.

**Blocking controls** (recommended for a cosy candy game)
- [ ] Apps → each Pasal Sort app → Blocking controls → **Maximum ad content
  rating: PG**. G blocks a lot of ads and lowers earnings.
- [ ] Optional: block the sensitive categories you don't want next to the
  game, for example gambling and dating.

**Send me these four values** (paste them in chat or fill in the table at the top):
- [ ] Android App ID, Android rewarded unit ID, iOS App ID, iOS rewarded unit ID

> Never tap your own live ads. Debug builds use Google's test ads
> automatically. For testing release builds, add your phone under AdMob →
> Settings → **Test devices**.

---

## 3. Website: neuron-nest (Claude, then you deploy)

- [ ] (Claude) Privacy policy page `src/app/pasal-sort/privacy/page.js`. It
  covers: AdMob and its data, consent, the local-only save and analytics,
  no accounts, no data from children, deletion by email, contact.
- [ ] (Claude) The in-game **Privacy policy** link points to it. It's
  `example.com` right now, in `scripts/ui/settings_panel.gd`.
- [x] `public/app-ads.txt` already lists `pub-7387045424284544`. One line
  covers every app.
- [ ] (you) Deploy the site and open the privacy link on your phone to
  confirm it loads

---

## 4. Game code (Claude, once I have the AdMob IDs)

I can do everything below except the real-device test. I'll port the parts
from Aksyatra, which already work on Godot 4.7.2.

**Ads**
- [ ] AdMob plugin v5.1.0 (`addons/admob`, Poing Studios) copied in and enabled
- [ ] `data/ads.json`: app IDs, rewarded unit IDs, and Google's test units.
  Debug builds always use the test units; only release builds use the live ones.
- [ ] `AdMobProvider` behind the existing `AdManager`: Google consent form
  (UMP) at startup → SDK start → preload → show → the reward is given only
  from the "earned reward" callback
- [ ] Release safety: release builds never show the fake "REWARDED TEST AD"
  overlay. With no ad available they say "No ad right now" and give nothing.
- [ ] Settings: an **Ad privacy options** button (only where consent applies)
- [ ] Every rewarded placement still works: daily free coins, +1 life, double
  coins, +5 moves, the second chance. Interstitials stay off.

**Purchases**
- [ ] Android: the store stays hidden (already done, `store_platforms: ["iOS"]`)
- [ ] iOS: option A or B from section 0

**Build and polish**
- [ ] Android export preset: Gradle build, **AAB**, target API **36** (min 24),
  arm64 + armv7, Internet + network-state permissions
- [ ] Version `1.0.0`, code `1` (raise the code by 1 for every upload after this)
- [x] Launcher icon from your icon set (`assets/app_icon/`): 192 px legacy
  icon, plus an adaptive foreground and a soft lilac background that blends
  when the launcher wobbles the icon. Wired into the Android preset.
- [ ] `tools/build_android.sh test` (APK with test ads) and `release`
  (signed AAB), the same as Aksyatra
- [ ] Release build check: the debug menu is unreachable, no "TEST" overlays
  appear, and nothing is logged to the screen
- [ ] Optional but useful for the test: an in-game **Send feedback** button
  using the same neuronnest.com endpoint and admin page as Aksyatra. Testers'
  notes then reach you directly.

---

## 5. Upload key (you)

- [ ] Create a key just for this app (in Terminal; choose a strong password):
  ```
  keytool -genkeypair -v -keystore ~/pasal-sort-upload.keystore -alias pasalsort -keyalg RSA -keysize 2048 -validity 10000
  ```
- [ ] **Back up `~/pasal-sort-upload.keystore` and its password in two safe
  places** (a password manager plus an offline copy). Every update must be
  signed with it. It stays out of the repo.

## 6. Test on your phone (both)

- [ ] (Claude) `tools/build_android.sh test` → APK
- [ ] (you) Install it and play through:
  - [ ] First launch: loading, tutorial levels 1–3, the first renovation task
  - [ ] Rewarded ad: a Google **test** ad plays and the reward arrives.
    Closing early gives nothing.
  - [ ] Consent form: set your phone to an EU region with a VPN, or I enable
    AdMob's debug geography for one build
  - [ ] Settings → Ad privacy options reopens the form
  - [ ] The Android back button closes popups, then asks before quitting
  - [ ] Notch and gesture bar: nothing is cut off at the top or bottom
  - [ ] Kill the app mid-level → reopen → the level resumes
  - [ ] Turn on airplane mode: the game still plays and ad buttons say no ad
  - [ ] Nepali language: switch in Settings and check a few screens
- [ ] (Claude) Fix anything found, then `tools/build_android.sh release` →
  `build/android/pasal-sort.aab`

---

## 7. Google Play Console: create the app and fill in every form (you)

### 7.1 Create the app
- [ ] **Create app**: name `Pasal Sort: Sort & Renovate`, default language
  English (United States) or English (UK), **Game**, **Free**
- [ ] Accept the Developer Program Policies and US export laws declarations

### 7.2 Dashboard → "Set up your app" (Policy → App content)
Each is a short questionnaire. The closed test can't be published until
they're all done.

- [ ] **Privacy policy:** https://www.neuronnest.com/pasal-sort/privacy
- [ ] **App access:** "All functionality is available without special access"
  (no login)
- [ ] **Ads:** Yes, the app contains ads
- [ ] **Content rating** (IARC questionnaire): category **Game**
  - Violence, fear, sexuality, bad language, drugs, crude humour: **No**
  - Simulated gambling: **No**
  - Users can interact or share content: **No**. Shares location: **No**.
  - Digital purchases: **No** (none on Android). Unrestricted internet: **No**.
  - Expected result: Everyone / PEGI 3
- [ ] **Target audience and content:** 13–15, 16–17, 18+ (section 0).
  "Could the store listing unintentionally appeal to children?" Answer
  honestly. If the form then asks for more, tell me (see section 0).
- [ ] **News app:** No
- [ ] **Data safety.** The game itself sends nothing off the phone: saves and
  analytics stay on the device. Everything to declare comes from the AdMob SDK.
  Follow Google's "Google Mobile Ads SDK: data disclosure" page **(check)**:
  - Does your app collect or share user data? **Yes**
  - Encrypted in transit: **Yes**
  - Users can request deletion: **Yes**, by email to info@neuronnest.com.
    Local data is cleared with Settings → Reset progress or by uninstalling.
  - Data types, each **collected and shared** with Google AdMob, for
    **Advertising or marketing**, **Analytics** and **Fraud prevention**, and
    **not optional**:
    - Location → **Approximate location** (from the IP address)
    - App activity → **App interactions**
    - App info and performance → **Crash logs**, **Diagnostics**
    - Device or other IDs → **Device or other IDs** (advertising ID)
  - If we add the Send feedback button (section 4): App activity → Other
    user-generated content, collected, **not shared**, **optional**, for App
    functionality
- [ ] **Advertising ID:** Yes, used for **Advertising or marketing** (the
  AdMob SDK adds the `AD_ID` permission)
- [ ] **Government app, Financial features, Health:** No to all

### 7.3 Store settings and listing
- [ ] **Store settings:** category **Games → Puzzle**; tags (Puzzle, Casual,
  Sorting, Relaxing…); email info@neuronnest.com; website
  https://www.neuronnest.com
- [ ] **Main store listing** (text in Appendix A; images from
  `docs/STORE_ASSETS.md`):
  - [ ] Title, short description, full description
  - [ ] App icon 512×512 PNG: `assets/app_icon/icon_512.png`
  - [ ] Feature graphic 1024×500
  - [ ] 4–8 phone screenshots 1080×1920 (`docs/store/play/01…08`)
  - [ ] Optional: Nepali translation (Manage translations → add Nepali, paste A.3)
- [ ] **Pricing and distribution:** Free; choose countries (all, or start with
  Nepal plus your testers' countries); "Contains ads" confirmed

### 7.4 Closed testing track
- [ ] **Testing → Closed testing → Create track** (or use the default
  "Closed testing - Alpha")
- [ ] **Countries:** the same as production, or at least every country your
  testers live in
- [ ] **Testers:** a **Google Group** is easiest (for example
  pasal-sort-testers@googlegroups.com). People join the group, and adding or
  removing testers needs no new release. An email list works too.
- [ ] **Create release** → let Google manage the app signing key (Play App
  Signing, the default) → upload `pasal-sort.aab` → release name `1.0.0 (1)` →
  release notes ("First test build: please play a few levels and send
  feedback!")
- [ ] **Review release → Start rollout to Closed testing**. Then go to
  **Publishing overview → Send changes for review**. The first review usually
  takes a few hours to 3 days.
- [ ] Copy the **opt-in link** (Testers tab, "How testers join your test")

---

## 8. The 14-day closed test (you)

- [ ] **12 or more testers opted in** (aim for 15–20, since some drop out)
  - Each one opens the opt-in link **while signed in with the Gmail they joined
    with**, taps **Become a tester**, installs from Play, and **keeps it
    installed for all 14 days**
  - The counter is on the Dashboard. The 14 days restart if you drop below 12.
  - Message to send them: Appendix B
  - Aksyatra testers can join this test too. The same people can test both apps.
- [ ] Keep notes during the test: who found what, and what you changed. The
  production application asks for this.
- [ ] Push **at least one update** during the test, for example fixes from
  feedback. Raise the version code (2, 3…) and upload it to the same closed
  track. It shows Google the test was real.
- [ ] Ask testers to actually play on several days, not just install it
- [ ] After 14 days: Dashboard → **Apply for production**. It asks:
  - How you recruited testers, and how engaged they were
  - A summary of the feedback, and the changes you made because of it
  - Who the app is for, and how it's different (renovation story, Nepali
    setting, bilingual)
  - Why it's ready for production
  - Usually 1–7 days to hear back

## 9. Production and after launch

- [ ] Production release from the tested build, staged rollout **20% → 100%**
- [ ] AdMob → Apps → each app → **App settings → Link to store**. Ads serve
  at a limited rate until the app is linked and reviewed.
- [ ] AdMob shows **app-ads.txt: Verified** for the app (can take a few days)
- [ ] (you) Confirm that real ads show for other people (never tap your own)
- [ ] Watch **Android vitals** (crashes, ANRs) and reviews in the first week
- [ ] Every later update: raise `version/code` and `version/name` in
  `export_presets.cfg` (I can do this)

## 10. App Store (after Play)

- [ ] Apple items in section 1 done
- [ ] (Claude) iOS export preset: bundle ID `com.neuronnest.pasalsort`, your
  Team ID, app icon `assets/app_icon/icon_1024.png` (no transparency, ready);
  `GADApplicationIdentifier`, `NSUserTrackingUsageDescription` and
  Google's SKAdNetwork IDs in Info.plist
- [ ] (Claude) Option A or B from section 0 finished
- [ ] (you) App Store Connect → New app → bundle ID → SKU `pasalsort`
- [ ] (you) Xcode → Archive → upload → **TestFlight** on a real iPhone
  (TestFlight is Apple's closed test: up to 10,000 testers, no 14-day rule)
- [ ] App Privacy label: Identifiers (Device ID), Location (coarse), Usage
  data and Diagnostics, all linked to third-party advertising. Tracking:
  **Yes** if ads can be personalised (the IDFA prompt). Add Purchases only
  with option B.
- [ ] Age rating questionnaire: all None. With option B, answer **Yes** to
  "in-app purchases" and to **loot boxes**, because coins buy random sticker
  packs.
- [ ] Screenshots 6.9" 1320×2868 (`docs/store/appstore/`), subtitle,
  keywords, promo text (Appendix A)
- [ ] Submit for review (usually 24–48 hours)

---

## Appendix A. Store listing text (ready to paste)

Every field fits the stores' character limits.

### A.1 Short fields

| Field | Text | Limit |
|---|---|---|
| Title | Pasal Sort: Sort & Renovate | 30 |
| Play short description | Sort colourful candies into jars and renovate Hajurama's old Nepali sweet shop! | 80 |
| Apple subtitle | Candy Sort & Shop Makeover | 30 |
| Apple promotional text | Sort sweets, earn stars and bring a family sweet shop in Kathmandu back to life, one room at a time. | 170 |
| Apple keywords | `candy,jar,ball sort,color sort,water sort,puzzle,nepal,nepali,renovate,makeover,cozy,relaxing,offline` | 100 |

### A.2 Full description, English (up to 4,000 characters)

```
Pour, sort and match colourful candies until every jar holds a single sweet, then use your stars to bring Hajurama's old sweet shop back to life!

Pasal Sort is a relaxing candy sorting puzzle set in a family sweet shop (a "pasal") in Kathmandu. Tap a jar, tap another, and watch the candies pour across. Fill a jar with one kind of sweet to seal it. Sort them all to win.

EASY TO START, SATISFYING TO MASTER
• One-tap controls: pick a jar, pick where it goes.
• Hundreds of handcrafted and generated levels that ramp up gently.
• Clever twists along the way: wrapped mystery candies, jars covered with dhaka cloth, padlocked jars, tall jars, gift boxes, customer orders and a mischievous shop cat.
• Stuck? Undo, add an extra jar or shuffle the jars.
• When the end is obvious, the game finishes the sorting for you.

RENOVATE THE FAMILY SHOP
• Earn a star for every win and spend it on renovation tasks.
• Restore 10 areas, from the Old Counter and the Shop Front to the Rooftop, a Festival Night and the Mountain Branch.
• Pick your favourite style for each piece and watch the shop transform with a before-and-after reveal.
• Help Maya and her grandmother Hajurama, and meet the neighbours along the way.

ALWAYS SOMETHING TO DO
• Daily rewards, daily missions and a daily challenge.
• Collect stickers in the sweet-shop album.
• Win streaks give free boosters, and seven wins in a row open Hajurama's Trunk.
• Dozens of achievements to unlock.

MADE TO BE FAIR AND COSY
• No ads between levels. Watching an ad is always your choice, for a bonus.
• Plays offline.
• In English and Nepali.
• Colour-blind friendly candy markers and adjustable text size.

Grab a jar and start sorting. The shop is waiting!
```

### A.3 Nepali (machine-drafted: ask a native speaker to read it first)

**Short description (80):**
`रंगीन मिठाई बट्टामा मिलाउनुहोस् र हजुरआमाको पुरानो पसल फेरि सजाउनुहोस्!`

**Full description:**
```
रंगीन मिठाईहरू बट्टामा खन्याउनुहोस्, मिलाउनुहोस् र हरेक बट्टामा एउटै किसिमको मिठाई भर्नुहोस्। अनि तारा कमाएर हजुरआमाको पुरानो मिठाई पसललाई फेरि जीवन्त बनाउनुहोस्!

पसल सर्ट काठमाडौंको एउटा पारिवारिक मिठाई पसलमा आधारित आरामदायी मिलाउने पजल हो। एउटा बट्टा थिच्नुहोस्, अर्को थिच्नुहोस्, मिठाई खन्याइन्छ। एकै किसिमले भरिएको बट्टा बन्द हुन्छ। सबै मिलाएपछि जित!

सुरु गर्न सजिलो, खेल्न रमाइलो
• एक थिचाइको नियन्त्रण।
• बिस्तारै कठिन हुँदै जाने सयौं तह।
• बेरिएका रहस्यमय मिठाई, ढाकाले छोपिएका बट्टा, ताल्चा लागेका बट्टा, अग्ला बट्टा, उपहार बाकस, ग्राहकका अर्डर र चकचके बिरालो।
• अड्किनुभयो? फर्काउनुहोस्, थप बट्टा राख्नुहोस् वा मिसाउनुहोस्।

पारिवारिक पसल सजाउनुहोस्
• हरेक जितमा तारा, अनि ताराले नवीकरणका काम।
• पुरानो काउन्टरदेखि छतसम्म, चाडको रात र हिमाली शाखासम्म १० ठाउँ।
• आफूलाई मनपर्ने शैली रोज्नुहोस् र पहिले-पछिको फरक हेर्नुहोस्।
• माया र हजुरआमालाई सघाउनुहोस्, छिमेकीहरूलाई भेट्नुहोस्।

हरेक दिन केही नयाँ
• दैनिक उपहार, दैनिक मिसन र दैनिक चुनौती।
• मिठाई पसलको एल्बममा स्टिकर जम्मा गर्नुहोस्।
• लगातार जितमा फ्री बुस्टर, सात जितमा हजुरआमाको बाकस।

निष्पक्ष र आरामदायी
• तहबीच विज्ञापन छैन। विज्ञापन हेर्नु सधैं तपाईंको रोजाइ।
• अफलाइन खेल्न मिल्छ।
• नेपाली र अंग्रेजीमा।

बट्टा समात्नुहोस्, मिलाउन थाल्नुहोस्। पसल पर्खिरहेको छ!
```

### A.4 Tips
- Play has no keyword field. It ranks on the title and descriptions, so the
  search terms (candy sort, jar, puzzle, renovate, Nepali, offline) appear in
  normal sentences above. Don't add a keyword block.
- Only describe what's in the build you submit.
- Screenshots sell more than text. The captioned set in `docs/store/play/` is
  ordered with the strongest first.

## Appendix B. Message for testers (copy and send)

```
Hi! I've made a cosy candy-sorting puzzle game called Pasal Sort, and Google needs 12 people to test it for 14 days before I can publish it. Could you help?

1. Open this link on your Android phone, signed in with your Gmail: <OPT-IN LINK>
2. Tap "Become a tester", then "Download it on Google Play" and install.
3. Please keep it installed for 14 days, and play a few levels whenever you have a minute.

If anything looks wrong or confusing, just reply to this message. Thank you so much!
```
(Replace `<OPT-IN LINK>` with the link from section 7.4. If you use a
Google Group, send the group's join link first.)
