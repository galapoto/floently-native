# Read Mobile Browser Compatibility — 0330

Status: implementation reference for the Read mobile browser.

## Decision

The universal mobile architecture is **native Read browser + browser-independent handoff**.

The source browser is not expected to run a Floently extension. Safari, Chrome, Firefox, Edge, Opera, Vivaldi, Brave, Samsung Internet and other mobile browsers hand a URL to the native app. The native app owns the continuing reading session.

## Why this is required

### Chrome mobile extensions are not a universal path

Google documents that Chrome Web Store extensions/themes can only be used on computers; mobile Chrome does not provide the desktop extension model.

Reference: https://support.google.com/chrome_webstore/answer/1698338

### iOS/iPadOS

The first implementation uses `WKWebView`, persistent `WKWebsiteDataStore.default()`, and native SwiftUI controls. Apple documents `WKWebView` as the customizable web-content surface and documents password/passkey support for browser apps using WKWebView.

References:

- https://developer.apple.com/documentation/webkit/wkwebview
- https://developer.apple.com/documentation/authenticationservices/password-use-in-web-browsers
- https://developer.apple.com/documentation/authenticationservices/passkey-use-in-web-browsers

Apple also offers managed default-browser and browser-engine entitlements. Those are future distribution capabilities, not prerequisites for 0330. In the EU, alternative/embedded engine entitlements have substantial eligibility and security requirements, so 0330 deliberately uses the platform engine instead of inventing a browser engine.

References:

- https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser
- https://developer.apple.com/support/alternative-browser-engines/

### Android

Android documents two major choices: Custom Tabs and WebView. Custom Tabs are excellent for external browsing and third-party authentication because they use the user's preferred browser and its cookie state, but they do not give Floently the DOM control required for live reading/highlighting. WebView provides the needed in-app DOM control, so Read uses WebView as its reading browser and follows Android's security guidance.

References:

- https://developer.android.com/develop/ui/views/layout/webapps
- https://developer.android.com/develop/ui/views/layout/webapps/in-app-browsing-embedded-web
- https://developer.android.com/develop/ui/views/layout/webapps/webview

Android explicitly notes that Custom Tabs are preferred for third-party identity-provider login. This is tracked as an authentication fallback boundary; 0330 does not pretend that arbitrary external OAuth can be made to share cookies back into an app-controlled WebView.

Reference: https://developer.android.com/work/guide

## Third-party OAuth constraint

Google's OAuth policy prohibits directing Google OAuth requests to embedded user agents under the developer's control. Google's current best-practice documentation specifically says not to use Android WebView or iOS WKWebView for Google OAuth.

References:

- https://developers.google.com/identity/protocols/oauth2/policies
- https://developers.google.com/identity/protocols/oauth2/resources/best-practices

Therefore Read must:

- allow normal website password/passkey forms where the site supports them;
- avoid injecting reader JavaScript on known authentication-provider pages;
- never spoof a browser user agent to bypass provider policy;
- expose provider-blocked login as a compatibility state rather than silently failing;
- add approved platform authentication handoff only where the target site's flow can safely return session state.

## Browser handoff strategy

Browser independence comes from operating-system URL/app routing, not extension APIs.

Canonical forms:

- custom scheme: `floentlyread://open?url=<encoded URL>`
- HTTPS app link: `https://read.floently.com/mobile/open?url=<encoded URL>`

Android also accepts `ACTION_SEND` text/URL shares and `ACTION_VIEW` links. iOS handles the custom scheme immediately and is prepared for the HTTPS universal-link form once the associated-domain file is published for the production bundle/team identity.

Apple universal links reference:
https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content

## Security decisions

- persistent first-party site cookies are allowed;
- Android third-party cookies are enabled for this dedicated browser surface to avoid breaking legitimate layered sites that rely on them;
- TLS errors are never ignored;
- Android mixed content is blocked;
- remote pages cannot use local file access;
- Android Safe Browsing remains enabled;
- arbitrary pages are not given a native `addJavascriptInterface` object;
- protected authentication origins never receive reader extraction code;
- Floently never proxies credentials/authenticated HTML through its backend.

## Compatibility targets

The native browser architecture is source-browser agnostic. It is intended to accept URLs originating from:

- Safari / Chrome / Firefox / Edge / Opera / Vivaldi / Brave on iPhone and iPad;
- Chrome / Firefox / Edge / Opera / Vivaldi / Brave / Samsung Internet and other Android browsers;
- browser share sheets and ordinary links;
- links opened from email, chat, notes and other apps.

The rendered site is not dependent on which browser originally supplied the URL.

## Known boundary after 0330

No engineering implementation can guarantee that every third-party identity provider will permit login inside an app-controlled embedded browser. That is a provider security policy, not a DOM/rendering bug. The browser itself remains functional; provider-specific authentication fallbacks must be implemented without bypassing those policies.
