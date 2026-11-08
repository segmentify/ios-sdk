# Demo apps

All demo apps run against **Segmentify QA** out of the box. No setup needed.

## Running against another environment (e.g. Unifonic)

Every backend setting can be overridden without changing code, so the same code works on every branch and no environment URLs or credentials are committed.

| Key | Default |
| --- | --- |
| `SEGMENTIFY_API_KEY` | Segmentify QA demo key (not sent when only `SEGMENTIFY_AUTH_HEADER` is set) |
| `SEGMENTIFY_AUTH_HEADER` | none |
| `SEGMENTIFY_DATA_CENTER_URL` | `https://gandalf-qa.segmentify.com` |
| `SEGMENTIFY_PUSH_DATA_CENTER_URL` | `https://gimli-qa.segmentify.com` |
| `SEGMENTIFY_SUB_DOMAIN` | demo subdomain of the app |

Set them in either place (environment variables win):

1. **Secrets.plist** (`ios-event-playground`, `native-push-app`, `native-apns-push-app`): copy `Demo/Secrets.example.plist` to `Secrets.plist` next to the app's `AppDelegate.swift` and fill in the values. Xcode picks it up automatically; it is gitignored.
2. **Scheme environment variables** (all apps, and the only option for `native-segmentify-app`): Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables. Uncheck "Shared" on the scheme or keep the scheme out of git so credentials are not committed.

Delete `Secrets.plist` (or clear the variables) to go back to Segmentify QA.
