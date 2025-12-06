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

# ---- Main: write one JS file per day ----------------------------------

convert_dp_devotions_to_js_files <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_derekprince.js" # {KEY} -> e.g. 12-09
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
    
    # Keep positions so we could debug if needed
    nonempty_idx <- which(block_trim != "")
    nonempty <- block_trim[nonempty_idx]
    
    if (length(nonempty) < 7) {
      warning("Block starting at line ", start, " too short (", length(nonempty), " nonempty lines), skipping.")
      next
    }
    
    # Structure:
    # 1: date
    # 2: title
    # 3: note
    # 4..(L-5): body
    # (L-4): prayer
    # (L-3): passage
    # (L-2), (L-1), (L): metadata to ignore
    
    L <- length(nonempty)
    
    date_line  <- nonempty[1]
    title_line <- nonempty[2]
    note_line  <- nonempty[3]
    
    if (L < 7) {
      warning("Not enough lines to safely split body/prayer/passage (block starting at line ", start, ").")
      next
    }
    
    prayer_line   <- nonempty[L - 4]
    passage_line  <- nonempty[L - 3]
    
    if ((L - 5) >= 4) {
      body_lines <- nonempty[4:(L - 5)]
    } else {
      body_lines <- character(0)
    }
    
    body_text <- paste(body_lines, collapse = "\n")
    
    key <- format_date_key(date_line)   # e.g. "12-09"
    
    # ---- Build JS for this one day ------------------------------------
    
    title_js     <- escape_js_single(title_line)
    note_js      <- escape_js_single(note_line)
    passage_js   <- escape_js_single(passage_line)
    body_js      <- escape_js_single(body_text)
    prayer_js    <- escape_js_single(prayer_line)
    
    js_lines <- c(
 
      paste0('  "', key, '": {'),
      paste0('    "title": \'', title_js, '\','),
      paste0('    "note": \'', note_js, '\','),
      paste0('    "passage": \'', passage_js, '\','),
      '    "dailyVerse": {',
      '      "ref": \'\',',
      '      "text": \'\'',
      '    },',
      paste0('    "body": \'', body_js, ' \','),
      '    "dailyPrayer": {',
      '      "title": \'Prayer\',',
      paste0('      "text": \'', prayer_js, '\''),
      '    }',
      "}"
    )
    
    # filename, e.g. devotion-12-09.js
    file_name <- gsub("\\{KEY\\}", key, filename_template)
    out_path  <- file.path(output_dir, file_name)
    
    writeLines(js_lines, out_path, useBytes = TRUE)
    message("Wrote: ", out_path)
  }
}

# ---- Example usage -----------------------------------------------------
# convert_new_devotions_to_js_files(
#   input_path = "declaring-gods-word.txt",
#   output_dir = "js-devotions"
# )
#
# This will create:
#   js-devotions/devotion-12-09.js
#   js-devotions/devotion-12-10.js
#   ...