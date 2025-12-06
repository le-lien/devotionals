# ---- Helpers -----------------------------------------------------------

# Convert "December 11" -> "12-11"
format_date_key <- function(date_str) {
  date_str <- trimws(date_str)
  d <- as.Date(paste0(date_str, " 2000"), format = "%B %d %Y")
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

# Strip leading/trailing quote characters (straight or curly)
strip_outer_quotes <- function(x) {
  x <- trimws(x)
  x <- gsub('^[“”"\' ]+', "", x)
  x <- gsub('[“”"\' ]+$', "", x)
  x
}

# ---- Main: write one JS file per day ----------------------------------

convert_devotions_to_js_files <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_chambers.js" # {KEY} -> e.g. 12-11
) {
  lines <- readLines(input_path, warn = FALSE, encoding = "UTF-8")
  lines <- gsub("\u00A0", " ", lines, fixed = TRUE)  # non-breaking spaces -> space
  
  n <- length(lines)
  trimmed <- trimws(lines)
  
  # date lines like "December 11"
  is_date_line <- grepl("^[A-Za-z]+ [0-9]{1,2}$", trimmed)
  date_idx <- which(is_date_line)
  
  if (length(date_idx) == 0) stop("No date lines found in file.")
  
  # ensure output directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # sentinel to mark end of last block
  idx_with_sentinel <- c(date_idx, n + 1)
  
  for (k in seq_along(date_idx)) {
    start <- idx_with_sentinel[k]
    end   <- idx_with_sentinel[k + 1] - 1
    
    block <- lines[start:end]
    block_trim <- trimws(block)
    
    # drop completely empty lines for structure detection
    nonempty <- block_trim[block_trim != ""]
    
    if (length(nonempty) < 4) {
      warning("Block starting at line ", start, " too short, skipping.")
      next
    }
    
    date_line   <- nonempty[1]
    title_line  <- nonempty[2]
    verse_text  <- nonempty[3]
    verse_ref   <- nonempty[4]
    body_lines  <- nonempty[-(1:4)]
    
    # join body lines with real newlines (we'll escape later)
    body_text <- paste(body_lines, collapse = "\n")
    
    key <- format_date_key(date_line)              # "12-11"
    verse_text_clean <- strip_outer_quotes(verse_text)
    
    # ---- Build JS for this one day ------------------------------------
    
    title_js      <- escape_js_single(title_line)
    verse_text_js <- escape_js_single(verse_text_clean)
    verse_ref_js  <- escape_js_single(verse_ref)
    body_js       <- escape_js_single(body_text)
    
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
      '      "title": \'\',',
      '      "text": \'\'',
      '    }',
      "}"
    )
    
    # filename, e.g. devotion-12-11.js
    file_name <- gsub("\\{KEY\\}", key, filename_template)
    out_path  <- file.path(output_dir, file_name)
    
    writeLines(js_lines, out_path, useBytes = TRUE)
    
    message("Wrote: ", out_path)
  }
}

# ---- Example usage -----------------------------------------------------
# convert_devotions_to_js_files(
#   input_path = "my-devotions.txt",
#   output_dir = "js-devotions"
# )
#
# This will create files like:
#   js-devotions/devotion-12-11.js
#   js-devotions/devotion-12-12.js
#   ...
