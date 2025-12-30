library(readxl)
library(jsonlite)
library(writexl)
library(stringr)
library(stringi)

# NOW CHECK MANUALLY

# Create js file for data set tripp
tripp_data <- NULL
tripp_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("tripp", list.files("data/entries/"))]
for (file in tripp_names) {
tripp_tmp <- readLines(paste0("data/entries/",file))
if(length(tripp_data)==0) {tripp_data <- tripp_tmp} else {tripp_data <- c(tripp_data,",",tripp_tmp)}
}
writeLines(tripp_data,"data/tripp.js")


# Create js file for data set chambers
chambers_data <- NULL
chambers_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("chambers", list.files("data/entries/"))]
for (file in chambers_names) {
  chambers_tmp <- readLines(paste0("data/entries/",file))
  if(length(chambers_data)==0) {chambers_data <- chambers_tmp} else {chambers_data <- c(chambers_data,",",chambers_tmp)}
}
writeLines(chambers_data,"data/chambers.js")


# Create js file for data set derekprince
derekprince_data <- NULL
derekprince_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("derekprince", list.files("data/entries/"))]
for (file in derekprince_names) {
  derekprince_tmp <- readLines(paste0("data/entries/",file))
  if(length(derekprince_data)==0) {derekprince_data <- derekprince_tmp} else {derekprince_data <- c(derekprince_data,",",derekprince_tmp)}
}
writeLines(derekprince_data,"data/derekprince.js")

# Create js file for data set lucado1
lucado1_data <- NULL
lucado1_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("lucado1", list.files("data/entries/"))]
for (file in lucado1_names) {
  lucado1_tmp <- readLines(paste0("data/entries/",file))
  if(length(lucado1_data)==0) {lucado1_data <- lucado1_tmp} else {lucado1_data <- c(lucado1_data,",",lucado1_tmp)}
}
writeLines(lucado1_data,"data/lucado1.js")


# Create js file for data set lucado2
lucado2_data <- NULL
lucado2_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("lucado2", list.files("data/entries/"))]
for (file in lucado2_names) {
  lucado2_tmp <- readLines(paste0("data/entries/",file))
  if(length(lucado2_data)==0) {lucado2_data <- lucado2_tmp} else {lucado2_data <- c(lucado2_data,",",lucado2_tmp)}
}
writeLines(lucado2_data,"data/lucado2.js")


# Create js file for data set lucado3
lucado3_data <- NULL
lucado3_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("lucado3", list.files("data/entries/"))]
for (file in lucado3_names) {
  lucado3_tmp <- readLines(paste0("data/entries/",file))
  if(length(lucado3_data)==0) {lucado3_data <- lucado3_tmp} else {lucado3_data <- c(lucado3_data,",",lucado3_tmp)}
}
writeLines(lucado3_data,"data/lucado3.js")


# Create js file for data set lucado4
lucado4_data <- NULL
lucado4_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("lucado4", list.files("data/entries/"))]
for (file in lucado4_names) {
  lucado4_tmp <- readLines(paste0("data/entries/",file))
  if(length(lucado4_data)==0) {lucado4_data <- lucado4_tmp} else {lucado4_data <- c(lucado4_data,",",lucado4_tmp)}
}
writeLines(lucado4_data,"data/lucado4.js")

# Create js file for data set wigglesworth
wigglesworth_data <- NULL
wigglesworth_names <- list.files("data/entries/")[grepl("js", list.files("data/entries/"))&grepl("wigglesworth", list.files("data/entries/"))]
for (file in wigglesworth_names) {
  wigglesworth_tmp <- readLines(paste0("data/entries/",file))
  if(length(wigglesworth_data)==0) {wigglesworth_data <- wigglesworth_tmp} else {wigglesworth_data <- c(wigglesworth_data,",",wigglesworth_tmp)}
}
writeLines(wigglesworth_data,"data/wigglesworth.js")


# Read in empty data set


data_tmp <- readLines(paste0("data/","data_empty.js"))
tripp_data<- gsub("\\n","\n",stri_flatten(readLines("data/tripp.js")),fixed = T)
wigglesworth_data<- gsub("\\n","\n",stri_flatten(readLines("data/wigglesworth.js")),fixed = T)
derekprince_data<- gsub("\\n","\n",stri_flatten(readLines("data/derekprince.js")),fixed = T)
chambers_data<- gsub("\\n","\n",stri_flatten(readLines("data/chambers.js")),fixed = T)
lucado1_data<- gsub("\\n","\n",stri_flatten(readLines("data/lucado1.js")),fixed = T)
lucado2_data<- gsub("\\n","\n",stri_flatten(readLines("data/lucado2.js")),fixed = T)
lucado3_data<- gsub("\\n","\n",stri_flatten(readLines("data/lucado3.js")),fixed = T)
lucado4_data<- gsub("\\n","\n",stri_flatten(readLines("data/lucado4.js")),fixed = T)


data_tmp <- str_replace_all(data_tmp,"TRIPPENTRIESGOHERE",tripp_data)
data_tmp <- str_replace_all(data_tmp,"WIGGLESWORTHENTRIESGOHERE",wigglesworth_data)
data_tmp <- str_replace_all(data_tmp,"DEREKPRINCEENTRIESGOHERE",derekprince_data)
data_tmp <- str_replace_all(data_tmp,"CHAMBERSENTRIESGOHERE",chambers_data)
data_tmp <- str_replace_all(data_tmp,"LUCADO1ENTRIESGOHERE",lucado1_data)
data_tmp <- str_replace_all(data_tmp,"LUCADO2ENTRIESGOHERE",lucado2_data)
data_tmp <- str_replace_all(data_tmp,"LUCADO3ENTRIESGOHERE",lucado3_data)
data_tmp <- str_replace_all(data_tmp,"LUCADO4ENTRIESGOHERE",lucado4_data)

data_tmp <- gsub("\n\n","\n",data_tmp,fixed = T)
data_tmp <- gsub("\n","\n\n",data_tmp,fixed = T)
data_tmp <- gsub("\n","\\n",data_tmp,fixed = T)

writeLines(stri_flatten(data_tmp),"data_tmp.js")
source("add_link.R")
add_bible_links_file("data_tmp.js")

