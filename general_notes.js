// general_notes.js
// Show all "My General Notes" (big textarea) and link back to index.html

const NOTE_STORAGE_KEY = "devotional_notes_v1";
const generalNotesContainer = document.getElementById("generalNotesContainer");
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

// notesState: { [sourceId]: { [dateKey "MM-DD"]: "note text" } }
const notesState = loadJSON(NOTE_STORAGE_KEY, {});

// Get source metadata from DEVOTIONAL_SOURCES
function getSources() {
  try {
    // Use the global const from data.js
    return Array.isArray(DEVOTIONAL_SOURCES) ? DEVOTIONAL_SOURCES : [];
  } catch {
    return [];
  }
}

function findSourceById(id) {
  return getSources().find((s) => s.id === id) || null;
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

// Build flat list of notes
function collectGeneralNotes() {
  const items = [];
  const currentYear = new Date().getFullYear();

  for (const sourceId in notesState) {
    const perDate = notesState[sourceId];
    for (const dateKey in perDate) {
      const text = perDate[dateKey];
      if (!text || !text.trim()) continue;

      const source = findSourceById(sourceId);
      const sourceName = source ? source.name : sourceId;

      const guessedDate = dateKeyToDate(dateKey, currentYear);

      items.push({
        sourceId,
        sourceName,
        dateKey,
        noteText: text,
        createdAt: guessedDate.toISOString(),
      });
    }
  }

  // Sort newest first by guessed date
  items.sort((a, b) => {
    const da = new Date(a.createdAt).getTime();
    const db = new Date(b.createdAt).getTime();
    return db - da;
  });

  return items;
}

function renderGeneralNotes() {
  if (!generalNotesContainer) return;

  const items = collectGeneralNotes();

  if (!items.length) {
    generalNotesContainer.innerHTML =
      "<p>You don’t have any general notes yet.</p>";
    return;
  }

  const list = document.createElement("div");
  list.className = "notes-overview-list";

  items.forEach((item) => {
    const card = document.createElement("article");
    card.className = "notes-overview-item";

    const created = new Date(item.createdAt);
    const longDate = formatLongDate(created);
    const y = created.getFullYear();
    const [mm, dd] = item.dateKey.split("-");
    const linkDateStr = `${y}-${mm}-${dd}`; // YYYY-MM-DD

    // Link goes back to index.html with source + date
    const href = `index.html?source=${encodeURIComponent(
      item.sourceId
    )}&date=${encodeURIComponent(linkDateStr)}`;

    const header = document.createElement("div");
    header.className = "notes-overview-header";

    const dateLink = document.createElement("a");
    dateLink.href = href;
    dateLink.className = "notes-overview-link";
    dateLink.textContent = longDate;

    const sourceSpan = document.createElement("span");
    sourceSpan.className = "notes-overview-type";
    sourceSpan.textContent = item.sourceName || "Devotional";
    
    // 🔍 show description when hovering the devotional name
    const src = findSourceById(item.sourceId);
    if (src && src.description) {
     sourceSpan.title = src.description;
    }

    header.appendChild(dateLink);
    header.appendChild(sourceSpan);

    const body = document.createElement("div");
    body.className = "notes-overview-body";

    const p = document.createElement("p");
    p.textContent = item.noteText;
    body.appendChild(p);

    card.appendChild(header);
    card.appendChild(body);
    list.appendChild(card);
  });

  generalNotesContainer.innerHTML = "";
  generalNotesContainer.appendChild(list);
}

renderGeneralNotes();
