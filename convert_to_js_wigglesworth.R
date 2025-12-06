# ---------- Helpers ----------------------------------------------------

# "December 9" -> "12-09"
format_date_key <- function(date_str) {
  date_str <- trimws(date_str)
  parts <- strsplit(date_str, "\\s+")[[1]]
  if (length(parts) < 2) stop("Cannot parse date: ", date_str)
  month_raw <- parts[1]
  day       <- parts[2]
  
  month <- tolower(month_raw)
  month <- paste0(toupper(substr(month, 1, 1)), substr(month, 2, nchar(month)))
  
  d <- as.Date(paste(month, day, "2000"), format = "%B %d %Y")
  if (is.na(d)) stop("Cannot parse date: ", date_str)
  
  sprintf("%02d-%02d", as.integer(format(d, "%m")), as.integer(format(d, "%d")))
}

# Escape content for JS single-quoted strings
escape_js_single <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x)  # backslashes
  x <- gsub("'", "\\\\'", x)        # single quotes
  x <- gsub("\r", "", x)            # strip CR
  x <- gsub("\n", "\\\\n", x)       # newline -> \n
  x
}

# Bible.com NKJV (114) book codes
bible_book_codes <- c(
  "Genesis"="GEN","Exodus"="EXO","Leviticus"="LEV","Numbers"="NUM","Deuteronomy"="DEU",
  "Joshua"="JOS","Judges"="JDG","Ruth"="RUT",
  "1 Samuel"="1SA","2 Samuel"="2SA",
  "1 Kings"="1KI","2 Kings"="2KI",
  "1 Chronicles"="1CH","2 Chronicles"="2CH",
  "Ezra"="EZR","Nehemiah"="NEH","Esther"="EST",
  "Job"="JOB","Psalm"="PSA","Psalms"="PSA","Proverbs"="PRO","Ecclesiastes"="ECC","Song of Songs"="SNG",
  "Isaiah"="ISA","Jeremiah"="JER","Lamentations"="LAM","Ezekiel"="EZK","Daniel"="DAN",
  "Hosea"="HOS","Joel"="JOL","Amos"="AMO","Obadiah"="OBA","Jonah"="JON",
  "Micah"="MIC","Nahum"="NAM","Habakkuk"="HAB","Zephaniah"="ZEP","Haggai"="HAG","Zechariah"="ZEC","Malachi"="MAL",
  "Matthew"="MAT","Mark"="MRK","Luke"="LUK","John"="JHN","Acts"="ACT",
  "Romans"="ROM","1 Corinthians"="1CO","2 Corinthians"="2CO",
  "Galatians"="GAL","Ephesians"="EPH","Philippians"="PHP","Colossians"="COL",
  "1 Thessalonians"="1TH","2 Thessalonians"="2TH",
  "1 Timothy"="1TI","2 Timothy"="2TI","Titus"="TIT","Philemon"="PHM",
  "Hebrews"="HEB","James"="JAS","1 Peter"="1PE","2 Peter"="2PE",
  "1 John"="1JN","2 John"="2JN","3 John"="3JN","Jude"="JUD","Revelation"="REV"
)

# Normalise simple Roman numerals to Arabic (I Thessalonians -> 1 Thessalonians, etc.)
normalize_roman_book <- function(ref_str) {
  s <- ref_str
  s <- gsub("^I\\s+Thessalonians",  "1 Thessalonians",  s)
  s <- gsub("^II\\s+Thessalonians", "2 Thessalonians",  s)
  s <- gsub("^I\\s+Corinthians",    "1 Corinthians",    s)
  s <- gsub("^II\\s+Corinthians",   "2 Corinthians",    s)
  s <- gsub("^I\\s+Timothy",        "1 Timothy",        s)
  s <- gsub("^II\\s+Timothy",       "2 Timothy",        s)
  s <- gsub("^I\\s+Peter",          "1 Peter",          s)
  s <- gsub("^II\\s+Peter",         "2 Peter",          s)
  s <- gsub("^I\\s+Samuel",         "1 Samuel",         s)
  s <- gsub("^II\\s+Samuel",        "2 Samuel",         s)
  s <- gsub("^I\\s+Kings",          "1 Kings",          s)
  s <- gsub("^II\\s+Kings",         "2 Kings",          s)
  s <- gsub("^I\\s+Chronicles",     "1 Chronicles",     s)
  s <- gsub("^II\\s+Chronicles",    "2 Chronicles",     s)
  s
}

# Extract book+chapter from "I Thessalonians 5:11–24"
parse_bible_ref <- function(ref_str) {
  ref_str <- normalize_roman_book(ref_str)
  ref_str <- trimws(ref_str)
  m <- regexec("^([0-9]?[A-Za-z ]+?)\\s+([0-9]+):", ref_str)
  mm <- regmatches(ref_str, m)[[1]]
  if (length(mm) < 3) return(NULL)
  list(book = trimws(mm[2]), chapter = trimws(mm[3]))
}

# Build HTML "Scripture reading" line
build_passage_html <- function(passage_line) {
  m <- regexec("^([^:]+:)(\\s*)(.+)$", passage_line)
  mm <- regmatches(passage_line, m)[[1]]
  if (length(mm) < 4) return(escape_js_single(passage_line))  # fallback
  
  prefix <- trimws(mm[2])  # "Scripture reading:"
  ref    <- trimws(mm[4])  # e.g. "I Thessalonians 5:11–24"
  
  parsed <- parse_bible_ref(ref)
  if (is.null(parsed)) {
    return(escape_js_single(passage_line))
  }
  
  book_code <- bible_book_codes[parsed$book]
  if (is.na(book_code)) {
    return(escape_js_single(passage_line))
  }
  
  url <- sprintf("https://www.bible.com/bible/114/%s.%s.NKJV?parallel=151",
                 book_code, parsed$chapter)
  
  html <- sprintf('%s <a href="%s">%s</a>', prefix, url, ref)
  escape_js_single(html)
}

# Heuristic: try to guess & restore missing first letter of body text
guess_fix_body_start <- function(body_text) {
  # Typical OCR: leading "n " should be "In "
  if (grepl("^n\\b", body_text)) {
    return(sub("^n", "In", body_text))
  }
  # A few extra guesses (t -> It, f -> If, nd -> And, he -> The)
  if (grepl("^t\\b", body_text))  return(sub("^t",  "It",  body_text))
  if (grepl("^f\\b", body_text))  return(sub("^f",  "If",  body_text))
  if (grepl("^nd\\b", body_text)) return(sub("^nd", "And", body_text))
  if (grepl("^he\\b", body_text)) return(sub("^he", "The", body_text))
  body_text
}

# ---------- Main: one JS file per date ---------------------------------

convert_wigglesworth_devotions_to_js_files <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_wigglesworth.js"  # e.g. "12-09.js"
) {
  lines   <- readLines(input_path, warn = FALSE, encoding = "UTF-8")
  lines   <- gsub("\u00A0", " ", lines, fixed = TRUE)
  trimmed <- trimws(lines)
  n       <- length(lines)
  
  # Date lines like "December 9"
  is_date_line <- grepl("^[A-Za-z]+\\s+[0-9]{1,2}$", trimmed)
  date_idx     <- which(is_date_line)
  if (!length(date_idx)) stop("No date lines found.")
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  idx_with_sentinel <- c(date_idx, n + 1)
  
  for (k in seq_along(date_idx)) {
    start <- idx_with_sentinel[k]
    end  <- idx_with_sentinel[k + 1] - 1
    if (k< length(idx_with_sentinel)) {if(trimmed[start]==trimmed[idx_with_sentinel[k + 1]]) {end<-idx_with_sentinel[k + 2] - 1 }}
    
    block_trim <- trimmed[start:end]
    block_raw  <- lines[start:end]
    
    nonempty_idx <- which(block_trim != "")
    if (length(nonempty_idx) < 6) next
    
    # Date, title, note
    idx_date  <- nonempty_idx[1]
    idx_title <- nonempty_idx[2]
    idx_note  <- nonempty_idx[3]
    
    date_line  <- block_trim[idx_date]
    title_line <- block_trim[idx_title]
    note_line  <- block_trim[idx_note]
    
    key <- format_date_key(date_line)
    
    # Verse ref: first line after note starting with dash / em dash
    dash_idx <- which(grepl("^[-—]", block_trim))
    dash_idx <- dash_idx[dash_idx > idx_note]
    if (!length(dash_idx)) next
    idx_verse_ref <- dash_idx[1]
    
    verse_ref_line <- sub("^[-—]\\s*", "", block_trim[idx_verse_ref])
    
    # Verse text = lines between note and verse ref
    verse_range <- seq(idx_note + 1, idx_verse_ref - 1)
    verse_lines <- block_trim[verse_range]
    verse_lines <- verse_lines[verse_lines != ""]
    verse_text  <-  verse_lines[2]#paste(verse_lines, collapse = " ")
    
    # Scripture reading line
    idx_script <- which(grepl("^Scripture reading:", block_trim, ignore.case = TRUE))
    idx_script <- idx_script[idx_script > idx_verse_ref]
    if (!length(idx_script)) next
    idx_script <- idx_script[1]
    
    passage_line <- block_trim[idx_script]
    passage_js   <- build_passage_html(passage_line)
    
    # Thought for today
    idx_thought <- which(grepl("^Thought for today:", block_trim, ignore.case = TRUE))
    if (!length(idx_thought)) next
    idx_thought <- idx_thought[1]
    
    thought_line <- block_trim[idx_thought]
    m  <- regexec("^([^:]+):\\s*(.+)$", thought_line)
    mm <- regmatches(thought_line, m)[[1]]
    if (length(mm) < 3) next
    
    prayer_title <- mm[2]  # "Thought for today"
    prayer_text  <- mm[3]  # text after colon
    
    # Body = lines between Scripture reading and Thought for today
    body_start <- idx_script + 1
    body_end   <- idx_thought - 1
    
    if (body_start > body_end) {
      body_text <- ""
    } else {
      body_block <- block_raw[body_start:body_end]
      
      
      # Delete date line within body text
      # Date lines like "December 9"
      is_date_line_body <- grepl("^[A-Za-z]+\\s+[0-9]{1,2} +$", body_block)
      is_page_number <- grepl("^[0-9]{1,4} +$", body_block)
      body_block    <- body_block[!is_date_line_body&!is_page_number]
      body_trim  <- trimws(body_block)

      # Build paragraphs: group non-empty lines separated by blank lines
      paras <- list()
      cur   <- character()
      for (i in seq_along(body_trim)) {
        if (body_trim[i] == "") {
          if (length(cur)) {
            paras[[length(paras) + 1]] <- cur
            cur <- character()
          }
        } else {
          cur <- c(cur, body_trim[i])
        }
      }
      if (length(cur)) paras[[length(paras) + 1]] <- cur
      
      para_texts <- vapply(paras, function(p) paste(p, collapse = " "), character(1))
      body_text  <- paste(para_texts, collapse = "\n\n")
      
      # Guess & fix missing first letter
      body_text <- guess_fix_body_start(body_text)
    }
    
    # Escape for JS
    title_js        <- escape_js_single(title_line)
    note_js         <- escape_js_single(note_line)
    verse_text_js   <- escape_js_single(verse_text)
    verse_ref_js    <- escape_js_single(verse_ref_line)
    body_js         <- escape_js_single(body_text)
    prayer_title_js <- escape_js_single(prayer_title)
    prayer_text_js  <- escape_js_single(prayer_text)
    
    # Build JS for this single date
    js_lines <- c(

      paste0('  "', key, '": {'),
      paste0('    "title": \'',   title_js,       '\','),
      paste0('    "note": \'',    note_js,        '\','),
      paste0('    "passage": \'', passage_js,     '\','),
      '    "dailyVerse": {',
      paste0('      "ref": \'',   verse_ref_js,   '\','),
      paste0('      "text": \'',  verse_text_js,  '\''),
      '    },',
      paste0('    "body": \'',    body_js,        '\','),
      '    "dailyPrayer": {',
      paste0('      "title": \'', prayer_title_js,'\','),
      paste0('      "text": \'',  prayer_text_js, '\''),
      '    }',
      "}"
    )
    
    file_name <- gsub("\\{KEY\\}", key, filename_template)
    out_path  <- file.path(output_dir, file_name)
    
    writeLines(js_lines, out_path, useBytes = TRUE)
    message("Wrote: ", out_path)
  }
}

# ---------- Example usage ----------------------------------------------
# convert_yield_devotions_to_js_files(
#   input_path = "yield-to-the-holy-spirit.txt",
#   output_dir = "js-devotions"
# )
# -> creates files like:
#    js-devotions/12-09.js
