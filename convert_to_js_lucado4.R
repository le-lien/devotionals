# ---- Helpers -----------------------------------------------------------

# Convert separate month ("DECEMBER") and day ("9") -> "12-09"
format_month_day_key <- function(month_str, day_str) {
  month_str <- trimws(month_str)
  day_str   <- trimws(day_str)
  
  month <- tolower(month_str)
  month <- paste0(toupper(substr(month, 1, 1)), substr(month, 2, nchar(month)))
  
  d <- as.Date(paste(month, day_str, "2000"), format = "%B %d %Y")
  if (is.na(d)) stop("Cannot parse date from: ", month_str, " ", day_str)
  
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

# Strip leading em dash / dash from verse ref
clean_verse_ref <- function(x) {
  x <- trimws(x)
  x <- gsub("^[-—]\\s*", "", x)
  trimws(x)
}

# Is this a month name (basic check)
is_month_name <- function(x) {
  months <- tolower(month.name)
  tolower(trimws(x)) %in% months
}

# ---- Main: one JS file per day for split-date kids format  ------------

convert_lucado4_devotions_to_js_files <- function(
    input_path,
    output_dir,
    filename_template = "{KEY}_lucado4.js" # {KEY} -> e.g. 12-09
) {
  lines <- readLines(input_path, warn = FALSE, encoding = "UTF-8")
  lines <- gsub("\u00A0", " ", lines, fixed = TRUE)  # replace non-breaking spaces
  
  n <- length(lines)
  trimmed <- trimws(lines)
  
  # Find lines that look like a month; next non-empty line must be a day number
  month_idx <- which(sapply(trimmed, is_month_name))
  start_idx <- integer()
  
  for (i in month_idx) {
    # assume day is on the next line (like "9")
    if (i < n && grepl("^[0-9]{1,2}$", trimmed[i + 1])) {
      start_idx <- c(start_idx, i)
    }
  }
  
  if (length(start_idx) == 0) stop("No month+day blocks found in file.")
  
  # Ensure output dir
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Sentinel for the end of the last block
  idx_with_sentinel <- c(start_idx, n + 1)
  
  for (k in seq_along(start_idx)) {
    start <- idx_with_sentinel[k]
    end   <- idx_with_sentinel[k + 1] - 1
    
    block <- lines[start:end]
    block_trim <- trimws(block)
    
    # Remove completely empty lines for structure detection
    nonempty <- block_trim[block_trim != ""]
    L <- length(nonempty)
    
    if (L < 8) {
      warning("Block starting at line ", start, " too short (", L,
              " nonempty lines), skipping.")
      next
    }
    
    # Expected structure:
    # 1: month
    # 2: day
    # 3: title
    # 4..(ref_pos-1): verse text (1+ lines)
    # ref_pos: verse ref (starts with dash)
    # (ref_pos+1)..(L-3): body
    # (L-2): dailyPrayer.title
    # (L-1)..L: dailyPrayer.text (2 lines)
    
    month_line <- nonempty[1]
    day_line   <- nonempty[2]
    title_line <- nonempty[3]
    
    # ---- dynamic verse-ref detection (line starting with dash/em dash) ----
    cand <- which(grepl("^[-—]", nonempty))
    cand <- cand[cand > 3]  # must be after title
    if (length(cand) == 0) {
      warning("No verse ref line (starting with dash) found in block starting at line ", start, ". Skipping.")
      next
    }
    ref_pos <- cand[1]
    
    if (ref_pos <= 4) {
      warning("Verse ref found too early in block starting at line ", start, ". Skipping.")
      next
    }
    
    verse_text_lines <- nonempty[4:(ref_pos - 1)]
    verse_text_line  <- paste(verse_text_lines, collapse = " ")
    verse_ref_line   <- nonempty[ref_pos]
    
    # ---- body + prayer -------------------------------------------------
    if (L - ref_pos < 4) {
      warning("Not enough lines after verse ref in block starting at line ", start, ". Skipping.")
      next
    }
    
    # ---- PRAYER START ----
    prayer_idx <- which(nonempty == "Growing in Grace")[1]
    
    # ---- BODY ----
    body_lines <- nonempty[(ref_pos + 1):(prayer_idx - 1)]
    body <- paste(na.omit(body_lines), collapse = "\n")
    body <- gsub("\\s+—\\s*", " ", body)
    body <- trimws(body)
    
    # ---- PRAYER ----
    prayer_title <- "Growing in Grace"
    prayer_text <- paste(na.omit(nonempty[(prayer_idx + 1):length(nonempty)]),
                         collapse = " ")
    prayer_text <- trimws(prayer_text)
    
    key <- format_month_day_key(month_line, day_line)  # e.g. "12-09"
    
    # ---- Build JS for this day ----------------------------------------
    
    title_js        <- escape_js_single(title_line)
    verse_text_js   <- escape_js_single(verse_text_line)
    verse_ref_js    <- escape_js_single(clean_verse_ref(verse_ref_line))
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
# convert_splitdate_kids_devotions_to_js_files(
#   input_path = "kids-devotions.txt",
#   output_dir = "js-devotions"
# )
#
# For your sample it will produce:
# js-devotions/devotion-12-09.js
# with exactly:
# "12-09": {
#   title: 'Can We Really Complain? ',
#   ...
# }
