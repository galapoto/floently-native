# Iloadi Read Mobile Browser UX — 0330

Status: **DESIGN FREEZE / implementation authority**

Applies to: **Iloadi/Floently Read mobile on iPhone, iPad, Android phone, Android tablet and foldables.**

This specification implements the existing Read-only scope lock and the Iloadi UI Constitution. The mobile web-page experience must not depend on a Chrome/Safari/Firefox/Opera/Vivaldi extension. Mobile source browsers are entry points only; the reading session lives inside the native Read browser.

## 1. Product rule

**Websites stay websites.**

Read must render the original remote page using the platform browser engine, preserve the site's own DOM, cookies, JavaScript, media, forms and navigation, and place native Iloadi controls around/above that live page. A website URL must never be silently converted into a standalone Reader document.

## 2. Browser-independent entry

Every mobile browser is treated the same:

1. User opens or shares a URL from Safari, Chrome, Firefox, Edge, Opera, Vivaldi, Brave, Samsung Internet or another browser.
2. The URL is handed to Iloadi Read through the standard app link / custom-scheme entry point.
3. Iloadi Read loads that URL in its native browser surface.
4. The user signs in once inside that browser session where the target site allows embedded-browser sign-in.
5. Navigation remains inside the same Read browser session, preserving cookies and site state.

No browser-specific extension is required for the core mobile path.

## 3. Screen geometry

The browser is an immersive Read screen and may hide global product navigation.

Phone layout, top to bottom:

- 52 pt/dp browser toolbar;
- live web page fills remaining viewport;
- 52 pt/dp native Read action strip floats above the safe-area bottom edge.

Tablet layout uses the same controls with a constrained toolbar content width and no artificial narrowing of the website viewport.

The web page itself receives the full available width. Iloadi must not wrap it in cards or resize it to imitate a document reader.

## 4. Browser toolbar

The toolbar contains, in this order:

- Back — 48 pt/dp hit target;
- Forward — 48 pt/dp hit target;
- address/search field — flexible width, 52 pt/dp height;
- reload/stop — 48 pt/dp hit target;
- overflow — 48 pt/dp hit target.

The address field always displays the real current origin/domain. It must never imply that an external website is hosted by Iloadi.

## 5. Native Read strip

The Read strip is native UI and is never inserted into the target site's DOM.

Initial 0330 actions:

- Read page;
- Read selection when a selection exists;
- play/pause state entry point;
- reading status.

The strip remains available as the website navigates between SPA routes or full page loads. It does not disappear because the site replaces its DOM.

## 6. Authentication states

Authentication is part of browsing, not a separate Reader mode.

- ordinary username/password forms remain inside the live page;
- site cookies use a persistent browser data store;
- third-party sign-in pages must not receive Iloadi DOM extraction/injection;
- Iloadi must not spoof a browser user agent to bypass identity-provider policy;
- Iloadi must never read password fields, authentication tokens or provider pages for TTS;
- provider-blocked embedded authentication must be surfaced honestly and handled by an approved browser/authentication flow in a later compatibility layer rather than bypassed.

## 7. DOM reading scope

Read extraction is explicit and occurs against the live rendered page.

The extraction engine must prefer visible semantic reading regions such as `main`, `article`, `[role=main]`, lesson/lecture/content containers and transcript containers while penalizing navigation, drawers, toolbars, dialogs, hidden/occluded layers, high-link-density regions and edge sidebars.

Extraction must never mutate, replace or restyle the source site's DOM.

Known authentication-provider origins are protected from reader injection.

## 8. Navigation continuity

The browser must preserve:

- cookies and persistent website data;
- back/forward history for the current session;
- full-page navigation;
- History API / SPA navigation signals;
- `target=_blank` and `window.open` by opening the destination inside the Read browser rather than silently abandoning the app;
- non-web schemes such as `mailto:` and `tel:` by delegating to the operating system.

## 9. Security baseline

- HTTPS is never downgraded.
- TLS/certificate errors are not bypassed.
- mixed active content is disabled where the platform exposes that control.
- local file access from arbitrary remote pages is disabled.
- Safe Browsing remains enabled on Android.
- no `addJavascriptInterface` bridge is exposed to arbitrary Android web content.
- Iloadi reader JavaScript is injected only on explicit/eligible reading pages and never on protected authentication origins.
- no proxying of third-party credentials or authenticated pages through `read.floently.com`.

## 10. External-browser compatibility contract

Core mobile Read compatibility is provided by the native app, not by trying to inject scripts into every mobile browser.

- iOS/iPadOS browsers: open/share the URL into Iloadi Read.
- Android browsers: open/share the URL into Iloadi Read.
- if an external browser supports a platform share sheet, Iloadi Read should be a URL/text share target;
- the canonical deep-link form is `floentlyread://open?url=<encoded https URL>`;
- the canonical HTTPS app-link form is `https://read.floently.com/mobile/open?url=<encoded https URL>`.

## 11. Quality gate

0330 is not complete unless automated checks prove at minimum:

- iOS uses persistent `WKWebsiteDataStore.default()`;
- Android uses persistent `CookieManager` and allows third-party cookies per browser surface where required for ordinary web compatibility;
- neither platform spoofs a user agent;
- protected auth origins skip reader extraction;
- Android does not expose `addJavascriptInterface` to untrusted pages;
- popup/new-window navigation remains in-app;
- non-HTTP schemes are delegated safely;
- both platforms implement the same URL normalization rules;
- external browser handoff routes exist for Android and iOS source URLs;
- Android Read compiles in CI;
- iOS Read compiles for an iPhone simulator in CI before merge.
