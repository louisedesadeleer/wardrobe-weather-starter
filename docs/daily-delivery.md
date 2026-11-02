# From one email to a daily email

The repo can generate and send an email. It does **not** install a scheduler, synchronise your phone, or enable unattended delivery.

## First, verify one manual send

1. Export the current full wardrobe backup to `private/wardrobe.json`.
2. Generate `newsletter.html`, inspect the temperatures and outfits, and send a test to yourself.
3. Check the received email's pictures. Gmail connections in AI tools have different HTML/attachment capabilities.
4. If using SMTP, configure your provider's credentials privately and test `send_email.py` with `--send`. Do not use your normal email password unless your provider explicitly supports it; use its app-password/OAuth/service credential instructions. The bundled sender supports password-based SMTP over TLS only.

## Daily command sequence

The process that runs these commands needs the SMTP environment variables described in the README. Replace the recipient and use a stable edition ID for the local date, such as `2026-07-06`.

```sh
.venv/bin/python newsletter.py --wardrobe private/wardrobe.json --config private/config.json --days 1
# Only run the next command if generation succeeded.
.venv/bin/python send_email.py outputs/newsletter/newsletter.eml --to you@example.com --send-id YYYY-MM-DD --send
```

Never send yesterday's output after today's forecast request fails. A scheduled wrapper must stop on generation errors and use the current local date, not the literal placeholder above.

## Scheduling prompt

Give this to your coding assistant after the manual test works:

> Set up this repo to generate and email one outfit each morning at 8:00 in Europe/Lisbon. Use the latest private/wardrobe.json and private/config.json. Keep credentials in private environment configuration. Run generation first and stop if it fails; never send stale output. Use a recipient-plus-local-date edition ID so retries don't duplicate emails. Log success/failure without secrets, notify me if it fails, and provide a way to disable it. Explain where the job runs, what happens if that computer is asleep, and verify daylight-saving behaviour. Don't enable the schedule until the dry run works. My recipient is [my address].

On a Mac, a local launch agent is a simple starting point but depends on that Mac being available. For independent delivery, use an always-on private host and configure its timezone explicitly. Do not put wardrobe photos or credentials in a public GitHub Actions artifact.

## The part you still have to maintain

The phone has local storage. A server cannot see your latest outfits unless you transfer a fresh backup or build authenticated sync.

Weekly limits work across a generated weekly edition and earlier logged wears in the supplied backup. Independently generated daily editions do not automatically reserve previously emailed outfits. Log what you wore and refresh the export, or extend the scheduler with a sent-plan ledger if you want “suggested” to count as “used”.

A practical first version: export on Sunday, generate the week, then log wears. Add automated phone sync later if you actually need it. Supabase is one possible future option, not a prerequisite.
