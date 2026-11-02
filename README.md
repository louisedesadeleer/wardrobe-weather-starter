# Your week, dressed.

A personal wardrobe app + an outfit newsletter based on the weather.

Upload your clothes, make outfit boards, swipe to tag their temperature, then generate an email showing what to wear. Built with SwiftUI and Python. Example clothes included; no personal wardrobe data or accounts included.

<img width="1248" height="2198" alt="CleanShot 2026-11-02 at 16 39 25@2x" src="https://github.com/user-attachments/assets/237d206c-5ff4-4a26-a374-b72e2f326cbb" />

## Try the newsletter first

You need Python 3.10 or newer. No Xcode, API key or email account needed for the demo.

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python newsletter.py --demo
```

Open `outputs/newsletter/newsletter.html` in a browser. Windows: activate with `.venv\Scripts\activate` instead.

The demo is a **fictional warm week**, with original illustrated clothes. It generates seven outfit images, HTML, plain text, a MIME email with embedded images, and `selection.json` so you can inspect the choices. It sends nothing.

## Use your own wardrobe

1. [Install the iPhone app](docs/iphone.md). Requires a Mac, Xcode and iOS 17+.
2. Upload clothes, choose their categories, and create outfits. Weather-tag the outfits.
3. In app settings, choose **Prepare full backup → Save or share backup**. AirDrop/save it to your computer as `private/wardrobe.json`.
4. Copy `config.example.json` to `private/config.json`. Change the city, coordinates and timezone together. Lisbon is the example.
5. Generate a real forecast edition:

```sh
mkdir -p private
# Put your full wardrobe backup and config.json inside private/ first.
python newsletter.py --wardrobe private/wardrobe.json --config private/config.json
```

For one day: add `--days 1`. The full backup includes local photos and item IDs; the older compact newsletter export does not contain enough information for item-repeat rules.

Example clothes are automatically excluded from real editions, including custom boards that still use example pieces. Upload and tag your own outfits first.

**Transfer is manual.** Export again after adding clothes, creating boards, tagging weather or logging wears. This is a personal starter, not a synced cloud service. The app's calendar forecast is currently fixed to Lisbon; changing the Python config changes newsletter weather only.

## How it chooses

- Uses the mean of hourly temperatures **from 09:00 until sunset**, in the configured timezone. The email shows the min–max within that window. It does not use overnight lows.
- Cold: below 10°C; cool: 10°C up to 18°C; mild: 18°C up to 24°C; hot: 24°C+.
- Matches your manual outfit tags. It does not ask an LLM whether a jacket is warm.
- No repeated tops; bottoms at most twice in a Monday–Sunday week. Matches item IDs, not names. Conservatively includes shirts/knitwear as tops and skirts/shorts as bottoms.
- Earlier logged wears count towards that week's limits. Update the backup so it knows what you wore.
- Favours planned outfits when they fit the constraints. Never repeats an outfit within one generated edition.
- Excludes outfits with missing items, stale photo tags or unknown item categories. Keep item categories consistent; supported labels are in `category()` in `newsletter.py`.
- At 40%+ precipitation probability, excludes dry-only outfits and adds a short rain reminder. At 30 km/h+ wind, excludes avoid-wind outfits. These are adjustable starter thresholds, not promises of comfort or protection.
- Leaves an honest gap if there aren't enough eligible outfits. A bounded search finds a practical combination, not a mathematically guaranteed optimum.

## Send it

**Simplest:** connect Gmail in your AI assistant, give it the generated HTML and the outfit JPGs, and explicitly ask it to email them to you with inline images. Available Gmail tools vary; check the received email once. Merely connecting Gmail does not create a schedule.

**Optional SMTP:** `send_email.py` can send the generated `.eml` with embedded photos. First configure `SMTP_HOST`, `SMTP_PORT` (defaults to 465), `SMTP_USER`, `SMTP_PASSWORD`, and optionally `SMTP_FROM` privately in your environment. Use credentials provided by your mail service; do not commit them or paste them into a chat. This sender uses implicit TLS, not port 587/STARTTLS.

```sh
# Dry run, no network or credentials needed:
python send_email.py outputs/newsletter/newsletter.eml --to you@example.com --send-id first-test
# Same command with --send delivers it using your configured SMTP service.
```

Receipts in `private/receipts/` prevent duplicate attempts for the same recipient and edition ID. After an uncertain failure, check sent mail before retrying. SMTP acceptance does not prove inbox delivery. The sender has been unit-tested with a fake SMTP server; no live delivery is included in the demo.

## Make it daily (optional)

See [daily delivery](docs/daily-delivery.md). No scheduler is installed or enabled by this repo. Start with a manual email, then schedule generation and delivery at your chosen local time. A daily run needs current wardrobe data and wear logs to avoid suggesting yesterday's T-shirt.

## What's in the app?

Outfit boards with drag/resize/rotate; one-photo-at-a-time clothing upload; on-device background removal; weather swipes and voice tags; monthly/weekly calendar; worn/not-worn tracking; wear analytics; optional OpenAI photo suggestions; manual resale-listing drafts.

The optional OpenAI connection sends selected photos and relevant wardrobe metadata to OpenAI. Bring your own API key in the app's settings. It is stored in the iOS Keychain. Background removal itself uses Apple's Vision framework and does not need an API key. For a shared production app, put paid AI requests behind an authenticated server instead of distributing a developer key.

The app stores its library locally on the phone. No Supabase, login, cloud sync, background newsletter worker or public subscription system is supplied.

Already use Indyx? See [optional import notes](docs/indyx-import.md). No supported one-click Indyx importer is included.

## Develop / check

```sh
python -m unittest discover -s tests -v
cd ios
bash scripts/check.sh
bash scripts/check-ios.sh
```

The iOS project is `ios/WardrobeWeather.xcodeproj`. The newsletter uses Pillow for board composition and Python's standard library for everything else. Live forecast requests use [Open-Meteo](https://open-meteo.com/en/docs); check their usage terms if adapting for a commercial service. Outages fail explicitly, without substituting fictional weather.

Keep personal data in `private/`, which is gitignored. Review staged files before pushing. The bundled images are simple original illustrations for the demo, not AI recognition examples.
