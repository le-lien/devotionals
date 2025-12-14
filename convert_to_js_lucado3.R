# ---- Helpers -----------------------------------------------------------

# Convert e.g. "DECEMBER 9" or "December 9" -> "12-09"
format_date_key <- function(date_str) {
  date_str <- trimws(date_str)
  parts <- strsplit(date_str, "\\s+")[[1]]
  if (length(parts) < 2) stop("Cannot parse date: ", date_str)
  
  month_raw <- parts[1]
  day <- parts[2]
  
  # Normalize month to "December"
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

# Strip [ ... ] around verse ref
clean_bracket_ref <- function(x) {
  x <- trimws(x)
  x <- gsub("^\\[\\s*", "", x)
  x <- gsub("\\s*\\]$", "", x)
  trimws(x)
}

# ---- Main: one JS file per day for this format ------------------------

convert_lucado3_devotions_to_js_files <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_lucado3.js" # {KEY} -> e.g. 12-09
) {
  lines <- readLines(input_path, warn = FALSE, encoding = "UTF-8")
  lines <- gsub("\u00A0", " ", lines, fixed = TRUE)  # non-breaking spaces -> space
  
  n <- length(lines)
  trimmed <- trimws(lines)
  
  # date lines like "DECEMBER 9"
  is_date_line <- grepl("^[A-Za-z]+\\s+[0-9]{1,2}$", trimmed, ignore.case = TRUE)
  date_idx <- which(is_date_line)
  
  if (length(date_idx) == 0) stop("No date lines found in file.")
  
  # ensure output directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # sentinel for last block
  idx_with_sentinel <- c(date_idx, n + 1)
  
  for (k in seq_along(date_idx)) {
    start <- idx_with_sentinel[k]
    end   <- idx_with_sentinel[k + 1] - 1
    
    block <- lines[start:end]
    block_trim <- trimws(block)
    
    nonempty <- block_trim[block_trim != ""]
    if (length(nonempty) < 6) {
      warning("Block starting at line ", start, " too short (", length(nonempty), " nonempty lines), skipping.")
      next
    }
    
    # ---- dynamic verse-ref detection (line starting with dash/em dash) ----
    cand <- which(grepl("\\[", nonempty)&grepl("[0:9]+", nonempty))
    #cand <- cand[cand < 4]  # must be before title
    if (length(cand) == 0) {
      warning("No verse ref line (starting with dash) found in block starting at line ", start, ". Skipping.")
      next
    }
    ref_pos <- cand[1]
    
    if (ref_pos <=2) {
      warning("Verse ref found too early in block starting at line ", start, ". Skipping.")
      next
    }
    
    
    # ---- PRAYER START ----
    prayer_idx <- which(nonempty == "ONE MORE THOUGHT")[1]
    
    # Structure for this format:
    # 1: date
    # 2: verse text
    # 3: verse ref (in brackets)
    # 4: title
    # 5..(L-2): body
    # (L-1): dailyPrayer.title
    # L: dailyPrayer.text
    
    L <- length(nonempty)
    
    date_line        <- nonempty[1]
    verse_text_line  <- nonempty[2]
    verse_ref_line   <- nonempty[3]
    title_line       <- nonempty[4]
    
    prayer_title <- "ONE MORE THOUGHT"
    prayer_text <- paste(na.omit(nonempty[(prayer_idx + 1):length(nonempty)]),
                         collapse = " ")
    prayer_text <- trimws(prayer_text)
    
    if (L > 5) {
      body_lines <- nonempty[(ref_pos + 2):(prayer_idx - 1)]
      body <- paste(na.omit(body_lines), collapse = "\n")
      body <- gsub("\\s+—\\s*", " ", body)
      body <- trimws(body)
    } else {
      body <- character(0)
    }
    

    key <- format_date_key(date_line)   # e.g. "12-09"
    
    # ---- Build JS for this one day ------------------------------------
    
    title_js        <- escape_js_single(title_line)
    verse_text_js   <- escape_js_single(verse_text_line)
    verse_ref_js    <- escape_js_single(clean_bracket_ref(verse_ref_line))
    body_js         <- escape_js_single(body)
    prayer_title_js <- escape_js_single(prayer_title)
    prayer_text_js  <- escape_js_single(prayer_text)
    
    js_lines <- c(
       paste0('  "', key, '": {'),
      paste0('    "title": \'', title_js, '\','),
      '    "note": \'\',',
      '    "passage": \'\',',
      '    "dailyVerse": {',
      paste0('      "ref": \'', verse_ref_js, '\','),
      paste0('      "text": \'', verse_text_js, '\''),
      '    },',
      paste0('    "body": \'', body_js, ' \','),
      '    "dailyPrayer": {',
      paste0('      "title": \'', prayer_title_js, '\','),
      paste0('      "text": \'', prayer_text_js, '\''),
      '    }',
      "}"
    )
    
    file_name <- gsub("\\{KEY\\}", key, filename_template)
    out_path  <- file.path(output_dir, file_name)
    
    writeLines(js_lines, out_path, useBytes = TRUE)
    message("Wrote: ", out_path)
  }
}

# ---- Example usage -----------------------------------------------------
# convert_bridge_devotions_to_js_files(
#   input_path = "bridge-of-confession-source.txt",
#   output_dir = "js-devotions"
# )
#
# For your sample it will create:
#   js-devotions/devotion-12-09.js
# containing exactly the shape you showed.
