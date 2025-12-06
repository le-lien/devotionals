# --- Helpers -----------------------------------------------------------

format_date_key <- function(date_str) {
  # "DECEMBER 9" -> "12-09"
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

escape_js_single <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x)  # backslashes
  x <- gsub("'", "\\\\'", x)        # single quotes
  x <- gsub("\r", "", x)            # remove CR
  x <- gsub("\n", "\\\\n", x)       # newline -> \n
  x
}

# Bible book -> code for Bible.com (114/NKJV)
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

# Extract book+chapter from "2 Kings 6:8–17" -> list(book="2 Kings", chapter="6")
parse_bible_ref <- function(ref_str) {
  ref_str <- trimws(ref_str)
  m <- regexec("^([0-9]?[A-Za-z ]+?)\\s+([0-9]+):", ref_str)
  mm <- regmatches(ref_str, m)[[1]]
  if (length(mm) < 3) return(NULL)
  list(book = trimws(mm[2]), chapter = trimws(mm[3]))
}

# Turn "For further study ... 2 Kings 6:8–17" into
# 'For further study ... <a href="https://www.bible.com/bible/114/2KI.6.NKJV?parallel=151">2 Kings 6:8–17</a>'
build_passage_html <- function(passage_line) {
  m <- regexec("^([^:]+:)(\\s*)(.+)$", passage_line)
  mm <- regmatches(passage_line, m)[[1]]
  if (length(mm) < 4) return(escape_js_single(passage_line))  # fallback
  
  prefix <- trimws(mm[1])
  ref    <- trimws(mm[4])
  
  parsed <- parse_bible_ref(ref)
  if (is.null(parsed)) {
    return(escape_js_single(passage_line))  # fallback
  }
  
  book_code <- bible_book_codes[parsed$book]
  if (is.na(book_code)) {
    return(escape_js_single(passage_line))  # fallback
  }
  
  url <- sprintf("https://www.bible.com/bible/114/%s.%s.NKJV?parallel=151",
                 book_code, parsed$chapter)
  
  html <- sprintf('%s <a href="%s">%s</a>', prefix, url, ref)
  escape_js_single(html)
}

# --- Main converter ----------------------------------------------------

convert_tripp_devotions_to_js <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_tripp.js" # {KEY} -> e.g. 12-09
){
  lines <- readLines(input_path, warn = FALSE, encoding = "UTF-8")
  lines <- gsub("\u00A0", " ", lines, fixed = TRUE)
  
  trimmed <- trimws(lines)
  n <- length(lines)
  
  # date lines like "DECEMBER 9"
  is_date_line <- grepl("^[A-Za-z]+\\s+[0-9]{1,2}$", trimmed, ignore.case = TRUE)
  date_idx <- which(is_date_line)
  if (!length(date_idx)) stop("No date lines found.")
  
  entries <- list()
  idx_with_sentinel <- c(date_idx, n + 1)
  
  for (k in seq_along(date_idx)) {
    start <- idx_with_sentinel[k]
    end   <- idx_with_sentinel[k + 1] - 1
    
    block <- lines[start:end]
    block_trim <- trimws(block)
    nonempty <- block_trim[block_trim != ""]
    if (length(nonempty) < 2) next
    
    date_line <- nonempty[1]
    key <- format_date_key(date_line)
    
    # everything after date line
    rest <- nonempty[-1]
    L <- length(rest)
    
    passage_line <- rest[L]              # last line = passage
    body_lines   <- rest[1:(L - 1)]      # body = everything except last
    
    body_text <- paste(body_lines, collapse = "\n")
    
    passage_js <- build_passage_html(passage_line)
    body_js    <- escape_js_single(body_text)
    
    
  
  
  # Build JS file
  js <- c(
  )

    
    block_lines <- c(
      paste0('  "', key, '": {'),
      '    "title": \'\',',
      '    "note": \'\',',
      paste0('    "passage": \'', passage_js, '\','),
      '    "dailyVerse": {',
      '      "ref": \'\',',
      '      "text": \'\'',
      '    },',
      paste0('    "body": \'', body_js, '\','),
      '    "dailyPrayer": {',
      '      "title": \'\',',
      '      "text": \'\'',
      '    }',
      if (!is_last) '  },' else '  }'
    )
    
    js <- c(js, block_lines)

  file_name <- gsub("\\{KEY\\}",e$key, filename_template)
  out_path  <- file.path(output_dir, file_name)
  
  writeLines(js, out_path, useBytes = TRUE)
  message("Wrote: ", out_path)
  }
}


