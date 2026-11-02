# Starter verification

Checked 2 November 2026:

- Twelve Python tests pass: daylight filtering, missing forecast values, weekly repeat limits, exhausted wardrobes, stale weather tags, categories, worn history, rain rules, embedded email images, path rejection, demo-data exclusion, SMTP dry run and recipient/duplicate handling.
- Thirteen Swift core test groups pass.
- Xcode simulator build succeeds (Xcode 27.1 installed locally, iOS 17 deployment target).
- The example newsletter renders with seven illustrated outfits; HTML preview inspected.
- Live Open-Meteo request returned HTTP 503 during this check. The live request/schema path is implemented, but successful live delivery was not verified for this starter. Errors do not fall back to demo weather.
- SMTP was tested with mocks only. No email was sent from the starter during verification.
- No real-device install, AI photo request, scheduler or automatic cloud sync was tested or enabled for this starter.

The original personal app was installed on an iPhone. This clean starter uses separate example data and a different bundle identifier.
