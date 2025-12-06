# Set the directory where your files live
dir_path <- "data/entries"

# List only .js files in that directory
files <- list.files(dir_path, pattern = "\\.js$", full.names = TRUE)

# Function to add dash after the first two digits when name starts with 4 digits
add_dash_to_filename <- function(filepath) {
  fname <- basename(filepath)
  
  # Only process if it starts with 4 digits and no dash in the first 5 chars
  if (grepl("^[0-9]{4}_[^/]+\\.js$", fname)) {
    # Replace "0101_" with "01-01_"
    new_fname <- sub("^([0-9]{2})([0-9]{2})_", "\\1-\\2_", fname)
    new_path  <- file.path(dirname(filepath), new_fname)
    
    file.rename(filepath, new_path)
    message("Renamed: ", fname, " -> ", new_fname)
  } else {
    message("Skipped: ", fname)
  }
}

# Apply to all files
invisible(lapply(files, add_dash_to_filename))
