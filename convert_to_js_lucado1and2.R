# ---- Helpers -----------------------------------------------------------

# Convert e.g. "JANUARY 1" -> "01-01"
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
  x <- gsub("\r", "", x)            # remove CR
  x <- gsub("\n", "\\\\n", x)       # newline -> \n
  x
}

# Robust verse-ref detection, e.g. "PSALM 142:1", "1 CORINTHIANS 13:4–7"
is_verse_ref_line <- function(x) {
  x <- trimws(x)
  if (nchar(x) == 0) return(FALSE)
  
  # Must contain a " chapter:verse" pattern (space before chapter)
  if (!grepl(" [0-9]+:[0-9]+", x)) return(FALSE)
  
  # Letters must be all uppercase (book names)
  letters_only <- gsub("[^A-Za-z]+", "", x)
  if (letters_only == "") return(FALSE)
  
  letters_only == toupper(letters_only)
}

# ---- Main: one JS file per day for this format ------------------------

convert_lucado12_devotions_to_js_files <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_lucado.js"  # {KEY} -> e.g. 01-01
) {
  lines <- readLines(input_path, warn = FALSE, encoding = "UTF-8")
  lines <- gsub("\u00A0", " ", lines, fixed = TRUE)  # non-breaking spaces -> normal spaces
  
  n <- length(lines)
  trimmed <- trimws(lines)
  
  # Date lines like "JANUARY 1", "DECEMBER 9"
  is_date_line <- grepl("^[A-Za-z]+\\s+[0-9]{1,2}$", trimmed, ignore.case = TRUE)
  date_idx <- which(is_date_line)
  
  if (length(date_idx) == 0) stop("No date lines found in file.")
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Sentinel to get the end of the last block
  idx_with_sentinel <- c(date_idx, n + 1)
  
  for (k in seq_along(date_idx)) {
    start <- idx_with_sentinel[k]
    end   <- idx_with_sentinel[k + 1] - 1
    
    block <- lines[start:end]
    block_trim <- trimws(block)
    
    nonempty <- block_trim[block_trim != ""]
    L <- length(nonempty)
    
    if (L < 6) {
      warning("Block starting at line ", start, " too short (", L, " nonempty lines), skipping.")
      next
    }
    
    # Expected structure:
    # 1: date          (e.g. "JANUARY 1")
    # 2: title         (e.g. "God Listens")
    # 3..(ref_pos-1): verse text (1+ lines)
    # ref_pos: verse ref (e.g. "PSALM 142:1")
    # (ref_pos+1)..(L-1): body (multiple lines)
    # L: passage (e.g. "The Great House of God")
    
    date_line  <- nonempty[1]
    title_line <- nonempty[2]
    
    # --- find verse-ref line dynamically ---
    cand <- which(sapply(nonempty, is_verse_ref_line))
    cand <- cand[cand > 2]  # must be after title
    if (length(cand) == 0) {
      warning("No verse reference line found in block starting at line ", start, ". Skipping.")
      next
    }
    ref_pos <- cand[1]
    
    if (ref_pos <= 3) {
      warning("Verse reference found too early in block starting at line ", start, ". Skipping.")
      next
    }
    
    verse_text_lines <- nonempty[3:(ref_pos - 1)]
    verse_text_line  <- paste(verse_text_lines, collapse = " ")
    verse_ref_line   <- nonempty[ref_pos]
    
    # last non-empty line = passage
    passage_line <- nonempty[L]
    
    # body = lines after verse ref up to (but excluding) passage
    if (ref_pos + 1 <= L - 1) {
      body_lines <- nonempty[(ref_pos + 1):(L - 1)]
    } else {
      body_lines <- character(0)
    }
    
    body_text <- paste(body_lines, collapse = "\n")
    
    key <- format_date_key(date_line)  # e.g. "01-01"
    
    # ---- Build JS for this one day ------------------------------------
    
    title_js      <- escape_js_single(title_line)
    verse_text_js <- escape_js_single(verse_text_line)
    verse_ref_js  <- escape_js_single(verse_ref_line)
    passage_js    <- escape_js_single(passage_line)
    body_js       <- escape_js_single(body_text)
    
    js_lines <- c(
      paste0('  "', key, '": {'),
      paste0('    "title": \'', title_js, '\','),
      '    "note": \'\',',
      paste0('    "passage": \'', passage_js, '\','),
      '    "dailyVerse": {',
      paste0('      "ref": \'', verse_ref_js, '\','),
      paste0('      "text": \'', verse_text_js, '\''),
      '    },',
      paste0('    "body": \'', body_js, ' \','),
      '    "dailyPrayer": {',
      '      "title": \'\',',
      '      "text": \'\'',
      '    }',
      "}"
    )
    
    file_name <- gsub("\\{KEY\\}", key, filename_template)
    out_path  <- file.path(output_dir, file_name)
    
    writeLines(js_lines, out_path, useBytes = TRUE)
    message("Wrote: ", out_path)
  }
}
