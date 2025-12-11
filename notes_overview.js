// notes_overview.js
// Shows all notes + comments + voice memos, linked back to index.html

const NOTE_STORAGE_KEY = "devotional_notes_v1";
const HIGHLIGHT_STORAGE_KEY = "devotional_highlights_v1";
const ANNOTATION_STORAGE_KEY = "devotional_annotations_v1";

const overviewContainer = document.getElementById("notesOverviewContainer");
const yearSpan = document.getElementById("year");

// year in footer
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

// --- IndexedDB helpers (same as script.js) ---
const DB_NAME = "devotional_voice_db";
const DB_STORE = "voiceMemos";

function openVoiceDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(DB_STORE)) {
        db.createObjectStore(DB_STORE);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function loadVoiceMemo(key) {
  const db = await openVoiceDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(DB_STORE, "readonly");
    const req = tx.objectStore(DB_STORE).get(key);
    req.onsuccess = () => resolve(req.result || null);
    req.onerror = () => reject(req.error);
  });
}

// --- source lookup from data.js ---
function findSourceById(id) {
  return (window.DEVOTIONAL_SOURCES || []).find((s) => s.id === id) || null;
}

// Convert "MM-DD" + year to Date
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

// --- load all three states ---
const notesState = loadJSON(NOTE_STORAGE_KEY, {});
const annotationsState = loadJSON(ANNOTATION_STORAGE_KEY, {});
const highlightState = loadJSON(HIGHLIGHT_STORAGE_KEY, {}); // not used yet but handy later

// Build flat list of items
function collectItems() {
  const items = [];
  const currentYear = new Date().getFullYear();

  // 1) Big general notes per date
  for (const sourceId in notesState) {
    const perDate = notesState[sourceId];
    for (const dateKey in perDate) {
      const noteText = perDate[dateKey];
      if (!noteText || !noteText.trim()) continue;

      const source = findSourceById(sourceId);
      const sourceName =
        (source && source.name) ||
        (source && source.description) ||
        sourceId; // fallback to ID only if we really must

      const guessedDate = dateKeyToDate(dateKey, currentYear);

      items.push({
        type: "note",
        sourceId,
        sourceName,
        dateKey,
        createdAt: guessedDate.toISOString(),
        noteText,
      });
    }
  }

  // 2) Inline comments + voice memos
  for (const sourceId in annotationsState) {
    const perDate = annotationsState[sourceId];
    for (const dateKey in perDate) {
      const list = perDate[dateKey] || [];
      list.forEach((ann) => {
        const source = findSourceById(sourceId);
        const sourceName =
          (source && source.name) ||
          (source && source.description) ||
          sourceId;

        let createdAt = ann.createdAt;
        if (!createdAt) {
          const guessedDate = dateKeyToDate(dateKey, currentYear);
          createdAt = guessedDate.toISOString();
        }

        items.push({
          type: "comment",
          sourceId,
          sourceName,
          dateKey,
          createdAt,
          quote: ann.quote,
          comment: ann.comment,
          voiceKey: ann.voiceKey || null,
        });
      });
    }
  }

  // Sort newest first
  items.sort((a, b) => {
    const da = new Date(a.createdAt).getTime();
    const db = new Date(b.createdAt).getTime();
    return db - da;
  });

  return items;
}

async function renderOverview() {
  if (!overviewContainer) return;

  const items = collectItems();

  if (!items.length) {
    overviewContainer.innerHTML =
      "<p>You don’t have any notes or comments yet.</p>";
    return;
  }

  const list = document.createElement("div");
  list.className = "notes-overview-list";

  for (const item of items) {
    const card = document.createElement("article");
    card.className = "notes-overview-item";

    const created = new Date(item.createdAt);
    const longDate = formatLongDate(created);
    const y = created.getFullYear();
    const mmdd = item.dateKey || "01-01";
    const [mm, dd] = mmdd.split("-");
    const linkDateStr = `${y}-${mm}-${dd}`; // YYYY-MM-DD

    // link back to index.html with source + date
    const href = `index.html?source=${encodeURIComponent(
      item.sourceId
    )}&date=${encodeURIComponent(linkDateStr)}`;

    const header = document.createElement("div");
    header.className = "notes-overview-header";

    const titleLink = document.createElement("a");
    titleLink.href = href;
    titleLink.className = "notes-overview-link";
    // 👇 this is where we show the friendly devotional name
    titleLink.textContent = `${item.sourceName || "Devotional"} – ${longDate}`;

    const badge = document.createElement("span");
    badge.className = "notes-overview-type";
    badge.textContent = item.type === "note" ? "Note" : "Comment";

    header.appendChild(titleLink);
    header.appendChild(badge);

    const body = document.createElement("div");
    body.className = "notes-overview-body";

    if (item.type === "note") {
      const p = document.createElement("p");
      p.textContent = item.noteText;
      body.appendChild(p);
    } else {
      if (item.quote) {
        const quote = document.createElement("div");
        quote.className = "notes-overview-quote";
        quote.textContent = `“${item.quote}”`;
        body.appendChild(quote);
      }

      const comment = document.createElement("p");
      comment.className = "notes-overview-comment";
      comment.textContent = item.comment || "(no comment text)";
      body.appendChild(comment);

      if (item.voiceKey) {
        const audio = document.createElement("audio");
        audio.controls = true;
        audio.style.width = "100%";
        audio.style.marginTop = "0.25rem";
        body.appendChild(audio);

        loadVoiceMemo(item.voiceKey).then((blob) => {
          if (blob) {
            audio.src = URL.createObjectURL(blob);
          } else {
            audio.replaceWith(
              document.createTextNode("(voice memo missing)")
            );
          }
        });
      }
    }

    card.appendChild(header);
    card.appendChild(body);
    list.appendChild(card);
  }

  overviewContainer.innerHTML = "";
  overviewContainer.appendChild(list);
}

renderOverview();
