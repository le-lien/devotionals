# Call entries
# list all dates in a given year as "mm-dd"
list_dates_mm_dd <- function(year) {
  start <- as.Date(paste0(year, "-01-01"))
  end   <- as.Date(paste0(year, "-12-31"))
  
  dates <- seq.Date(start, end, by = "day")
  format(dates, "%m-%d")
}

# example: all dates in 2025
all_2025_dates <- list_dates_mm_dd(2025)

#date <- "01-01"
for(date in all_2025_dates){
  for (file in c("tripp","wigglesworth","derekprince","chambers","lucado1","lucado2","lucado3","lucado4")) {file.copy(paste0("data/entries/",file,"/",date,"_",file,".js"),paste0("data/entries/",date,"_",file,".js"),overwrite = F)}
}