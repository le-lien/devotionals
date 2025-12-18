# Create entries
source("convert_to_js_chambers.R")
convert_chambers_devotions_to_js_files("data/entries/chambers.txt","data/entries/chambers")

source("convert_to_js_derekprince.R")
convert_dp_devotions_to_js_files("data/entries/derekprince.txt","data/entries/derekprince")

source("convert_to_js_lucado1and2.R")
convert_lucado12_devotions_to_js_files("data/entries/lucado1.txt","data/entries/lucado1","{KEY}_lucado1.js" )

source("convert_to_js_lucado1and2.R")
convert_lucado12_devotions_to_js_files("data/entries/lucado2.txt","data/entries/lucado2","{KEY}_lucado2.js" )

source("convert_to_js_lucado3.R")
convert_lucado3_devotions_to_js_files("data/entries/lucado3.txt","data/entries/lucado3")

source("convert_to_js_lucado4.R")
convert_lucado4_devotions_to_js_files("data/entries/lucado4.txt","data/entries/lucado4")

source("convert_to_js_tripp.R")
convert_tripp_to_js_files("data/entries/tripp.txt","data/entries/tripp")

source("convert_to_js_wigglesworth.R")
convert_wigglesworth_devotions_to_js_files("data/entries/wigglesworth.txt","data/entries/wigglesworth")


# Call entries

date <- "12-15"
for (file in c("tripp","wigglesworth","derekprince","chambers","lucado1","lucado2","lucado3","lucado4")) {file.copy(paste0("data/entries/",file,"/",date,"_",file,".js"),paste0("data/entries/",date,"_",file,".js"),overwrite = F)}


# list all dates in a given year as "mm-dd"
list_dates_mm_dd <- function(year) {
  start <- as.Date(paste0(year, "-12-22"))
  end   <- as.Date(paste0(year, "-12-30"))
  
  dates <- seq.Date(start, end, by = "day")
  format(dates, "%m-%d")
}

# example: all dates in 2025
all_2025_dates <- list_dates_mm_dd(2025)


for(date in all_2025_dates){
  for (file in c("tripp","wigglesworth","derekprince","chambers","lucado1","lucado2","lucado3","lucado4")) {file.copy(paste0("data/entries/",file,"/",date,"_",file,".js"),paste0("data/entries/",date,"_",file,".js"),overwrite = F)}
}


