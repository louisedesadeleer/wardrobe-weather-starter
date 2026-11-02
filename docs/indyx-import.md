# Optional: bring your own Indyx wardrobe

You can start with photos in this app. You do not need Indyx or a proxy.

If you already have a large wardrobe in another app, first check whether it offers an export. The original project used mitmproxy to inspect requests from the owner's own Indyx account. This is an advanced, manual migration, not an official Indyx integration or a guaranteed working importer.

## iPhone + Mac proxy setup

1. Install [mitmproxy](https://docs.mitmproxy.org/stable/overview/installation/) on your Mac. Put phone and Mac on the same trusted Wi-Fi.
2. Start `mitmweb --listen-host 0.0.0.0 --listen-port 8080`. Allow incoming access on your trusted network if macOS asks. Find your Mac's Wi-Fi IP in System Settings → Wi-Fi → Details → TCP/IP.
3. On iPhone, open **Settings → Wi-Fi → ⓘ next to that network → Configure Proxy → Manual**. Server = your Mac's IP, port = `8080`. Save. This is a Wi-Fi setting, not a VPN.
4. In iPhone Safari, visit **http://mitm.it** and download the Apple certificate profile. If it says traffic isn't passing through mitmproxy, check the IP, port, firewall, Wi-Fi and VPN settings first.
5. Install the downloaded profile from **Settings → General → VPN & Device Management** (or **Profile Downloaded** near the top of Settings). An unsigned local certificate profile is expected here; check it is the mitmproxy profile you just downloaded.
6. Go to **Settings → General → About → Certificate Trust Settings** and enable full trust for that mitmproxy root certificate. If only “Trust Store Version” is shown, the profile has not been installed yet.
7. Open Indyx. Browse your clothes and outfits so their requests appear in mitmweb. Use only your own account/data. Avoid using unrelated apps during capture.
8. Export the necessary wardrobe response data locally, then adapt it to the schema in `examples/wardrobe.json`. Preserve item IDs, outfit IDs, item membership, board layers and image references. Do not copy authentication headers into the output JSON.
9. Turn **Configure Proxy → Off** afterwards. Stop mitmweb and remove the temporary certificate profile/trust if no longer needed.

Follow [mitmproxy's certificate documentation](https://docs.mitmproxy.org/stable/concepts/certificates/) for updated platform instructions. Some apps use certificate pinning and will not accept a proxy certificate; this starter does not bypass that protection.

Captures can contain session credentials. Keep captures, tokens and exports out of Git. The repo ignores `private/` and `*.flows`, but still review every staged file. Never give a public repo your full traffic capture.

## Prompt for your coding assistant

> I have a local export of my own wardrobe in private/. Inspect its structure without printing tokens or personal account data. Write a local converter to the full-backup schema in examples/wardrobe.json. Preserve IDs and outfit membership; handle pagination, missing items and changed photos. Download only the needed wardrobe photos. Keep all my data in private/. Show an import summary before replacing anything. Do not upload captures or commit personal data.

For updates, compare by stable ID and image hash: add new items, update changed photos, flag removed items, and preserve existing weather choices unless the outfit changed. Re-review changed outfits instead of trusting old tags blindly.
