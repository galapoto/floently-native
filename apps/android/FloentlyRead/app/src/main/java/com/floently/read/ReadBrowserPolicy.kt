package com.floently.read

import android.net.Uri

object ReadBrowserPolicy {
    private val protectedAuthenticationHosts = setOf(
        "accounts.google.com",
        "login.microsoftonline.com",
        "login.live.com",
        "appleid.apple.com",
        "www.facebook.com",
        "m.facebook.com"
    )

    fun isProtectedAuthenticationUrl(url: String?): Boolean {
        val host = runCatching { Uri.parse(url.orEmpty()).host?.lowercase() }.getOrNull() ?: return false
        return host in protectedAuthenticationHosts || host.endsWith(".okta.com") || host.endsWith(".auth0.com")
    }

    fun normalizeAddress(value: String?): String? {
        val raw = value.orEmpty().trim()
        if (raw.isBlank()) return null

        val parsed = runCatching { Uri.parse(raw) }.getOrNull()
        val scheme = parsed?.scheme?.lowercase()
        if ((scheme == "http" || scheme == "https") && !parsed.host.isNullOrBlank()) {
            return parsed.toString()
        }

        if (DOMAIN_PATTERN.matches(raw)) {
            return "https://$raw"
        }

        return Uri.Builder()
            .scheme("https")
            .authority("www.google.com")
            .path("search")
            .appendQueryParameter("q", raw)
            .build()
            .toString()
    }

    fun resolveIncomingUri(uri: Uri?): String? {
        uri ?: return null
        val scheme = uri.scheme?.lowercase()
        val host = uri.host?.lowercase()

        if (scheme == "floentlyread" && host == "open") {
            return normalizeAddress(uri.getQueryParameter("url"))
        }

        if ((scheme == "http" || scheme == "https") && host == "read.floently.com" && uri.path == "/mobile/open") {
            return normalizeAddress(uri.getQueryParameter("url"))
        }

        return if (scheme == "http" || scheme == "https") normalizeAddress(uri.toString()) else null
    }

    val selectionExtractionJavaScript: String = """
        (() => {
          const selection = window.getSelection();
          return String(selection ? selection.toString() : "")
            .replace(/\s+/g, " ")
            .trim();
        })();
    """.trimIndent()

    // FLOENTLY_LIVE_READER_0330 — explicit extraction against the live rendered page.
    val pageExtractionJavaScript: String = """
        (() => {
          const normalize = (value) => String(value || "").replace(/\s+/g, " ").trim();
          const excludedSelector = [
            "script", "style", "noscript", "template", "nav", "footer", "aside",
            "[role='navigation']", "[role='dialog']", "[role='menu']", "[aria-modal='true']",
            "[aria-hidden='true']", "[hidden]", ".cookie", ".cookies", ".modal", ".drawer",
            ".sidebar", ".side-nav", ".sidenav", ".toolbar", ".menu"
          ].join(",");

          const isVisible = (element) => {
            if (!(element instanceof HTMLElement)) return false;
            const style = getComputedStyle(element);
            if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) return false;
            const rect = element.getBoundingClientRect();
            if (rect.width < 80 || rect.height < 24) return false;
            if (rect.bottom < 0 || rect.top > innerHeight * 1.5) return false;
            return true;
          };

          const exposure = (element) => {
            const rect = element.getBoundingClientRect();
            const points = [
              [rect.left + rect.width * 0.5, rect.top + Math.min(rect.height * 0.25, innerHeight * 0.25)],
              [rect.left + rect.width * 0.5, rect.top + Math.min(rect.height * 0.5, innerHeight * 0.5)]
            ];
            let hits = 0;
            for (const [x, y] of points) {
              if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) continue;
              const stack = document.elementsFromPoint(x, y);
              if (stack.some((node) => node === element || element.contains(node))) hits += 1;
            }
            return hits;
          };

          const candidates = Array.from(document.querySelectorAll([
            "main", "article", "[role='main']", "[data-testid*='lesson' i]", "[data-testid*='content' i]",
            "[class*='lesson' i]", "[class*='lecture' i]", "[class*='transcript' i]", "[class*='content' i]",
            "section", "body"
          ].join(",")));

          const scored = candidates
            .filter(isVisible)
            .map((element) => {
              const clone = element.cloneNode(true);
              clone.querySelectorAll(excludedSelector).forEach((node) => node.remove());
              const text = normalize(clone.innerText || clone.textContent || "");
              if (text.length < 80) return null;

              const rect = element.getBoundingClientRect();
              const linkText = Array.from(element.querySelectorAll("a"))
                .reduce((sum, link) => sum + normalize(link.innerText).length, 0);
              const controls = element.querySelectorAll("button,input,select,textarea,[role='button'],[role='menuitem']").length;
              const linkDensity = Math.min(1, linkText / Math.max(text.length, 1));
              const edgeDistance = Math.min(Math.abs(rect.left), Math.abs(innerWidth - rect.right));
              const narrowEdgePenalty = rect.width < innerWidth * 0.42 && edgeDistance < 40 ? 2500 : 0;
              const shellPenalty = element === document.body ? 1800 : 0;
              const fixedPenalty = ["fixed", "sticky"].includes(getComputedStyle(element).position) ? 1400 : 0;
              const semanticBonus = element.matches("main,article,[role='main']") ? 1800 : 0;
              const lessonBonus = /lesson|lecture|transcript|content/i.test(`${'$'}{element.id} ${'$'}{element.className}`) ? 900 : 0;
              const exposedBonus = exposure(element) * 800;
              const viewportWidthBonus = rect.width >= innerWidth * 0.45 && rect.width <= innerWidth * 0.98 ? 500 : 0;
              const score = Math.min(text.length, 14000) + semanticBonus + lessonBonus + exposedBonus + viewportWidthBonus
                - linkDensity * 7000 - controls * 55 - narrowEdgePenalty - shellPenalty - fixedPenalty;

              return { text, score };
            })
            .filter(Boolean)
            .sort((a, b) => b.score - a.score);

          return scored[0] ? scored[0].text : "";
        })();
    """.trimIndent()

    private val DOMAIN_PATTERN = Regex("^[A-Za-z0-9.-]+\\.[A-Za-z]{2,}([/:?#].*)?${'$'}")
}
