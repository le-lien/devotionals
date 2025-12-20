# -------- Helpers ------------------------------------------------------

# "JANUARY 1" or "January 1" -> "01-01"
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

# -------- Main: one JS file per date -----------------------------------

convert_tripp_to_js_files <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_tripp.js"   # e.g. "01-01.js"
) {
  lines   <- readLines(input_path, warn = FALSE, encoding = "UTF-8")
  lines   <- gsub("\u00A0", " ", lines, fixed = TRUE)  # non-breaking spaces
  trimmed <- trimws(lines)
  n       <- length(lines)
  
  # Date lines like "JANUARY 1", "January 1"
  is_date_line <- grepl("^[A-Za-z]+\\s+[0-9]{1,2}$", trimmed, ignore.case = TRUE)
  date_idx     <- which(is_date_line)
  if (!length(date_idx)) stop("No date lines found.")
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Sentinel to mark end of last block
  idx_with_sentinel <- c(date_idx, n + 1)
  
  for (k in seq_along(date_idx)) {
    start <- idx_with_sentinel[k]
    end   <- idx_with_sentinel[k + 1] - 1
    
    block_trim <- trimmed[start:end]
    
    # indices of non-empty lines within this block
    nonempty_idx <- which(block_trim != "")
    if (length(nonempty_idx) < 2) next
    
    # First non-empty line = date
    idx_date   <- nonempty_idx[1]
    date_line  <- block_trim[idx_date]
    key        <- format_date_key(date_line)
    
    # All remaining non-empty lines
    rest_idx <- nonempty_idx[-1]
    if (!length(rest_idx)) next
    
    # Last non-empty line = passage
    idx_passage   <- tail(rest_idx, 1)
    passage_line  <- block_trim[idx_passage]
    idx_verse <- nonempty_idx[2]
    
    # Body = everything after date up to (but excluding) passage
    body_idx <- rest_idx[rest_idx != idx_passage&rest_idx != idx_verse]
    if (!length(body_idx)) {
      body_text <- ""
    } else {
      body_lines <- block_trim[body_idx]
      # Keep original line breaks
      body_text  <- paste(body_lines, collapse = "\n")
    }
    
    # Escape for JS
    passage_js <- escape_js_single(passage_line)
    body_js    <- escape_js_single(body_text)
    verse_js <- escape_js_single(paste(block_trim[idx_verse],collapse = "\n"))
    
    # Build JS for this date
    js_lines <- c(
      paste0('  "', key, '": {'),
      '    "title": \'\',',
      '    "note": \'\',',
      paste0('    "passage": \'', passage_js, '\','),
      '    "dailyVerse": {',
      '      "ref": \'\',',
      paste0('      "text": \'', verse_js, '\''),
      '    },',
      paste0('    "body": \'', body_js, '\','),
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

# -------- Example usage -----------------------------------------------
# convert_devotions_simple_to_js_files(
#   input_path   = "tripp-devotions.txt",
#   output_dir   = "js-devotions"
# )
# -> creates files like:
#    js-devotions/01-01.js
#    js-devotions/01-02.js
#    ...
