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

convert_chambers_devotions_to_js_files <- function(
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
    
    # ---------- TITLE ----------
    title <- nonempty[2]
    
    # ---------------- DAILY VERSE ----------------
    verse_line <- nonempty[3]
    next_line <- nonempty[4]

    # Detect reference pattern
    ref_pattern <- "[A-Za-z ]+\\s\\d+:\\d+(-\\d+)?(\\s*\\([A-Za-z0-9]+\\))?$"
    
    if (grepl(ref_pattern, verse_line)) {
      # verse + ref on same line
      ref <- trimws(sub(".*\\(" , "", regmatches(verse_line, regexpr(ref_pattern, verse_line))))
      verse_text <- trimws(sub(ref_pattern, "", verse_line))
      body_start <- 4
    } else {
      # ref on next line
      ref <- next_line
      verse_text <- verse_line
      body_start <- 5
    }
    
    # Clean verse text
    verse_text <- gsub('^"|"$', "", verse_text)
    
    # ---------------- BODY ----------------
    body <- paste(nonempty[body_start:length(nonempty)], collapse = "\n")
    
    key <- format_date_key(date_line)   # e.g. "12-09"
    
    # ---------------- JS escaping ----------------
    esc <- function(x) {
      x <- gsub("\\\\", "\\\\\\\\", x)
      x <- gsub("'", "\\\\'", x)
      x <- gsub("\n", "\\\\n", x)
      x
    }
    
    # ---------------- Build JS ----------------
    js_lines <- paste0(
      "\"", key, "\": {\n",
      "  \"title\": '", esc(title), "',\n",
      "  \"note\": '',\n",
      "  \"passage\": '',\n",
      "  \"dailyVerse\": {\n",
      "    \"ref\": '", esc(ref), "',\n",
      "    \"text\": '", esc(verse_text), "'\n",
      "  },\n",
      "  \"body\": '", esc(body), "',\n",
      "  \"dailyPrayer\": {\n",
      "    \"title\": '',\n",
      "    \"text\": ''\n",
      "  }\n",
      "}\n"
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
