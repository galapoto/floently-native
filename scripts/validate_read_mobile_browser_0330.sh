#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS="$ROOT/apps/ios/FloentlyRead/FloentlyRead"
ANDROID="$ROOT/apps/android/FloentlyRead/app/src/main"

fail() {
  echo "READ_MOBILE_BROWSER_0330_FAIL: $*" >&2
  exit 1
}

require_text() {
  local file="$1"
  local text="$2"
  grep -Fq "$text" "$file" || fail "$file missing required contract: $text"
}

for file in \
  "$ROOT/docs/design/READ_MOBILE_BROWSER_UX_SPEC_0330.md" \
  "$ROOT/docs/READ_MOBILE_BROWSER_COMPATIBILITY_0330.md" \
  "$IOS/ReadBrowserModel.swift" \
  "$IOS/ReadWebView.swift" \
  "$IOS/ReadBrowserView.swift" \
  "$ANDROID/java/com/floently/read/MainActivity.kt" \
  "$ANDROID/java/com/floently/read/ReadBrowserPolicy.kt"; do
  test -f "$file" || fail "missing $file"
done

require_text "$IOS/ReadWebView.swift" "configuration.websiteDataStore = .default()"
require_text "$IOS/ReadWebView.swift" "createWebViewWith configuration"
require_text "$IOS/ReadWebView.swift" "webViewWebContentProcessDidTerminate"
require_text "$IOS/ReadBrowserModel.swift" "accounts.google.com"
require_text "$IOS/ReadBrowserModel.swift" "elementsFromPoint"
require_text "$IOS/ReadBrowserModel.swift" "floentlyread"
require_text "$IOS/ReadBrowserModel.swift" "/mobile/open"
require_text "$ROOT/apps/ios/FloentlyRead/project.yml" "floentlyread"
require_text "$ROOT/apps/ios/FloentlyRead/FloentlyRead/FloentlyRead.entitlements" "applinks:read.floently.com"

if grep -RniE "customUserAgent|applicationNameForUserAgent" "$IOS"; then
  fail "iOS Read browser must not spoof a browser user agent"
fi

ANDROID_ACTIVITY="$ANDROID/java/com/floently/read/MainActivity.kt"
ANDROID_POLICY="$ANDROID/java/com/floently/read/ReadBrowserPolicy.kt"
ANDROID_MANIFEST="$ANDROID/AndroidManifest.xml"

require_text "$ANDROID_ACTIVITY" "CookieManager.getInstance().setAcceptCookie(true)"
require_text "$ANDROID_ACTIVITY" "setAcceptThirdPartyCookies(this, true)"
require_text "$ANDROID_ACTIVITY" "WebSettings.MIXED_CONTENT_NEVER_ALLOW"
require_text "$ANDROID_ACTIVITY" "settings.allowFileAccess = false"
require_text "$ANDROID_ACTIVITY" "settings.safeBrowsingEnabled = true"
require_text "$ANDROID_ACTIVITY" "onRenderProcessGone"
require_text "$ANDROID_ACTIVITY" "onCreateWindow"
require_text "$ANDROID_ACTIVITY" "onReceivedSslError"
require_text "$ANDROID_POLICY" "accounts.google.com"
require_text "$ANDROID_POLICY" "FLOENTLY_LIVE_READER_0330"
require_text "$ANDROID_POLICY" "elementsFromPoint"
require_text "$ANDROID_MANIFEST" "android:scheme=\"floentlyread\""
require_text "$ANDROID_MANIFEST" "android:host=\"read.floently.com\""
require_text "$ANDROID_MANIFEST" "android.intent.action.SEND"
require_text "$ROOT/apps/android/settings.gradle.kts" "include(\":FloentlyRead:app\")"

if grep -RniE "addJavascriptInterface|userAgentString|setUserAgentString" "$ANDROID"; then
  fail "Android Read browser must not expose a JS native bridge or spoof a user agent"
fi

if grep -RniE "handler\.proceed\(\)|proceed\(\).*Ssl" "$ANDROID_ACTIVITY"; then
  fail "Android Read browser must never bypass TLS certificate errors"
fi

require_text "$ROOT/docs/design/READ_MOBILE_BROWSER_UX_SPEC_0330.md" "Websites stay websites."
require_text "$ROOT/docs/design/READ_MOBILE_BROWSER_UX_SPEC_0330.md" "Safari, Chrome, Firefox, Edge, Opera, Vivaldi, Brave, Samsung Internet"

echo "FLOENTLY_READ_MOBILE_BROWSER_0330=PASS"
