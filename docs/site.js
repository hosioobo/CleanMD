function sanitizeEventKey(value) {
    return (value || "unknown")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "")
        .slice(0, 64) || "unknown";
}

function countApiURL(namespace, key) {
    return `https://api.countapi.xyz/hit/${encodeURIComponent(namespace)}/${encodeURIComponent(key)}`;
}

function trackSiteEvent(kind, label) {
    const namespace = document.body?.dataset.countapiNamespace;
    if (!namespace) {
        return;
    }

    const key = sanitizeEventKey([kind, label].filter(Boolean).join("-"));

    fetch(countApiURL(namespace, key), {
        cache: "no-store",
        mode: "cors"
    }).catch(() => null);
}

function bindTrackedLinks() {
    document.querySelectorAll("[data-track-click]").forEach((link) => {
        link.addEventListener("click", () => {
            trackSiteEvent("click", link.dataset.trackClick || "link");
        });
    });
}

async function resolveLatestReleaseDownload(apiURL, fallbackURL) {
    const response = await fetch(apiURL, {
        cache: "no-store",
        headers: {
            Accept: "application/vnd.github+json"
        }
    });

    if (!response.ok) {
        throw new Error(`GitHub release lookup failed with ${response.status}`);
    }

    const release = await response.json();
    const releaseAsset = (release.assets || []).find((asset) => {
        return typeof asset.name === "string" && asset.name.endsWith(".zip");
    });

    return releaseAsset?.browser_download_url || release.html_url || fallbackURL;
}

async function startDownloadRedirect() {
    const body = document.body;
    const status = document.querySelector("[data-download-status]");
    const searchParams = new URLSearchParams(window.location.search);
    const ref = sanitizeEventKey(searchParams.get("ref") || "direct");
    const apiURL = body.dataset.releaseApi;
    const fallbackURL = body.dataset.releaseFallback;

    trackSiteEvent("download_click", ref);

    if (!apiURL || !fallbackURL) {
        if (status) {
            status.textContent = "Download settings are missing. Opening the GitHub release page instead.";
        }
        window.location.replace(fallbackURL || "https://github.com/hosioobo/CleanMD/releases/latest");
        return;
    }

    if (status) {
        status.textContent = "Finding the newest packaged zip on GitHub Releases…";
    }

    try {
        const targetURL = await resolveLatestReleaseDownload(apiURL, fallbackURL);
        if (status) {
            status.textContent = "Release found. Redirecting now…";
        }
        window.location.replace(targetURL);
    } catch (error) {
        if (status) {
            status.textContent = "GitHub is slow right now. Opening the release page instead…";
        }
        window.location.replace(fallbackURL);
    }
}

document.addEventListener("DOMContentLoaded", () => {
    const body = document.body;
    bindTrackedLinks();

    if (body.dataset.siteEvent) {
        trackSiteEvent(body.dataset.siteEvent, body.dataset.sitePage || body.dataset.pageKind || "site");
    }

    if (body.dataset.pageKind === "download") {
        void startDownloadRedirect();
    }
});
