# Put it on your iPhone

1. Install Xcode from the Mac App Store. Your Mac must meet the installed Xcode version's requirements. Open Xcode and finish its component downloads.
2. Open `ios/WardrobeWeather.xcodeproj`.
3. Select an iPhone **simulator** in the top toolbar and press ▶︎. You can try the app without a developer account. The seed has 32 illustrated outfits, including four waiting to be weather-tagged.
4. To use your real iPhone, sign in under **Xcode → Settings → Accounts** with your Apple Account.
5. Click the **blue project icon at the top of the left sidebar**. In the editor, select **TARGETS → WardrobeWeather → Signing & Capabilities**. This is not the scheme dropdown next to the Run button.
6. Enable **Automatically manage signing**, choose your **Personal Team**, and change the bundle identifier from `com.example.wardrobeweather` to your own unique value, e.g. `com.yourname.mywardrobe`.
7. Connect your unlocked iPhone by cable and trust the Mac if prompted. Select that physical device in the top toolbar.
8. If requested, enable **Settings → Privacy & Security → Developer Mode** on the phone, restart it and confirm. Press ▶︎ in Xcode. Approve any signing/keychain request on the Mac itself.
9. If the phone asks you to trust the developer, use **Settings → General → VPN & Device Management**. Keep internet access working for verification. Turn off any leftover manual Wi-Fi proxy from an import.

Once installed and launched, you can unplug it. Local wardrobe functions work without the Mac; forecast and AI requests need internet.

A free Personal Team is enough to test on your own phone, but its provisioning expires after seven days, so you need to rebuild/reinstall periodically. TestFlight/App Store distribution requires the appropriate developer membership. [Apple's account guide](https://developer.apple.com/help/account/basics/about-your-developer-account).

## First use

- Swipe an outfit up for hot, down for cold, left for cool, right for mild. Use the editor to choose multiple temperature bands or rain/wind tags.
- Go back to your wardrobe to upload an item. Brand is optional; category matters for filtering and repeat limits.
- Create an outfit board. Tap a piece to bring it to the front; drag, pinch or use the size/rotation controls. Save.
- Log worn days in the calendar. Those records make the newsletter's weekly repeat limits useful.
- In Settings, **Prepare full backup → Save or share backup**, then transfer it to `private/wardrobe.json` on your computer.

Demo assets are bundled in the app. User photos live in the phone's app storage and full backups. Back up before deleting the app, resetting its storage or importing another full library; a full import replaces the local collection.

The app starts from its seed only on first launch. Editing `wardrobe-seed.json` won't overwrite an existing installation. Use a full-backup import to intentionally replace a library.
