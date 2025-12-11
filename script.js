// TODO: paste your current script.js here
// script.js

// LocalStorage keys
const NOTE_STORAGE_KEY = "devotional_notes_v1";
const HIGHLIGHT_STORAGE_KEY = "devotional_highlights_v1";
const ANNOTATION_STORAGE_KEY = "devotional_annotations_v1";

// DOM references
const datePicker = document.getElementById("datePicker");
const sourceTabs = document.getElementById("sourceTabs");

const contentTitle = document.getElementById("contentTitle");
const contentNote = document.getElementById("contentNote");

const contentMeta = document.getElementById("contentMeta");
const contentDate = document.getElementById("contentDate");
const contentBody = document.getElementById("contentBody");
const contentRef = document.getElementById("contentRef");

const prevDayBtn = document.getElementById("prevDayBtn");
const nextDayBtn = document.getElementById("nextDayBtn");

const dailyPrayerBox = document.getElementById("dailyPrayerBox");
const dailyPrayerTitle = document.getElementById("dailyPrayerTitle");
const dailyPrayerText = document.getElementById("dailyPrayerText");

const dailyVerseBox = document.getElementById("dailyVerseBox");
const dailyVerseRef = document.getElementById("dailyVerseRef");
const dailyVerseText = document.getElementById("dailyVerseText");


const notesArea = document.getElementById("notesArea");
const highlightToggle = document.getElementById("highlightToggle");
const readerSection = document.querySelector(".reader");
const yearSpan = document.getElementById("year");

const exportBtn = document.getElementById("exportBtn");
const importInput = document.getElementById("importInput");
const addCommentFromSelectionBtn = document.getElementById("addCommentFromSelectionBtn");
const annotationsList = document.getElementById("annotationsList");

const dictPopup = document.getElementById("dictPopup");
const dictPopupWord = document.getElementById("dictPopupWord");
const dictPopupBody = document.getElementById("dictPopupBody");


if (yearSpan) {
  yearSpan.textContent = new Date().getFullYear();
}

function setDatePickerFromDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  const value = `${y}-${m}-${d}`;

  datePicker.value = value;

  // make sure existing logic runs (render, notes, etc.)
  const event = new Event("change");
  datePicker.dispatchEvent(event);
}

if (prevDayBtn) {
  prevDayBtn.addEventListener("click", () => {
    const current = getDateFromPicker();   // you already have this function
    current.setDate(current.getDate() - 1);
    setDatePickerFromDate(current);
  });
}

if (nextDayBtn) {
  nextDayBtn.addEventListener("click", () => {
    const current = getDateFromPicker();
    current.setDate(current.getDate() + 1);
    setDatePickerFromDate(current);
  });
}

// Comment form DOM (new)
const annotationForm = document.getElementById("annotationForm");
const annotationSelectedText = document.getElementById("annotationSelectedText");
const annotationCommentInput = document.getElementById("annotationCommentInput");
const annotationSaveBtn = document.getElementById("annotationSaveBtn");
const annotationCancelBtn = document.getElementById("annotationCancelBtn");

// Voice memo DOM
const startVoiceBtn = document.getElementById("startVoiceBtn");
const stopVoiceBtn = document.getElementById("stopVoiceBtn");
const voiceStatus = document.getElementById("voiceStatus");
const voicePreview = document.getElementById("voicePreview");

// Pending state while form is open
let pendingAnnotationId = null;
let pendingAnnotationQuote = null;

// Recording state
let mediaRecorder = null;
let recordedChunks = [];
let pendingVoiceBlob = null;

// --- detect if localStorage is usable (browsers may block it on file://) ---
let CAN_USE_LOCAL_STORAGE = true;
try {
  const testKey = "__ls_test__";
  window.localStorage.setItem(testKey, "1");
  window.localStorage.removeItem(testKey);
} catch (e) {
  console.warn("localStorage not available, falling back to in-memory only.", e);
  CAN_USE_LOCAL_STORAGE = false;
}

// ---Add blob → base64 converter
function blobToBase64(blob) {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result.split(",")[1]); // strip prefix
    reader.readAsDataURL(blob);
  });
}

function base64ToBlob(base64, type = "audio/webm") {
  const byteCharacters = atob(base64);
  const byteNumbers = new Array(byteCharacters.length)
    .fill(0)
    .map((_, i) => byteCharacters.charCodeAt(i));
  const byteArray = new Uint8Array(byteNumbers);
  return new Blob([byteArray], { type });
}


// --- localStorage helpers ---

function cleanSelectedWord(str) {
  return (str || "")
    .trim()
    .toLowerCase()
    .replace(/^[^a-z]+|[^a-z]+$/g, ""); // strip punctuation around word
}

function hideDictPopup() {
  if (!dictPopup) return;
  dictPopup.hidden = true;
}

async function lookupWord(word) {
  // Free public dictionary API
  const url = `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error("Not found");
  return res.json();
}

function positionPopupNearSelection() {
  if (!dictPopup) return;

  const sel = window.getSelection();
  if (!sel || sel.rangeCount === 0) return;

  const range = sel.getRangeAt(0);
  const rect = range.getBoundingClientRect();

  // position below selection, account for scroll
  const top = rect.bottom + window.scrollY + 6;
  const left = rect.left + window.scrollX;

  dictPopup.style.top = `${top}px`;
  dictPopup.style.left = `${left}px`;
}

// Double-click to define a word in the reading
if (contentBody) {
  contentBody.addEventListener("dblclick", async () => {
    const sel = window.getSelection();
    if (!sel) return;
    const raw = sel.toString();
    const word = cleanSelectedWord(raw);

    if (!word) return;

    // show popup immediately with loading
    dictPopupWord.textContent = word;
    dictPopupBody.innerHTML = "<small>Looking up…</small>";
    dictPopup.hidden = false;
    positionPopupNearSelection();

    try {
      const data = await lookupWord(word);

      // build a neat display
      const entry = data[0];
      const phonetic = entry.phonetic || "";
      const meanings = entry.meanings || [];

      let html = "";
      if (phonetic) {
        html += `<div><small>${phonetic}</small></div>`;
      }

      meanings.slice(0, 2).forEach((m) => {
        html += `<div style="margin-top:6px;"><strong>${m.partOfSpeech}</strong></div>`;
        (m.definitions || []).slice(0, 2).forEach((d, i) => {
          html += `<div>${i + 1}. ${d.definition}</div>`;
          if (d.example) {
            html += `<div><small>e.g. “${d.example}”</small></div>`;
          }
        });
      });

      dictPopupBody.innerHTML = html || "<small>No definition available.</small>";
      positionPopupNearSelection();
    } catch (e) {
      dictPopupBody.innerHTML =
        "<small>Sorry, I couldn’t find a definition for that word.</small>";
    }
  });
}

// Click anywhere outside the popup to close it
document.addEventListener("click", (e) => {
  if (!dictPopup) return;
  if (dictPopup.hidden) return;
  if (!dictPopup.contains(e.target)) hideDictPopup();
});

// Also hide on Escape
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") hideDictPopup();
});


function loadJSON(key, fallback) {
  if (!CAN_USE_LOCAL_STORAGE) return fallback;
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return fallback;
    return JSON.parse(raw);
  } catch (e) {
    console.warn("Failed to parse localStorage for", key, e);
    return fallback;
  }
}

function saveJSON(key, value) {
  if (!CAN_USE_LOCAL_STORAGE) return;
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.warn("Failed to save to localStorage for", key, e);
  }
}

// notesState: { [sourceId]: { [dateKey]: "note text" } }
let notesState = loadJSON(NOTE_STORAGE_KEY, {});

// highlightState: { [sourceId]: { [dateKey]: { highlighted: true } } }
let highlightState = loadJSON(HIGHLIGHT_STORAGE_KEY, {});

// annotationsState: { [sourceId]: { [dateKey]: [ {id, quote, comment, createdAt} ] } }
let annotationsState = loadJSON(ANNOTATION_STORAGE_KEY, {});


// --- IndexedDB for voice memos (persistent local storage) ---
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

async function saveVoiceMemo(key, blob) {
  const db = await openVoiceDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(DB_STORE, "readwrite");
    tx.objectStore(DB_STORE).put(blob, key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
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

async function deleteVoiceMemo(key) {
  const db = await openVoiceDB();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(DB_STORE, "readwrite");
    tx.objectStore(DB_STORE).delete(key);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}


// --- date helpers ---

function toDateKey(date) {
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${m}-${d}`;
}

function getTodayDateInputValue() {
  const today = new Date();
  const y = today.getFullYear();
  const m = String(today.getMonth() + 1).padStart(2, "0");
  const d = String(today.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function getDateFromPicker() {
  if (!datePicker || !datePicker.value) {
    return new Date();
  }
  const [year, month, day] = datePicker.value.split("-").map(Number);
  return new Date(year, month - 1, day);
}

function formatDateForDisplay(date) {
  return date.toLocaleDateString(undefined, {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

// --- source + entry helpers ---

function findSourceById(sourceId) {
  return (DEVOTIONAL_SOURCES || []).find((s) => s.id === sourceId) || null;
}

function getEntry(sourceId, dateKey) {
  const source = findSourceById(sourceId);
  if (!source || !source.entries) return null;
  return source.entries[dateKey] || null;
}

function isHighlighted(sourceId, dateKey) {
  return !!(
    highlightState[sourceId] &&
    highlightState[sourceId][dateKey] &&
    highlightState[sourceId][dateKey].highlighted
  );
}

function toggleHighlight(sourceId, dateKey) {
  if (!highlightState[sourceId]) {
    highlightState[sourceId] = {};
  }
  const current = isHighlighted(sourceId, dateKey);
  highlightState[sourceId][dateKey] = { highlighted: !current };
  saveJSON(HIGHLIGHT_STORAGE_KEY, highlightState);
}

function getNote(sourceId, dateKey) {
  if (!notesState[sourceId]) return "";
  return notesState[sourceId][dateKey] || "";
}

function setNote(sourceId, dateKey, text) {
  if (!notesState[sourceId]) {
    notesState[sourceId] = {};
  }
  notesState[sourceId][dateKey] = text;
  saveJSON(NOTE_STORAGE_KEY, notesState);
}

function getAnnotations(sourceId, dateKey) {
  if (!annotationsState[sourceId]) return [];
  return annotationsState[sourceId][dateKey] || [];
}

function setAnnotations(sourceId, dateKey, list) {
  if (!annotationsState[sourceId]) {
    annotationsState[sourceId] = {};
  }
  annotationsState[sourceId][dateKey] = list;
  saveJSON(ANNOTATION_STORAGE_KEY, annotationsState);
}

// --- app state ---

let currentSourceId =
  (DEVOTIONAL_SOURCES && DEVOTIONAL_SOURCES[0] && DEVOTIONAL_SOURCES[0].id) ||
  null;
let currentDateKey = null;

// --- UI builders ---

function buildSourceTabs() {
  if (!sourceTabs || !Array.isArray(DEVOTIONAL_SOURCES)) return;

  sourceTabs.innerHTML = "";

  DEVOTIONAL_SOURCES.forEach((source) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "source-tab";
    btn.textContent = source.name;
    btn.dataset.sourceId = source.id;

    if (source.id === currentSourceId) {
      btn.classList.add("active");
    }

    btn.addEventListener("click", () => {
      currentSourceId = source.id;
      updateActiveTab();
      render();
    });

    sourceTabs.appendChild(btn);
  });
}

function updateActiveTab() {
  if (!sourceTabs) return;
  const buttons = sourceTabs.querySelectorAll(".source-tab");
  buttons.forEach((btn) => {
    const isActive = btn.dataset.sourceId === currentSourceId;
    btn.classList.toggle("active", isActive);
  });
}

// --- annotations DOM helpers ---

// Walk text nodes and wrap the first match of given text with a mark element
function wrapFirstMatchInBody(root, text, annId) {
  if (!text || !root) return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
  let node;
  while ((node = walker.nextNode())) {
    const idx = node.data.indexOf(text);
    if (idx !== -1) {
      const range = document.createRange();
      range.setStart(node, idx);
      range.setEnd(node, idx + text.length);

      const mark = document.createElement("mark");
      mark.setAttribute("data-annotation-id", annId);
      range.surroundContents(mark);
      return;
    }
  }
}

// Render annotations list under the text
function renderAnnotationsList(sourceId, dateKey) {
  if (!annotationsList) return;
  annotationsList.innerHTML = "";
  const anns = getAnnotations(sourceId, dateKey);
  if (!anns.length) return;

  anns.forEach((ann) => {
    const li = document.createElement("li");
    li.className = "annotation-item";
    li.dataset.annotationId = ann.id;

    const quoteDiv = document.createElement("div");
    quoteDiv.className = "annotation-quote";
    quoteDiv.textContent = `“${ann.quote}”`;

    const commentP = document.createElement("p");
    commentP.className = "annotation-comment";
    commentP.innerHTML = ann.comment || "(no comment)";
  
    const metaP = document.createElement("p");
    metaP.className = "annotation-meta";
    const dateStr = ann.createdAt
      ? new Date(ann.createdAt).toLocaleString()
      : "";
    metaP.textContent = dateStr ? `Added on ${dateStr}` : "";

    const removeBtn = document.createElement("button");
    removeBtn.className = "annotation-remove-btn";
    removeBtn.type = "button";
    removeBtn.textContent = "Remove";
    removeBtn.addEventListener("click", () => {
      removeAnnotation(sourceId, dateKey, ann.id);
    });

    metaP.appendChild(removeBtn);

    li.appendChild(quoteDiv);
    li.appendChild(commentP);
    
    // If annotation has a voice memo, render player
if (ann.voiceKey) {
  const audio = document.createElement("audio");
  audio.controls = true;
  audio.style.width = "100%";
  audio.style.marginTop = "0.35rem";
  li.appendChild(audio);

  loadVoiceMemo(ann.voiceKey).then((blob) => {
    if (blob) {
      audio.src = URL.createObjectURL(blob);
    } else {
      audio.replaceWith(document.createTextNode("(voice memo missing)"));
    }
  });
}


    li.appendChild(metaP);
    annotationsList.appendChild(li);
  });
}

// Remove annotation by id
function removeAnnotation(sourceId, dateKey, annId) {
  const list = getAnnotations(sourceId, dateKey);
  const removed = list.find(a => a.id === annId);
  const filtered = list.filter((a) => a.id !== annId);

  setAnnotations(sourceId, dateKey, filtered);

  if (removed?.voiceKey) {
    deleteVoiceMemo(removed.voiceKey).catch(console.error);
  }

  render();
}

// Apply stored annotations as <mark> in the body
function applyAnnotationsToBody(sourceId, dateKey) {
  const anns = getAnnotations(sourceId, dateKey);
  if (!anns.length || !contentBody) return;

  anns.forEach((ann) => {
    wrapFirstMatchInBody(contentBody, ann.quote, ann.id);
  });
}

// --- rendering ---

function render() {
  const date = getDateFromPicker();
  currentDateKey = toDateKey(date);

  const source = currentSourceId ? findSourceById(currentSourceId) : null;
  const entry = source ? getEntry(source.id, currentDateKey) : null;

  if (!source) {
    contentTitle.textContent = "Choose a devotional";
    contentMeta.textContent =
      "Select a devotional source above to start reading.";
    contentDate.textContent = "";
    contentBody.innerHTML =
      "<p>Use the tabs at the top to switch between different devotional sources.</p>";
    contentRef.innerHTML = "";
    highlightToggle.hidden = true;
    readerSection.classList.remove("is-highlighted");
    notesArea.value = "";
    annotationsList.innerHTML = "";
    return;
  }

  contentMeta.textContent = `${source.name} · ${source.author || ""}`.trim();
  contentDate.textContent = formatDateForDisplay(date);

  if (!entry) {
    contentTitle.textContent = "No entry for this date";
    contentBody.innerHTML =
      "<p>There is no devotional entry stored for this date.</p>";
    contentRef.innerHTML = "";
    highlightToggle.hidden = true;
    readerSection.classList.remove("is-highlighted");
    annotationsList.innerHTML = "";
  } else {
    contentTitle.textContent = entry.title || source.name || "Devotional";
    contentNote.textContent = entry.note || "";
    const bodyHtml = (entry.body || "").replace(/\n/g, "<br>");
    contentBody.innerHTML = bodyHtml;
    contentRef.innerHTML = entry.passage ? `${entry.passage}` : "";

    // Apply annotations as highlighted marks
    applyAnnotationsToBody(source.id, currentDateKey);

    const highlighted = isHighlighted(source.id, currentDateKey);
    readerSection.classList.toggle("is-highlighted", highlighted);
    highlightToggle.hidden = false;
    highlightToggle.textContent = highlighted
      ? "★ Highlighted reading"
      : "☆ All markings removed";

    // Render annotations list
    renderAnnotationsList(source.id, currentDateKey);
  }
  
// --- Daily Verse block ---
if (dailyVerseBox && dailyVerseRef && dailyVerseText) {



  if (entry && entry.dailyVerse) {
    const verse = entry.dailyVerse;
    dailyVerseBox.hidden = false;

   if (typeof verse === "string") {
      dailyVerseRef.textContent = "Daily Verse";
      dailyVerseText.textContent = verse;
    } else {
      dailyVerseRef.textContent = verse.ref || "";
      dailyVerseText.textContent = verse.text || "";
    }
    
    if (verse.text=="") {dailyVerseBox.hidden = true;}  
    
  }
}

// --- Daily Prayer block (end of reading) ---
if (dailyPrayerBox && dailyPrayerTitle && dailyPrayerText) {
  dailyPrayerBox.hidden = true;


  if (entry && entry.dailyPrayer) {
    const prayer = entry.dailyPrayer;

    dailyPrayerBox.hidden = false;

    if (typeof prayer === "string") {
      dailyPrayerTitle.textContent = "Daily Prayer";
      dailyPrayerText.innerHTML = prayer;
    } else {
      dailyPrayerTitle.textContent = prayer.title || "";
      dailyPrayerText.innerHTML = prayer.text || "";
    }
    if (prayer.text=="") {dailyPrayerBox.hidden  = true;}
  }
}



  notesArea.value = getNote(source.id, currentDateKey);
}

// --- export/import helpers ---

function downloadJSON(filename, data) {
  const json = JSON.stringify(data, null, 2);
  const blob = new Blob([json], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}


function downloadFile(filename, text) {
  const blob = new Blob([text], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function handleExport() {
  const payload = {
    notesState,
    highlightState,
    annotationsState,
  };
  const json = JSON.stringify(payload, null, 2);
  downloadFile("devotional-notes-comments-highlights.json", json);
}

function handleImportFile(file) {
  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const data = JSON.parse(e.target.result);
      if (data.notesState && typeof data.notesState === "object") {
        notesState = data.notesState;
        saveJSON(NOTE_STORAGE_KEY, notesState);
      }
      if (data.highlightState && typeof data.highlightState === "object") {
        highlightState = data.highlightState;
        saveJSON(HIGHLIGHT_STORAGE_KEY, highlightState);
      }
      if (data.annotationsState && typeof data.annotationsState === "object") {
        annotationsState = data.annotationsState;
        saveJSON(ANNOTATION_STORAGE_KEY, annotationsState);
      }
      render();
      alert("Notes, comments, and highlights imported.");
    } catch (err) {
      console.error("Failed to import JSON", err);
      alert("Import failed: invalid JSON file.");
    }
  };
  reader.readAsText(file);
}

// --- events ---

function initDatePicker() {
  if (!datePicker) return;
  if (!datePicker.value) {
    datePicker.value = getTodayDateInputValue();
  }
  datePicker.addEventListener("change", () => {
    render();
  });
}

if (notesArea) {
  notesArea.addEventListener("input", () => {
    if (!currentSourceId || !currentDateKey) return;
    setNote(currentSourceId, currentDateKey, notesArea.value);
  });
}

if (highlightToggle) {
  highlightToggle.addEventListener("click", () => {
    if (!currentSourceId || !currentDateKey) return;
    toggleHighlight(currentSourceId, currentDateKey);
    render();
  });
}

if (exportBtn) {
  exportBtn.addEventListener("click", async () => {
    const payload = {
      notesState,
      annotationsState,
      highlightState,
      voiceMemos: {} // NEW
    };

    // Collect all voice keys
    const allVoiceKeys = [];

    for (const srcId in annotationsState) {
      for (const dateKey in annotationsState[srcId]) {
        for (const ann of annotationsState[srcId][dateKey]) {
          if (ann.voiceKey) {
            allVoiceKeys.push(ann.voiceKey);
          }
        }
      }
    }

    // Load and convert each blob
    for (const key of allVoiceKeys) {
      const blob = await loadVoiceMemo(key);
      if (blob) {
        const base64 = await blobToBase64(blob);
        payload.voiceMemos[key] = {
          base64,
          type: blob.type || "audio/webm"
        };
      }
    }

    // Download full JSON
    downloadJSON("devotional_backup_with_audio.json", payload);
  });
}


if (importInput) {
  importInput.addEventListener("change", async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const payload = JSON.parse(text);



    if (payload.annotationsState) {
      annotationsState = payload.annotationsState;
     saveJSON(ANNOTATION_STORAGE_KEY, annotationsState);
    }

      if (payload.highlightState) {
        highlightState = payload.highlightState;
        saveJSON(HIGHLIGHT_STORAGE_KEY, highlightState);
      }

      // Restore voice memos
      if (payload.voiceMemos) {
        for (const key in payload.voiceMemos) {
          const { base64, type } = payload.voiceMemos[key];
          const blob = base64ToBlob(base64, type);
          await saveVoiceMemo(key, blob);
        }
      }

      render();
      alert("Import complete (including voice memos)!");
    } catch (err) {
      console.error(err);
      alert("Import failed. Please check the JSON file.");
    } finally {
      importInput.value = "";
    }
  });
}

if (startVoiceBtn) {
  startVoiceBtn.addEventListener("click", async () => {
    pendingVoiceBlob = null;
    recordedChunks = [];

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

      mediaRecorder = new MediaRecorder(stream);
      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) recordedChunks.push(e.data);
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(recordedChunks, { type: "audio/webm" });
        pendingVoiceBlob = blob;

        if (voicePreview) {
          voicePreview.src = URL.createObjectURL(blob);
          voicePreview.hidden = false;
        }
        if (voiceStatus) voiceStatus.textContent = "Recorded ✓";

        stream.getTracks().forEach((t) => t.stop());
      };

      mediaRecorder.start();

      if (voiceStatus) voiceStatus.textContent = "Recording…";
      startVoiceBtn.disabled = true;
      if (stopVoiceBtn) stopVoiceBtn.disabled = false;

      if (voicePreview) {
        voicePreview.hidden = true;
        voicePreview.src = "";
      }
    } catch (err) {
      console.error(err);
      alert("Microphone access denied or unavailable.");
    }
  });
}

if (stopVoiceBtn) {
  stopVoiceBtn.addEventListener("click", () => {
    if (mediaRecorder && mediaRecorder.state !== "inactive") {
      mediaRecorder.stop();
    }
    stopVoiceBtn.disabled = true;
    if (startVoiceBtn) startVoiceBtn.disabled = false;
    if (voiceStatus) voiceStatus.textContent = "Stopping…";
  });
}

if (annotationSaveBtn) {
  annotationSaveBtn.addEventListener("click", async () => {
    if (!currentSourceId || !currentDateKey) return;
    if (!pendingAnnotationId || !pendingAnnotationQuote) {
      alert("No selection to comment on.");
      return;
    }

    const commentText = (annotationCommentInput?.value || "").trim();

    // Save voice memo (if any) in IndexedDB
    let voiceKey = null;
    if (pendingVoiceBlob) {
      voiceKey = `voice-${pendingAnnotationId}`;
      try {
        await saveVoiceMemo(voiceKey, pendingVoiceBlob);
      } catch (e) {
        console.error(e);
        alert("Could not save voice memo.");
        voiceKey = null;
      }
    }

    const list = getAnnotations(currentSourceId, currentDateKey).slice();
    list.push({
      id: pendingAnnotationId,
      quote: pendingAnnotationQuote,
      comment: commentText,
      createdAt: new Date().toISOString(),
      voiceKey
    });
    setAnnotations(currentSourceId, currentDateKey, list);

    // Clear + hide form
    pendingAnnotationId = null;
    pendingAnnotationQuote = null;
    pendingVoiceBlob = null;
    if (annotationForm) annotationForm.hidden = true;

    render();
  });
}

if (annotationCancelBtn) {
  annotationCancelBtn.addEventListener("click", () => {
    pendingAnnotationId = null;
    pendingAnnotationQuote = null;
    pendingVoiceBlob = null;
    if (annotationForm) annotationForm.hidden = true;
  });
}

// Handle "Add comment from selection"
if (addCommentFromSelectionBtn) {
  addCommentFromSelectionBtn.addEventListener("click", () => {
    if (!currentSourceId || !currentDateKey) return;
    if (!contentBody) return;

    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0) {
      alert("Please select some text in the reading first.");
      return;
    }

    const range = selection.getRangeAt(0);
    if (!contentBody.contains(range.commonAncestorContainer)) {
      alert("Please select text inside the reading area.");
      return;
    }

    const selectedText = selection.toString().trim();
    if (!selectedText) {
      alert("Selection is empty. Please highlight some text.");
      return;
    }

    // Create annotation id + store pending values
    pendingAnnotationId =
      Date.now().toString() + "-" + Math.random().toString(16).slice(2);
    pendingAnnotationQuote = selectedText;

    // Wrap selection immediately for visual highlight
    const mark = document.createElement("mark");
    mark.setAttribute("data-annotation-id", pendingAnnotationId);
    try {
      range.surroundContents(mark);
    } catch (e) {
      console.warn(
        "Could not surround selection. Will re-apply on render via text match.",
        e
      );
    }
    selection.removeAllRanges();

    // Show form
    if (annotationForm && annotationSelectedText && annotationCommentInput) {
      annotationSelectedText.textContent = `“${selectedText}”`;
      annotationCommentInput.value = "";
      annotationForm.hidden = false;
      annotationCommentInput.focus();
    }

    // Reset voice UI for new comment
    pendingVoiceBlob = null;
    recordedChunks = [];
    if (voicePreview) {
      voicePreview.hidden = true;
      voicePreview.src = "";
    }
    if (voiceStatus) voiceStatus.textContent = "";
    if (startVoiceBtn) startVoiceBtn.disabled = false;
    if (stopVoiceBtn) stopVoiceBtn.disabled = true;
  });
}

// --- init ---

(function init() {
  if (!Array.isArray(DEVOTIONAL_SOURCES) || DEVOTIONAL_SOURCES.length === 0) {
    console.error("DEVOTIONAL_SOURCES is missing or empty.");
    return;
  }

  // Read URL parameters: ?source=...&date=YYYY-MM-DD
  const params = new URLSearchParams(window.location.search);
  const sourceFromUrl = params.get("source");
  const dateFromUrl = params.get("date");

  if (sourceFromUrl && findSourceById(sourceFromUrl)) {
    currentSourceId = sourceFromUrl;
  } else {
    currentSourceId =
      (DEVOTIONAL_SOURCES[0] && DEVOTIONAL_SOURCES[0].id) || null;
  }

  initDatePicker();

  if (dateFromUrl && datePicker) {
    datePicker.value = dateFromUrl;
  }

  buildSourceTabs();
  updateActiveTab();
  render();
})();
