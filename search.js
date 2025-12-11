// search.js
// Site-wide text search across devotionals, general notes, and comments

const NOTE_STORAGE_KEY = "devotional_notes_v1";
const ANNOTATION_STORAGE_KEY = "devotional_annotations_v1";

const searchResultsEl = document.getElementById("searchResults");
const searchInfoEl = document.getElementById("searchInfo");
const yearSpan = document.getElementById("year");

// Footer year
if (yearSpan) {
  yearSpan.textContent = new Date().getFullYear();
}

// --- localStorage helpers ---
let CAN_USE_LOCAL_STORAGE = true;
try {
  const testKey = "__ls_test__";
  window.localStorage.setItem(testKey, "1");
  window.localStorage.removeItem(testKey);
} catch {
  CAN_USE_LOCAL_STORAGE = false;
}

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
  try {
    return Array.isArray(DEVOTIONAL_SOURCES) ? DEVOTIONAL_SOURCES : [];
  } catch {
    return [];
  }
}

function findSourceById(id) {
  return getSources().find((s) => s.id === id) || null;
}

// Date helpers
function dateKeyToDate(dateKey, year) {
  const [mm, dd] = dateKey.split("-").map(Number);
  return new Date(year, mm - 1, dd);
}

function formatLongDate(dateObj) {
  return dateObj.toLocaleDateString(undefined, {
    weekday: "long",
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// Get query from URL
function getQuery() {
  const params = new URLSearchParams(window.location.search);
  const q = params.get("q") || "";
  return q.trim();
}

// --- Build searchable items ---

const notesState = loadJSON(NOTE_STORAGE_KEY, {});
const annotationsState = loadJSON(ANNOTATION_STORAGE_KEY, {});
const currentYear = new Date().getFullYear();

function normalizeText(text) {
  return (text || "").toString();
}

// Single search item model:
// {
//   kind: "reading" | "general-note" | "comment",
//   sourceId,
//   sourceName,
//   dateKey,
//   createdAt,
//   where,      // "Reading", "General note", "Comment"
//   snippet,
//   href
// }

function collectReadingItems() {
  const items = [];
  const sources = getSources();

  sources.forEach((src) => {
    if (!src.entries) return;
    for (const dateKey in src.entries) {
      const entry = src.entries[dateKey];
      if (!entry) continue;

      const texts = [
        entry.title,
        entry.passage,
        entry.body,
        entry.note,
        entry.dailyVerse && entry.dailyVerse.ref,
        entry.dailyVerse && entry.dailyVerse.text,
        entry.dailyPrayer && entry.dailyPrayer.title,
        entry.dailyPrayer && entry.dailyPrayer.text,
      ]
        .map(normalizeText)
        .join("\n");

      const d = dateKeyToDate(dateKey, currentYear);
      const y = d.getFullYear();
      const [mm, dd] = dateKey.split("-");
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

function collectGeneralNoteItems() {
  const items = [];
  for (const sourceId in notesState) {
    const perDate = notesState[sourceId];
    for (const dateKey in perDate) {
      const text = normalizeText(perDate[dateKey]);
      if (!text.trim()) continue;

      const src = findSourceById(sourceId);
      const sourceName = (src && src.name) || sourceId;

      const d = dateKeyToDate(dateKey, currentYear);
      const y = d.getFullYear();
      const [mm, dd] = dateKey.split("-");
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

function collectCommentItems() {
  const items = [];
  for (const sourceId in annotationsState) {
    const perDate = annotationsState[sourceId];
    for (const dateKey in perDate) {
      const anns = perDate[dateKey] || [];
      anns.forEach((ann) => {
        const src = findSourceById(sourceId);
        const sourceName = (src && src.name) || sourceId;

        const text = [ann.quote, ann.comment]
          .map(normalizeText)
          .join("\n");

        let createdAt = ann.createdAt;
        if (!createdAt) {
          const d = dateKeyToDate(dateKey, currentYear);
          createdAt = d.toISOString();
        }

        const d = new Date(createdAt);
        const y = d.getFullYear();
        const [mm, dd] = dateKey.split("-");
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

function searchAll(query) {
  if (!query) return [];

  const qLower = query.toLowerCase();

  const allItems = [
    ...collectReadingItems(),
    ...collectGeneralNoteItems(),
    ...collectCommentItems(),
  ];

  const matches = allItems.filter((item) =>
    item.fullText.toLowerCase().includes(qLower)
  );

  // sort newest first
  matches.sort((a, b) => {
    const da = new Date(a.createdAt).getTime();
    const db = new Date(b.createdAt).getTime();
    return db - da;
  });

  return matches.map((item) => ({
    ...item,
    snippet: makeSnippet(item.fullText, query),
  }));
}

// --- Render ---

function renderResults() {
  const q = getQuery();

  if (!q) {
    if (searchInfoEl) {
      searchInfoEl.textContent = "Enter a word or phrase to search.";
    }
    if (searchResultsEl) {
      searchResultsEl.innerHTML = "";
    }
    return;
  }

  const results = searchAll(q);

  if (searchInfoEl) {
    searchInfoEl.textContent = `${results.length} result${
      results.length === 1 ? "" : "s"
    } for “${q}”`;
  }

  if (!searchResultsEl) return;

  if (!results.length) {
    searchResultsEl.innerHTML =
      "<p>No matches found. Try a different word or phrase.</p>";
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

renderResults();
