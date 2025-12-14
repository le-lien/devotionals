// search.js
// Site-wide text search across devotionals, general notes, and comments

(() => {
  const NOTE_STORAGE_KEY = "devotional_notes_v1";
  const ANNOTATION_STORAGE_KEY = "devotional_annotations_v1";

  // --- localStorage helpers ---
  function canUseLocalStorage() {
    try {
      const testKey = "__ls_test__";
      window.localStorage.setItem(testKey, "1");
      window.localStorage.removeItem(testKey);
      return true;
    } catch {
      return false;
    }
  }

  const CAN_USE_LOCAL_STORAGE = canUseLocalStorage();

  function loadJSON(key, fallback) {
    if (!CAN_USE_LOCAL_STORAGE) return fallback;
    try {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch {
      return fallback;
    }
  }

  // --- DEVOTIONAL_SOURCES access ---
  function getSources() {
    // If data.js wasn't loaded on search.html, this will be undefined
    const src = window.DEVOTIONAL_SOURCES;
    return Array.isArray(src) ? src : [];
  }

  function findSourceById(id) {
    return getSources().find((s) => s.id === id) || null;
  }

  // Date helpers
  function dateKeyToDate(dateKey, year) {
    const [mm, dd] = String(dateKey).split("-").map(Number);
    return new Date(year, (mm || 1) - 1, dd || 1);
  }

  function formatLongDate(dateObj) {
    return dateObj.toLocaleDateString(undefined, {
      weekday: "long",
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  // Get query from URL (and optional input)
  function getQueryFromURL() {
    const params = new URLSearchParams(window.location.search);
    const q = params.get("q") || "";
    return q.trim();
  }

  function setQueryToURL(q) {
    const params = new URLSearchParams(window.location.search);
    if (q) params.set("q", q);
    else params.delete("q");
    const newUrl = `${window.location.pathname}?${params.toString()}`;
    window.history.replaceState({}, "", newUrl);
  }

  function normalizeText(text) {
    return (text || "").toString();
  }

  // --- Build searchable items ---
  function collectReadingItems(currentYear) {
    const items = [];
    const sources = getSources();

    sources.forEach((src) => {
      if (!src || !src.entries) return;

      for (const dateKey in src.entries) {
        const entry = src.entries[dateKey];
        if (!entry) continue;

        // dailyVerse/dailyPrayer might be "", object, or undefined
        const dv = entry.dailyVerse;
        const dp = entry.dailyPrayer;

        const texts = [
          entry.title,
          entry.passage,
          entry.body,
          entry.note,

          typeof dv === "string" ? dv : (dv && dv.ref),
          typeof dv === "string" ? "" : (dv && dv.text),

          typeof dp === "string" ? dp : (dp && dp.title),
          typeof dp === "string" ? "" : (dp && dp.text),
        ]
          .map(normalizeText)
          .join("\n");

        const d = dateKeyToDate(dateKey, currentYear);
        const y = d.getFullYear();
        const [mm, dd] = String(dateKey).split("-");
        const linkDateStr = `${y}-${mm}-${dd}`;

        items.push({
          kind: "reading",
          sourceId: src.id,
          sourceName: src.name || src.id,
          dateKey,
          createdAt: d.toISOString(),
          where: "Reading",
          fullText: texts,
          href: `index.html?source=${encodeURIComponent(
            src.id
          )}&date=${encodeURIComponent(linkDateStr)}`,
        });
      }
    });

    return items;
  }

  function collectGeneralNoteItems(notesState, currentYear) {
    const items = [];
    for (const sourceId in notesState) {
      const perDate = notesState[sourceId] || {};
      for (const dateKey in perDate) {
        const text = normalizeText(perDate[dateKey]);
        if (!text.trim()) continue;

        const src = findSourceById(sourceId);
        const sourceName = (src && src.name) || sourceId;

        const d = dateKeyToDate(dateKey, currentYear);
        const y = d.getFullYear();
        const [mm, dd] = String(dateKey).split("-");
        const linkDateStr = `${y}-${mm}-${dd}`;

        items.push({
          kind: "general-note",
          sourceId,
          sourceName,
          dateKey,
          createdAt: d.toISOString(),
          where: "General note",
          fullText: text,
          href: `index.html?source=${encodeURIComponent(
            sourceId
          )}&date=${encodeURIComponent(linkDateStr)}`,
        });
      }
    }
    return items;
  }

  function collectCommentItems(annotationsState, currentYear) {
    const items = [];
    for (const sourceId in annotationsState) {
      const perDate = annotationsState[sourceId] || {};
      for (const dateKey in perDate) {
        const anns = perDate[dateKey] || [];
        anns.forEach((ann) => {
          const src = findSourceById(sourceId);
          const sourceName = (src && src.name) || sourceId;

          const text = [ann?.quote, ann?.comment]
            .map(normalizeText)
            .join("\n");

          let createdAt = ann?.createdAt;
          if (!createdAt) {
            const d0 = dateKeyToDate(dateKey, currentYear);
            createdAt = d0.toISOString();
          }

          const d = new Date(createdAt);
          const y = d.getFullYear();
          const [mm, dd] = String(dateKey).split("-");
          const linkDateStr = `${y}-${mm}-${dd}`;

          items.push({
            kind: "comment",
            sourceId,
            sourceName,
            dateKey,
            createdAt,
            where: "Comment",
            fullText: text,
            href: `index.html?source=${encodeURIComponent(
              sourceId
            )}&date=${encodeURIComponent(linkDateStr)}`,
          });
        });
      }
    }
    return items;
  }

  // --- Searching ---
  function makeSnippet(text, q, maxLen = 180) {
    const lowerText = text.toLowerCase();
    const lowerQ = q.toLowerCase();
    const idx = lowerText.indexOf(lowerQ);

    if (idx === -1) {
      return text.slice(0, maxLen) + (text.length > maxLen ? "…" : "");
    }

    const start = Math.max(0, idx - 40);
    const end = Math.min(text.length, idx + q.length + 60);
    let snippet = text.slice(start, end);
    if (start > 0) snippet = "…" + snippet;
    if (end < text.length) snippet = snippet + "…";
    return snippet;
  }

  function searchAll(query, currentYear, notesState, annotationsState) {
    if (!query) return [];

    const qLower = query.toLowerCase();

    const allItems = [
      ...collectReadingItems(currentYear),
      ...collectGeneralNoteItems(notesState, currentYear),
      ...collectCommentItems(annotationsState, currentYear),
    ];

    const matches = allItems.filter((item) =>
      (item.fullText || "").toLowerCase().includes(qLower)
    );

    // sort newest first
    matches.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    return matches.map((item) => ({
      ...item,
      snippet: makeSnippet(item.fullText || "", query),
    }));
  }

  // --- Render ---
  function renderResults(q, els, currentYear, notesState, annotationsState) {
    const { searchResultsEl, searchInfoEl } = els;

    if (!q) {
      if (searchInfoEl) searchInfoEl.textContent = "Enter a word or phrase to search.";
      if (searchResultsEl) searchResultsEl.innerHTML = "";
      return;
    }

    const results = searchAll(q, currentYear, notesState, annotationsState);

    if (searchInfoEl) {
      searchInfoEl.textContent = `${results.length} result${results.length === 1 ? "" : "s"} for “${q}”`;
    }

    if (!searchResultsEl) return;

    if (!results.length) {
      searchResultsEl.innerHTML = "<p>No matches found. Try a different word or phrase.</p>";
      return;
    }

    const list = document.createElement("div");
    list.className = "notes-overview-list";

    results.forEach((item) => {
      const card = document.createElement("article");
      card.className = "notes-overview-item";

      const d = new Date(item.createdAt);
      const longDate = formatLongDate(d);

      const header = document.createElement("div");
      header.className = "notes-overview-header";

      const link = document.createElement("a");
      link.href = item.href;
      link.className = "notes-overview-link";
      link.textContent = `${item.sourceName} – ${longDate}`;

      const whereBadge = document.createElement("span");
      whereBadge.className = "notes-overview-type";
      whereBadge.textContent = item.where;

      header.appendChild(link);
      header.appendChild(whereBadge);

      const body = document.createElement("div");
      body.className = "notes-overview-body";

      const snippetP = document.createElement("p");
      snippetP.textContent = item.snippet;

      body.appendChild(snippetP);

      card.appendChild(header);
      card.appendChild(body);
      list.appendChild(card);
    });

    searchResultsEl.innerHTML = "";
    searchResultsEl.appendChild(list);
  }

  // --- Init ---
  document.addEventListener("DOMContentLoaded", () => {
    const searchResultsEl = document.getElementById("searchResults");
    const searchInfoEl = document.getElementById("searchInfo");
    const yearSpan = document.getElementById("year");

    if (yearSpan) yearSpan.textContent = new Date().getFullYear();

    // Helpful warning if localStorage is blocked (file:// often causes this)
    if (!CAN_USE_LOCAL_STORAGE && searchInfoEl) {
      searchInfoEl.textContent =
        "⚠️ Your browser is blocking local storage (common on file://). Use GitHub Pages / HTTPS or run a local server to search notes/comments.";
    }

    // Optional: support a search box if you have it
    const searchForm = document.getElementById("searchForm");
    const searchInput = document.getElementById("searchInput");

    const currentYear = new Date().getFullYear();
    const notesState = loadJSON(NOTE_STORAGE_KEY, {});
    const annotationsState = loadJSON(ANNOTATION_STORAGE_KEY, {});

    // If your reading search is empty, data.js probably isn't included on search.html
    if (getSources().length === 0 && searchInfoEl) {
      // Only show this if user actually searches; otherwise it’s noisy.
      // We'll add it when q is present.
    }

    function doSearch(q) {
      const sourcesCount = getSources().length;
      if (q && sourcesCount === 0 && searchInfoEl) {
        searchInfoEl.textContent =
          `Searching “${q}”… (Note: reading search is unavailable because data.js/DEVOTIONAL_SOURCES is not loaded on this page.)`;
      }

      renderResults(q, { searchResultsEl, searchInfoEl }, currentYear, notesState, annotationsState);
    }

    // Search from URL
    const initialQ = getQueryFromURL();
    if (searchInput) searchInput.value = initialQ;
    doSearch(initialQ);

    // Search from form (if exists)
    if (searchForm && searchInput) {
      searchForm.addEventListener("submit", (e) => {
        e.preventDefault();
        const q = (searchInput.value || "").trim();
        setQueryToURL(q);
        doSearch(q);
      });
    }
  });
})();
