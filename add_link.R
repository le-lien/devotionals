# ---- add_bible_links.R ----

# Your mapping
book_map <- c(
  "Genesis"="GEN","Exodus"="EXO","Exod"="EXO","Leviticus"="LEV","Numbers"="NUM","Deuteronomy"="DEU",
  "Joshua"="JOS","Judges"="JDG","Ruth"="RUT",
  "1 Samuel"="1SA","2 Samuel"="2SA",
  "1 Kings"="1KI","2 Kings"="2KI",
  "1 Chronicles"="1CH","2 Chronicles"="2CH",
  "Ezra"="EZR","Nehemiah"="NEH","Esther"="EST",
  "Job"="JOB","Psalm"="PSA","Psalms"="PSA","Proverbs"="PRO","Ecclesiastes"="ECC","Song of Songs"="SNG",
  "Isaiah"="ISA","Jeremiah"="JER","Lamentations"="LAM","Ezekiel"="EZK","Daniel"="DAN",
  "Hosea"="HOS","Joel"="JOL","Amos"="AMO","Obadiah"="OBA","Jonah"="JON",
  "Micah"="MIC","Nahum"="NAM","Habakkuk"="HAB","Zephaniah"="ZEP","Haggai"="HAG","Zechariah"="ZEC","Malachi"="MAL",
  "Matthew"="MAT","Matt"="MAT","Mark"="MRK","Luke"="LUK","John"="JHN","Acts"="ACT",
  "Romans"="ROM","Rom"="ROM","1 Cor"="1CO","2 Cor"="2CO","1 Corinthians"="1CO","2 Corinthians"="2CO",
  "Galatians"="GAL","Ephesians"="EPH","Philippians"="PHP","Colossians"="COL",
  "1 Thessalonians"="1TH","2 Thessalonians"="2TH",
  "1 Timothy"="1TI","2 Timothy"="2TI","Titus"="TIT","Philemon"="PHM",
  "Hebrews"="HEB","Heb."="HEB","James"="JAS","1 Peter"="1PE","2 Peter"="2PE",
  "1 John"="1JN","2 John"="2JN","3 John"="3JN","Jude"="JUD","Revelation"="REV"
)

# Your roman numeral normalizer (I extended it to include John because it's common)
normalize_roman_book <- function(ref_str) {
  s <- ref_str
  s <- gsub("^I\\s+Thessalonians",  "1 Thessalonians",  s, ignore.case = TRUE)
  s <- gsub("^II\\s+Thessalonians", "2 Thessalonians",  s, ignore.case = TRUE)
  s <- gsub("^I\\s+Corinthians",    "1 Corinthians",    s, ignore.case = TRUE)
  s <- gsub("^II\\s+Corinthians",   "2 Corinthians",    s, ignore.case = TRUE)
  s <- gsub("^I\\s+Timothy",        "1 Timothy",        s, ignore.case = TRUE)
  s <- gsub("^II\\s+Timothy",       "2 Timothy",        s, ignore.case = TRUE)
  s <- gsub("^I\\s+Peter",          "1 Peter",          s, ignore.case = TRUE)
  s <- gsub("^II\\s+Peter",         "2 Peter",          s, ignore.case = TRUE)
  s <- gsub("^I\\s+Samuel",         "1 Samuel",         s, ignore.case = TRUE)
  s <- gsub("^II\\s+Samuel",        "2 Samuel",         s, ignore.case = TRUE)
  s <- gsub("^I\\s+Kings",          "1 Kings",          s, ignore.case = TRUE)
  s <- gsub("^II\\s+Kings",         "2 Kings",          s, ignore.case = TRUE)
  s <- gsub("^I\\s+Chronicles",     "1 Chronicles",     s, ignore.case = TRUE)
  s <- gsub("^II\\s+Chronicles",    "2 Chronicles",     s, ignore.case = TRUE)
  
  # optional but useful
  s <- gsub("^I\\s+John",           "1 John",           s, ignore.case = TRUE)
  s <- gsub("^II\\s+John",          "2 John",           s, ignore.case = TRUE)
  s <- gsub("^III\\s+John",         "3 John",           s, ignore.case = TRUE)
  
  s
}

# Escape regex metacharacters in book names
escape_regex <- function(x) {
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x, perl = TRUE)
}

# Build the matcher from your map keys, plus roman variants for the ones you normalize
make_reference_regex <- function(book_names) {
  roman_variants <- c(
    "I Thessalonians","II Thessalonians",
    "I Corinthians","II Corinthians",
    "I Timothy","II Timothy",
    "I Peter","II Peter",
    "I Samuel","II Samuel",
    "I Kings","II Kings",
    "I Chronicles","II Chronicles",
    "I John","II John","III John"
  )
  
  all_books <- unique(c(book_names, roman_variants))
  # sort longest first so "1 John" matches before "John"
  all_books <- all_books[order(nchar(all_books), decreasing = TRUE)]
  book_alt <- paste(escape_regex(all_books), collapse = "|")
  
  # Groups:
  #  1 = book
  #  2 = chapter
  #  3 = verse_start (optional)
  #  4 = verse_end (optional, for ranges)
  paste0(
    "\\b(", book_alt, ")\\b\\.{0,1}\\s+",
    "(\\d{1,3})",
    "(?::(\\d{1,3})(?:\\s*[-–]\\s*(\\d{1,3}))?)?",
    "\\b"
  )
}

add_bible_links_file <- function(infile,
                                 #outfile = sub("\\.js?$", ".linked.js", infile, ignore.case = TRUE),
                                 outfile="data.js",
                                 bible_version_id = "114",
                                 bible_version_code = "NKJV") {
  
  # case-insensitive lookup
  book_map_lower <- setNames(unname(book_map), tolower(names(book_map)))
  
  normalize_book_key <- function(book) {
    b <- normalize_roman_book(book)
    b <- gsub("\\s+", " ", b)
    trimws(tolower(b))
  }
  
  build_url <- function(book, chapter, verse_start = NA_character_) {
    abbr <- unname(book_map_lower[normalize_book_key(book)])
    if (is.na(abbr) || !nzchar(abbr)) return(NA_character_)
    
    if (!is.na(verse_start) && nzchar(verse_start)) {
      sprintf("https://www.bible.com/bible/%s/%s.%s.%s.%s",
              bible_version_id, abbr, chapter, verse_start, bible_version_code)
    } else {
      sprintf("https://www.bible.com/bible/%s/%s.%s.%s",
              bible_version_id, abbr, chapter, bible_version_code)
    }
  }
  
  ref_pattern <- make_reference_regex(names(book_map))
  a_pattern <- "(?is)<a\\b[^>]*>.*?</a>"  # existing anchor blocks
  
  html <- paste(readLines(infile, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  
  # Replace refs only in non-<a> regions
  link_refs_in_segment <- function(seg) {
    m <- gregexpr(ref_pattern, seg, perl = TRUE, ignore.case = TRUE)[[1]]
    if (length(m) == 1 && m[1] == -1) return(seg)
    
    lens <- attr(m, "match.length")
    starts <- m
    ends <- starts + lens - 1
    
    out <- character(0)
    pos <- 1
    
    for (i in seq_along(starts)) {
      s <- starts[i]; e <- ends[i]
      out <- c(out, substr(seg, pos, s - 1))
      
      match_txt <- substr(seg, s, e)
      
      rx <- regexec(ref_pattern, match_txt, perl = TRUE, ignore.case = TRUE)
      parts <- regmatches(match_txt, rx)[[1]]
      # parts: [1]=full, [2]=book, [3]=chapter, [4]=verse_start, [5]=verse_end
      book <- parts[2]
      chapter <- parts[3]
      verse_start <- if (length(parts) >= 4) parts[4] else NA_character_
      if (is.null(verse_start) || identical(verse_start, "")) verse_start <- NA_character_
      
      url <- build_url(book, chapter, verse_start)
      
      if (!is.na(url)) {
        out <- c(out, sprintf('<a href="%s">%s</a>', url, match_txt))
      } else {
        out <- c(out, match_txt) # unknown book -> leave unchanged
      }
      
      pos <- e + 1
    }
    
    out <- c(out, substr(seg, pos, nchar(seg)))
    paste0(out, collapse = "")
  }
  
  # find existing anchors
  a_matches <- gregexpr(a_pattern, html, perl = TRUE)[[1]]
  if (length(a_matches) == 1 && a_matches[1] == -1) {
    new_html <- link_refs_in_segment(html)
    writeLines(new_html, outfile, useBytes = TRUE)
    #return(outfile)
  }
  
  a_lens <- attr(a_matches, "match.length")
  a_starts <- a_matches
  a_ends <- a_starts + a_lens - 1
  
  pieces <- character(0)
  cur <- 1
  for (i in seq_along(a_starts)) {
    s <- a_starts[i]; e <- a_ends[i]
    
    before <- substr(html, cur, s - 1)
    pieces <- c(pieces, link_refs_in_segment(before))
    
    anchor_block <- substr(html, s, e)
    pieces <- c(pieces, anchor_block)
    
    cur <- e + 1
  }
  
  tail <- substr(html, cur, nchar(html))
  pieces <- c(pieces, link_refs_in_segment(tail))
  
  new_html <- paste0(pieces, collapse = "")
  writeLines(new_html, outfile, useBytes = TRUE)
  outfile
}

# ---- Example ----
# result <- add_bible_links_file("input.html")
# cat("Wrote:", result, "\n")
