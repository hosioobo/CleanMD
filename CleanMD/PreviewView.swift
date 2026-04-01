import SwiftUI
import AppKit
import WebKit
import UniformTypeIdentifiers

struct PreviewView: NSViewRepresentable {
    var text: String
    var scrollSync: ScrollSyncController
    var isDarkMode: Bool
    var palette: ColorPalette
    var showH1Divider: Bool
    var showH2Divider: Bool
    var fileURL: URL? = nil
    var previewMode: PreviewMode? = nil

    private var resolvedPreviewMode: PreviewMode {
        previewMode ?? fileURL.flatMap { SupportedDocumentKind(url: $0).previewMode } ?? .markdown
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "scrollChanged")
        config.setURLSchemeHandler(context.coordinator, forURLScheme: PreviewURLPolicy.localFileScheme)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.applyColorScheme(isDarkMode, to: webView)
        context.coordinator.applyUnderPageBackground(palette.previewBg, to: webView)

        let html = Self.htmlTemplate(resourceURL: Bundle.main.resourceURL)
        if let resourceURL = Bundle.main.resourceURL {
            webView.loadHTMLString(html, baseURL: resourceURL)
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }

        scrollSync.onScrollPreviewTo = { [weak webView] fraction in
            guard let webView else { return }
            webView.evaluateJavaScript("scrollToFraction(\(fraction));", completionHandler: nil)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.scheduleRender(text: text, previewMode: resolvedPreviewMode, fileURL: fileURL)
        context.coordinator.applyColorScheme(isDarkMode, to: webView)
        context.coordinator.applyUnderPageBackground(palette.previewBg, to: webView)
        context.coordinator.applyDocumentBaseURL(fileURL, to: webView)
        // Apply palette whenever it changes — covers dark/light switch AND user edits
        if context.coordinator.lastPalette != palette {
            context.coordinator.lastPalette = palette
            context.coordinator.applyPalette(palette, to: webView)
        }
        context.coordinator.applyHeadingDividers(
            showH1: showH1Divider,
            showH2: showH2Divider,
            to: webView
        )
    }

    // MARK: - HTML Template

    static func htmlTemplate(resourceURL: URL?) -> String {
        let katexCSSURL = assetURLString(resourceURL: resourceURL, fileName: "katex.min.css")
        let highlightCSSURL = assetURLString(resourceURL: resourceURL, fileName: "highlight.min.css")
        let markedURL = assetURLString(resourceURL: resourceURL, fileName: "marked.min.js")
        let highlightURL = assetURLString(resourceURL: resourceURL, fileName: "highlight.min.js")
        let katexURL = assetURLString(resourceURL: resourceURL, fileName: "katex.min.js")
        let autoRenderURL = assetURLString(resourceURL: resourceURL, fileName: "auto-render.min.js")
        let allowedLinkSchemesJSON = PreviewURLPolicy.allowedSchemesJSON(for: .link)
        let allowedImageSchemesJSON = PreviewURLPolicy.allowedSchemesJSON(for: .image)
        let localFileScheme = PreviewURLPolicy.localFileScheme
        let sharedRendererSource = sharedRendererJavaScript()
        let sharedRendererSourceLiteral = String(reflecting: sharedRendererSource)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="\(katexCSSURL)">
        <link rel="stylesheet" href="\(highlightCSSURL)">
        <style>
        :root {
            --preview-bg:      #ffffff;
            --preview-text:    #24292e;
            --h1:              #24292e;
            --h2:              #24292e;
            --h3:              #24292e;
            --inline-code-bg:  #eaecf0;
            --inline-code-fg:  #24292e;
            --code-block-bg:   #eaecf0;
            --quote-text:      #57606a;
            --quote-border:    #d0d7de;
            --link:            #0969da;
            --hr-border:       #d0d7de;
            --h-border:        #d0d7de;
            --h1-divider-width: 1px;
            --h2-divider-width: 1px;
            --table-border:    #d0d7de;
            --table-alt:       #f6f8fa;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --preview-bg:      #0d1117;
                --preview-text:    #e1e4e8;
                --h1:              #e1e4e8;
                --h2:              #e1e4e8;
                --h3:              #e1e4e8;
                --inline-code-bg:  #30363d;
                --inline-code-fg:  #d8d9f2;
                --code-block-bg:   #161b22;
                --quote-text:      #b8bcc7;
                --quote-border:    #3d444d;
                --link:            #79c0ff;
                --hr-border:       #30363d;
                --h-border:        #30363d;
                --h1-divider-width: 1px;
                --h2-divider-width: 1px;
                --table-border:    #30363d;
                --table-alt:       #161b22;
            }
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            font-size: 15px;
            line-height: 1.72;
            letter-spacing: 0.01em;
            color: var(--preview-text);
            background: var(--preview-bg);
            padding: 22px 30px 34px;
            max-width: 980px;
            margin: 0 auto;
            -webkit-font-smoothing: antialiased;
            text-rendering: optimizeLegibility;
        }
        body.code-preview {
            max-width: none;
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 1.35em;
            margin-bottom: 0.55em;
            font-weight: 600;
            line-height: 1.2;
            letter-spacing: -0.01em;
        }
        h1 { color: var(--h1); font-size: 1.92em; border-bottom: var(--h1-divider-width) solid var(--h-border); padding-bottom: 0.28em; }
        h2 { color: var(--h2); font-size: 1.46em; border-bottom: var(--h2-divider-width) solid var(--h-border); padding-bottom: 0.28em; }
        h3 { color: var(--h3); font-size: 1.22em; }
        h4, h5, h6 { color: var(--h3); }
        h1:first-child, h2:first-child, h3:first-child { margin-top: 0.2em; }
        p { margin-bottom: 1.02em; }
        a { color: var(--link); text-decoration: none; }
        a:hover { text-decoration: underline; }
        code {
            font-family: "SF Mono", Menlo, monospace;
            font-size: 0.86em;
            background: var(--inline-code-bg);
            color: var(--inline-code-fg);
            padding: 0.2em 0.4em;
            border-radius: 4px;
        }
        pre {
            background: var(--code-block-bg) !important;
            border: none;
            padding: 13px 16px;
            border-radius: 8px;
            overflow-x: auto;
            margin-bottom: 1.08em;
        }
        pre code, pre code.hljs, .hljs {
            background: transparent !important;
            border: none;
            padding: 0;
            font-size: 0.86em;
            color: inherit;
        }
        blockquote {
            border-left: 4px solid var(--quote-border);
            color: var(--quote-text);
            padding: 0.08em 0 0.08em 1em;
            margin: 0 0 1.02em 0;
        }
        ul, ol { padding-left: 1.75em; margin-bottom: 1.02em; }
        li + li { margin-top: 0.22em; }
        table {
            border-collapse: collapse;
            margin-bottom: 1.08em;
            width: 100%;
            table-layout: fixed;
        }
        table th, table td {
            border: 1px solid var(--table-border);
            padding: 8px 12px;
            text-align: left;
            vertical-align: top;
            line-height: 1.5;
            overflow-wrap: anywhere;
            word-break: break-word;
        }
        table code {
            white-space: pre-wrap;
            overflow-wrap: anywhere;
            word-break: break-word;
        }
        table tr:nth-child(2n) { background-color: var(--table-alt); }
        img { max-width: 100%; }
        hr { border: none; border-top: 1px solid var(--hr-border); margin: 1.8em 0; }
        </style>
        <script src="\(markedURL)"></script>
        <script src="\(highlightURL)"></script>
        <script src="\(katexURL)"></script>
        <script src="\(autoRenderURL)"></script>
        <script>
        var allowedLinkSchemes = \(allowedLinkSchemesJSON);
        var allowedImageSchemes = \(allowedImageSchemesJSON);
        var localFileScheme = \(String(reflecting: localFileScheme));
        var cleanMDDocumentBaseURL = null;
        \(sharedRendererSource)

        function hasSupportedMathDelimiters(text) {
            return text.indexOf('$$') !== -1 ||
                   text.indexOf('\\\\(') !== -1 ||
                   text.indexOf('\\\\[') !== -1;
        }

        function maybeRenderMath(content, sourceText) {
            // Single-$ inline math is intentionally disabled to avoid currency false positives.
            if (!hasSupportedMathDelimiters(sourceText)) return;
            renderMathInElement(content, {
                delimiters: [
                    { left: '$$', right: '$$', display: true },
                    { left: '\\\\(', right: '\\\\)', display: false },
                    { left: '\\\\[', right: '\\\\]', display: true }
                ],
                throwOnError: false
            });
        }

        var maxHighlightedCodeCacheEntries = 400;
        var mainThreadHighlightCache = new Map();
        marked.use(buildMarkedOptions(mainThreadHighlightCache, maxHighlightedCodeCacheEntries));

        var renderWorker = null;
        var workerUnavailable = false;
        var latestRequestId = 0;
        var latestRequestedText = '';
        var latestRequestedMode = 'markdown';
        var hasRenderedFirstDocument = false;

        function ensureRenderWorker() {
            if (renderWorker || workerUnavailable) return;
            try {
                var markedURL = \(String(reflecting: markedURL));
                var highlightURL = \(String(reflecting: highlightURL));
                var workerSource = `
                self.importScripts(${JSON.stringify(markedURL)}, ${JSON.stringify(highlightURL)});
                var allowedLinkSchemes = ${JSON.stringify(allowedLinkSchemes)};
                var allowedImageSchemes = ${JSON.stringify(allowedImageSchemes)};
                var localFileScheme = ${JSON.stringify(localFileScheme)};
                var cleanMDDocumentBaseURL = null;
                ${\(sharedRendererSourceLiteral)}
                
                var highlightCache = new Map();
                marked.use(buildMarkedOptions(highlightCache, 400));
                
                self.onmessage = function(event) {
                    var data = event.data || {};
                    if (data.type !== 'render') return;
                    var text = String(data.text || '');
                    var mode = String(data.mode || 'markdown');
                    cleanMDDocumentBaseURL = (typeof data.documentBaseURL === 'string' && data.documentBaseURL.length > 0)
                        ? data.documentBaseURL
                        : null;
                    var html = '';
                    try {
                        html = renderPreviewHtml(mode, text, highlightCache, 400);
                    } catch (err) {
                        html = '<pre>' + escapeHtml(String(err && err.message ? err.message : err)) + '</pre>';
                    }
                    self.postMessage({
                        type: 'rendered',
                        requestId: data.requestId,
                        mode: mode,
                        html: html
                    });
                };
                `;

                var blob = new Blob([workerSource], { type: 'application/javascript' });
                var blobURL = URL.createObjectURL(blob);
                renderWorker = new Worker(blobURL);
                URL.revokeObjectURL(blobURL);

                renderWorker.onmessage = function(event) {
                    var data = event.data || {};
                    if (data.type !== 'rendered') return;
                    if (data.requestId !== latestRequestId) return; // drop stale renders

                    var content = document.getElementById('content');
                    if (!content) return;
                    var mode = String(data.mode || latestRequestedMode || 'markdown');
                    document.body.classList.toggle('code-preview', mode.indexOf('code:') === 0);
                    content.innerHTML = String(data.html || '');
                    if (mode === 'markdown') {
                        maybeRenderMath(content, latestRequestedText);
                    }
                };

                renderWorker.onerror = function() {
                    workerUnavailable = true;
                    if (renderWorker) {
                        renderWorker.terminate();
                        renderWorker = null;
                    }
                    renderWithMainThreadPreview(latestRequestedMode, latestRequestedText);
                };
            } catch (e) {
                workerUnavailable = true;
                renderWorker = null;
            }
        }

        function renderWithMainThreadPreview(mode, text) {
            var content = document.getElementById('content');
            if (!content) return;
            var html = renderPreviewHtml(mode, text, mainThreadHighlightCache, maxHighlightedCodeCacheEntries);
            content.innerHTML = html;
            if (String(mode || 'markdown') === 'markdown') {
                maybeRenderMath(content, text);
            }
        }

        function renderPreview(mode, text, documentBaseURL) {
            latestRequestedMode = String(mode || 'markdown');
            latestRequestedText = text;
            cleanMDDocumentBaseURL = (typeof documentBaseURL === 'string' && documentBaseURL.length > 0)
                ? documentBaseURL
                : null;

            // Render the initial document synchronously to remove startup lag.
            if (!hasRenderedFirstDocument) {
                hasRenderedFirstDocument = true;
                renderWithMainThreadPreview(mode, text);
                ensureRenderWorker(); // warm worker for subsequent updates
                return;
            }

            ensureRenderWorker();

            // Fallback path when Web Worker is unavailable.
            if (!renderWorker) {
                renderWithMainThreadPreview(mode, text);
                return;
            }

            latestRequestId += 1;
            renderWorker.postMessage({
                type: 'render',
                requestId: latestRequestId,
                mode: latestRequestedMode,
                text: text,
                documentBaseURL: cleanMDDocumentBaseURL
            });
        }

        function renderMarkdown(text) {
            renderPreview('markdown', text, cleanMDDocumentBaseURL);
        }

        function updateColors(c) {
            var r = document.documentElement.style;
            r.setProperty('--preview-bg',     c.previewBg);
            r.setProperty('--preview-text',   c.previewText);
            r.setProperty('--h1',             c.h1);
            r.setProperty('--h2',             c.h2);
            r.setProperty('--h3',             c.h3);
            r.setProperty('--inline-code-bg', c.inlineCodeBg);
            r.setProperty('--inline-code-fg', c.inlineCodeFg);
            r.setProperty('--code-block-bg',  c.codeBlockBg);
            r.setProperty('--quote-text',     c.quoteText);
            r.setProperty('--quote-border',   c.quoteBorder);
            r.setProperty('--link',           c.link);
            document.body.style.background = c.previewBg;
            document.body.style.color = c.previewText;
        }

        function updateHeadingDividers(config) {
            var r = document.documentElement.style;
            r.setProperty('--h1-divider-width', config.h1 ? '1px' : '0px');
            r.setProperty('--h2-divider-width', config.h2 ? '1px' : '0px');
        }

        function updateDocumentBaseURL(rawURL) {
            cleanMDDocumentBaseURL = (typeof rawURL === 'string' && rawURL.length > 0) ? rawURL : null;
        }

        var suppressScrollEvent = false;
        var suppressTimer = null;
        function scrollToFraction(fraction) {
            if (suppressTimer) clearTimeout(suppressTimer);
            suppressScrollEvent = true;
            var maxScroll = document.documentElement.scrollHeight - window.innerHeight;
            if (maxScroll > 0) { window.scrollTo(0, fraction * maxScroll); }
            suppressTimer = setTimeout(function() {
                suppressScrollEvent = false;
                suppressTimer = null;
            }, 200);
        }

        window.addEventListener('scroll', function() {
            if (suppressScrollEvent) return;
            var scrollTop = window.scrollY || document.documentElement.scrollTop;
            var maxScroll = document.documentElement.scrollHeight - window.innerHeight;
            var fraction = maxScroll > 0 ? scrollTop / maxScroll : 0;
            window.webkit.messageHandlers.scrollChanged.postMessage(fraction);
        }, { passive: true });
        </script>
        </head>
        <body>
        <div id="content"></div>
        </body>
        </html>
        """
    }

    private static func assetURLString(resourceURL: URL?, fileName: String) -> String {
        resourceURL?.appendingPathComponent(fileName).absoluteString ?? fileName
    }

    private static func sharedRendererJavaScript() -> String {
        """
        function escapeHtml(raw) {
            return String(raw).replace(/[&<>"']/g, function(ch) {
                switch (ch) {
                    case '&': return '&amp;';
                    case '<': return '&lt;';
                    case '>': return '&gt;';
                    case '"': return '&quot;';
                    case "'": return '&#39;';
                    default:  return ch;
                }
            });
        }

        function escapeAttribute(raw) {
            return escapeHtml(raw);
        }

        function resolveSanitizedURL(rawValue, allowedSchemes) {
            var value = String(rawValue || '').trim();
            if (!value) return '';
            if (value[0] === '#') return value;

            var resolved = value;
            if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(resolved)) {
                if (!cleanMDDocumentBaseURL) return '';
                try {
                    resolved = new URL(resolved, cleanMDDocumentBaseURL).href;
                } catch (e) {
                    return '';
                }
            }

            var schemeIndex = resolved.indexOf(':');
            if (schemeIndex <= 0) return '';
            var scheme = resolved.slice(0, schemeIndex).toLowerCase();
            return allowedSchemes.indexOf(scheme) !== -1 ? resolved : '';
        }

        function rewriteLocalFileURL(resolvedURL) {
            if (typeof resolvedURL !== 'string' || resolvedURL.indexOf('file://') !== 0) return resolvedURL;
            return localFileScheme + '://' + resolvedURL.slice('file://'.length);
        }

        function sanitizeLinkHref(rawHref) {
            return rewriteLocalFileURL(resolveSanitizedURL(rawHref, allowedLinkSchemes));
        }

        function sanitizeImageSrc(rawSrc) {
            return rewriteLocalFileURL(resolveSanitizedURL(rawSrc, allowedImageSchemes));
        }

        function normalizeLanguage(rawLang) {
            var lang = String(rawLang || '').trim();
            if (!lang) return '';
            return lang.split(/\\s+/)[0].toLowerCase();
        }

        function hashString(input) {
            var hash = 2166136261;
            for (var i = 0; i < input.length; i++) {
                hash ^= input.charCodeAt(i);
                hash = Math.imul(hash, 16777619);
            }
            return hash >>> 0;
        }

        function cacheSet(cache, key, value, maxEntries) {
            if (cache.has(key)) cache.delete(key);
            cache.set(key, value);
            if (cache.size > maxEntries) {
                var oldestKey = cache.keys().next().value;
                cache.delete(oldestKey);
            }
        }

        function highlightCodeCached(code, lang, cache, maxEntries) {
            var key = lang + '|' + code.length + '|' + hashString(code);
            if (cache.has(key)) return cache.get(key);

            var highlighted;
            if (lang && hljs.getLanguage(lang)) {
                highlighted = hljs.highlight(code, { language: lang, ignoreIllegals: true }).value;
            } else {
                highlighted = hljs.highlightAuto(code).value;
            }
            cacheSet(cache, key, highlighted, maxEntries);
            return highlighted;
        }

        function buildMarkedOptions(cache, maxEntries) {
            return {
                gfm: true,
                breaks: true,
                renderer: {
                    html: function(token) {
                        var raw = '';
                        if (typeof token === 'string') {
                            raw = token;
                        } else if (token && typeof token === 'object') {
                            raw = token.raw || token.text || '';
                        }
                        return escapeHtml(raw);
                    },
                    link: function(token) {
                        var href = sanitizeLinkHref(token && token.href);
                        var text = '';
                        if (this.parser && token && Array.isArray(token.tokens)) {
                            text = this.parser.parseInline(token.tokens);
                        } else {
                            text = escapeHtml(token && token.text ? token.text : '');
                        }
                        if (!href) return text;
                        var title = token && token.title ? ' title="' + escapeAttribute(token.title) + '"' : '';
                        return '<a href="' + escapeAttribute(href) + '"' + title + '>' + text + '</a>';
                    },
                    image: function(token) {
                        var src = sanitizeImageSrc(token && token.href);
                        var alt = escapeAttribute(token && token.text ? token.text : '');
                        if (!src) return alt;
                        var title = token && token.title ? ' title="' + escapeAttribute(token.title) + '"' : '';
                        return '<img src="' + escapeAttribute(src) + '" alt="' + alt + '"' + title + '>';
                    },
                    code: function(token) {
                        var code = String(token && token.text ? token.text : '');
                        var lang = normalizeLanguage(token && token.lang);
                        var highlighted = highlightCodeCached(code, lang, cache, maxEntries);
                        var className = 'hljs' + (lang ? (' language-' + lang) : '');
                        return '<pre><code class="' + className + '">' + highlighted + '</code></pre>\\n';
                    }
                }
            };
        }

        function setCodePreviewClass(enabled) {
            if (typeof document === 'undefined' || !document.body) return;
            document.body.classList.toggle('code-preview', !!enabled);
        }

        function renderCodePreviewHtml(language, text, cache, maxEntries) {
            var code = String(text || '');
            var lang = normalizeLanguage(language);
            var highlighted = highlightCodeCached(code, lang, cache, maxEntries);
            var className = 'hljs' + (lang ? (' language-' + lang) : '');
            setCodePreviewClass(true);
            return '<pre><code class="' + className + '">' + highlighted + '</code></pre>\\n';
        }

        function renderMarkdownPreviewHtml(text) {
            setCodePreviewClass(false);
            return marked.parse(text);
        }

        function renderPreviewHtml(mode, text, cache, maxEntries) {
            var normalizedMode = String(mode || 'markdown');
            if (normalizedMode.indexOf('code:') === 0) {
                var language = normalizedMode.slice(5);
                return renderCodePreviewHtml(language, text, cache, maxEntries);
            }
            return renderMarkdownPreviewHtml(text);
        }
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKURLSchemeHandler {
        var parent: PreviewView
        weak var webView: WKWebView?

        private var debounceTimer: Timer?
        private var isLoaded = false
        private var pendingText: String?
        private var pendingPreviewMode: PreviewMode = .markdown
        private var queuedRenderKey: String?
        private var lastRenderedRenderKey: String?
        private var pendingPalette: ColorPalette?
        private var pendingHeadingDividers: (Bool, Bool)?
        private var pendingDocumentBaseURLString: String?
        private var lastAppliedDarkMode: Bool? = nil
        private var lastUnderPageBackgroundHex: String?
        private var lastAppliedHeadingDividers: (Bool, Bool)?
        private var lastAppliedDocumentBaseURLString: String?
        var lastPalette: ColorPalette? = nil

        init(_ parent: PreviewView) {
            self.parent = parent
        }

        func scheduleRender(text: String, previewMode: PreviewMode, fileURL: URL?) {
            let normalizedText = Self.normalizedText(text: text, previewMode: previewMode)
            let documentBaseKey = PreviewURLPolicy.documentBaseURLAbsoluteString(for: fileURL) ?? ""
            let renderKey = Self.renderKey(text: normalizedText, previewMode: previewMode, documentBaseKey: documentBaseKey)
            guard renderKey != queuedRenderKey, renderKey != lastRenderedRenderKey else { return }
            queuedRenderKey = renderKey
            pendingText = normalizedText
            pendingPreviewMode = previewMode
            pendingDocumentBaseURLString = PreviewURLPolicy.documentBaseURLAbsoluteString(for: fileURL)
            debounceTimer?.invalidate()
            guard isLoaded, let webView else { return }
            debounceTimer = Timer.scheduledTimer(
                withTimeInterval: debounceInterval(for: normalizedText),
                repeats: false
            ) { [weak self, weak webView] _ in
                guard let self, let webView else { return }
                self.render(text: normalizedText, previewMode: previewMode, in: webView)
            }
        }

        private static func renderKey(text: String, previewMode: PreviewMode, documentBaseKey: String) -> String {
            "\(previewMode.renderKey)|\(documentBaseKey)|\(text)"
        }

        private static func normalizedText(text: String, previewMode: PreviewMode) -> String {
            switch previewMode {
            case .markdown:
                return MarkdownLinkDestinationNormalizer.normalize(
                    MarkdownTableNormalizer.normalize(text)
                )
            case .code:
                return text
            }
        }

        private func debounceInterval(for text: String) -> TimeInterval {
            let length = text.utf16.count
            switch length {
            case ..<2_000:   return 0.08
            case ..<12_000:  return 0.12
            case ..<40_000:  return 0.18
            default:         return 0.28
            }
        }

        func applyColorScheme(_ isDark: Bool, to webView: WKWebView) {
            guard isDark != lastAppliedDarkMode else { return }
            lastAppliedDarkMode = isDark
            webView.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        }

        func applyUnderPageBackground(_ hex: String, to webView: WKWebView) {
            guard hex != lastUnderPageBackgroundHex else { return }
            lastUnderPageBackgroundHex = hex
            if #available(macOS 12.0, *) {
                webView.underPageBackgroundColor = NSColor(hex: hex)
            }
        }

        func applyDocumentBaseURL(_ fileURL: URL?, to webView: WKWebView) {
            let target = PreviewURLPolicy.documentBaseURLAbsoluteString(for: fileURL)
            guard target != lastAppliedDocumentBaseURLString else { return }
            guard isLoaded else {
                pendingDocumentBaseURLString = target
                return
            }

            lastAppliedDocumentBaseURLString = target
            pendingDocumentBaseURLString = target
            let json = (try? JSONEncoder().encode(target))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
            webView.evaluateJavaScript("updateDocumentBaseURL(\(json));", completionHandler: nil)
        }

        func applyPalette(_ palette: ColorPalette, to webView: WKWebView) {
            guard isLoaded else { pendingPalette = palette; return }
            guard let data = try? JSONEncoder().encode(palette),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView.evaluateJavaScript("updateColors(\(json));", completionHandler: nil)
        }

        func applyHeadingDividers(showH1: Bool, showH2: Bool, to webView: WKWebView) {
            let target = (showH1, showH2)
            if let lastAppliedHeadingDividers, lastAppliedHeadingDividers == target { return }
            guard isLoaded else { pendingHeadingDividers = target; return }

            lastAppliedHeadingDividers = target
            let json = "{\"h1\":\(showH1 ? "true" : "false"),\"h2\":\(showH2 ? "true" : "false")}"
            webView.evaluateJavaScript("updateHeadingDividers(\(json));", completionHandler: nil)
        }

        private func render(text: String, previewMode: PreviewMode, in webView: WKWebView) {
            guard let data = try? JSONEncoder().encode(text),
                  let json = String(data: data, encoding: .utf8) else { return }
            let renderKey = Self.renderKey(
                text: text,
                previewMode: previewMode,
                documentBaseKey: pendingDocumentBaseURLString ?? ""
            )
            lastRenderedRenderKey = renderKey
            queuedRenderKey = nil
            let modeJSON = (try? JSONEncoder().encode(previewMode.renderKey))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "\"markdown\""
            let documentBaseJSON = (try? JSONEncoder().encode(pendingDocumentBaseURLString))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
            webView.evaluateJavaScript(
                "renderPreview(\(modeJSON), \(json), \(documentBaseJSON));",
                completionHandler: nil
            )
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let pendingDocumentBase = pendingDocumentBaseURLString ?? PreviewURLPolicy.documentBaseURLAbsoluteString(for: parent.fileURL)
            if pendingDocumentBase != lastAppliedDocumentBaseURLString {
                lastAppliedDocumentBaseURLString = pendingDocumentBase
                let json = (try? JSONEncoder().encode(pendingDocumentBase))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
                webView.evaluateJavaScript("updateDocumentBaseURL(\(json));", completionHandler: nil)
            }
            if let text = pendingText {
                render(text: text, previewMode: pendingPreviewMode, in: webView)
            }
            applyColorScheme(parent.isDarkMode, to: webView)
            applyPalette(pendingPalette ?? parent.palette, to: webView)
            let pending = pendingHeadingDividers ?? (parent.showH1Divider, parent.showH2Divider)
            applyHeadingDividers(showH1: pending.0, showH2: pending.1, to: webView)
            pendingPalette = nil
            pendingHeadingDividers = nil
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            switch PreviewURLPolicy.navigationAction(for: url, currentURL: webView.url) {
            case .allowInPlace:
                decisionHandler(.allow)
            case .openExternally(let externalURL):
                NSWorkspace.shared.open(externalURL)
                decisionHandler(.cancel)
            case .openDocument(let documentURL):
                NSDocumentController.shared.openDocument(withContentsOf: documentURL, display: true) { _, _, _ in }
                decisionHandler(.cancel)
            case .cancel:
                decisionHandler(.cancel)
            }
        }

        deinit {
            debounceTimer?.invalidate()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "scrollChanged", let fraction = message.body as? Double else { return }
            DispatchQueue.main.async { self.parent.scrollSync.previewScrolled(to: fraction) }
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
            guard let requestURL = urlSchemeTask.request.url,
                  let fileURL = PreviewURLPolicy.fileURL(fromLocalPreviewURL: requestURL) else {
                urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL))
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let mimeType = PreviewURLPolicy.mimeType(for: fileURL, data: data)
                let response = URLResponse(
                    url: requestURL,
                    mimeType: mimeType,
                    expectedContentLength: data.count,
                    textEncodingName: nil
                )
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } catch {
                urlSchemeTask.didFailWithError(error)
            }
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
            // No-op: requests are fulfilled synchronously in `start`.
        }
    }
}

private extension PreviewMode {
    var renderKey: String {
        switch self {
        case .markdown:
            return "markdown"
        case .code(let language):
            return "code:\(language.lowercased())"
        }
    }
}
