#!/usr/bin/env bash
# =====================================================================
# Linux CMD Project - TMDB movies analysis with Linux commands
#
# Run from the project folder:   bash cmd.sh
# Every step below has the same layout:
#   WHAT  - what the command does
#   WHY   - why it is needed
#   CHECK - how I know the result is right
# =====================================================================


# ---------------------------------------------------------------------
# STEP 0. GET AND INSPECT THE DATA
# ---------------------------------------------------------------------

# Go to the working folder.
cd ~/Documents/Project1

# WHAT: download the dataset (only needed once).
curl -O https://raw.githubusercontent.com/yinghaoz1/tmdb-movie-dataset-analysis/master/tmdb-movies.csv

# WHAT: print the column names, one per line, with a line number.
#   head -n 1      take the first line (the header)
#   tr ',' '\n'    replace every comma with a new line
#   nl -ba         number all lines
# WHY:   I need to know which column number is which
#        (4 budget, 5 revenue, 6 original_title, 7 cast, 9 director,
#         14 genres, 16 release_date, 18 vote_average, 19 release_year).
head -n 1 tmdb-movies.csv | tr ',' '\n' | nl -ba

# WHAT: count how many columns each line has when I split by comma.
#   awk -F,        use "," as the column separator
#   NF             awk's built-in "number of fields" of the current line
#   sort | uniq -c count how many lines have each number of columns
# WHY:   to test if "split by comma" works.
# CHECK: it does NOT. The counts are not all the same (10, 11, 12... columns),
#        because some text cells (for example the movie overview) contain commas.
awk -F, '{print NF}' tmdb-movies.csv | sort | uniq -c

# WHAT: count the lines of the file.
# CHECK: more lines than movies, see the next two commands.
wc -l tmdb-movies.csv

# WHAT: count lines that start with a digit (every real movie starts with its id).
#   grep -c '^[0-9]'   count lines that start with 0-9
grep -c '^[0-9]' tmdb-movies.csv

# WHAT: show the lines that do NOT start with a digit
#   grep -n -v '^[0-9]'   -v = invert (not matching), -n = show the line number
# CHECK: the header plus some broken lines. Some cells contain a line break,
#        so one movie is split into several lines.
grep -n -v '^[0-9]' tmdb-movies.csv


# ---------------------------------------------------------------------
# STEP 1. CLEAN: CSV -> TSV (columns separated by a Tab)
# ---------------------------------------------------------------------

# WHAT: run a small Python script (clean_data.py). It only does one job:
#       read the CSV correctly (it understands quotes), remove line breaks and
#       tabs inside cells, and write clean_data.tsv with Tab-separated columns.
# WHY:  with commas inside cells and line breaks inside cells, awk, cut and sort
#       cannot read the CSV safely. This is the only Python step.
#       All analysis below uses Linux commands.
python3 clean_data.py

# CHECK: 10867 lines = 1 header + 10866 movies.
wc -l clean_data.tsv

# CHECK: every line has exactly 21 columns (the output must be "10867 21").
awk -F'\t' '{print NF}' clean_data.tsv | sort | uniq -c

# WHAT: create the folder for the results (-p = no error if it already exists).
mkdir -p out


# ---------------------------------------------------------------------
# REQUIREMENT 1. SORT MOVIES BY RELEASE DATE, NEWEST FIRST
# ---------------------------------------------------------------------

# WHAT: write the header line first. ">" creates (or empties) the file.
head -1 clean_data.tsv > out/1_sorted_by_release_date_desc.tsv

# WHAT: look at column 16 (release_date) and column 19 (release_year).
#   tail -n +2   skip the header (start from line 2)
# WHY:   release_date looks like 12/31/15 (month/day/2-digit year), so I cannot
#        tell if "60" means 1960 or 2060. The full year is in column 19.
tail -n +2 clean_data.tsv | head -n 3 | awk -F'\t' '{print $16, "|", $19}'

# WHAT: build a sort key "yyyymmdd" for the first 3 movies, to test the idea.
#   split($16,d,"/")   cut the date at "/": d[1]=month, d[2]=day
#   %04d%02d%02d       print year with 4 digits, month and day with 2 digits
# CHECK: a movie released on 31 Dec 2015 gives 20151231.
tail -n +2 clean_data.tsv | head -n 3 | awk -F'\t' '{split($16,d,"/"); printf "%04d%02d%02d\n", $19,d[1],d[2]}'

# WHAT: the full command.
#   1) awk puts the key yyyymmdd in front of each line
#   2) sort -t$'\t' -k1,1nr   sort by column 1 (the key): n = as numbers, r = biggest first
#   3) cut -f2-               remove the key again
#   4) >>                     append to the file after the header
tail -n +2 clean_data.tsv | awk -F'\t' '{split($16,d,"/"); printf "%04d%02d%02d\t%s\n",$19,d[1],d[2],$0}' | sort -t$'\t' -k1,1nr | cut -f2- >> out/1_sorted_by_release_date_desc.tsv

# CHECK: the first 2 movies must have the latest dates (Martyrs, 12/31/15).
head -2 out/1_sorted_by_release_date_desc.tsv | cut -f6,16


# ---------------------------------------------------------------------
# REQUIREMENT 2. MOVIES WITH vote_average > 7.5
# ---------------------------------------------------------------------

# WHAT: count movies where column 18 (vote_average) is greater than 7.5.
#   LC_ALL=C   make awk read "7.5" with a dot as a decimal number.
# WHY:   on a computer with a decimal comma, awk reads 7.5 as 7 and returns
#        1282 movies (wrong). With LC_ALL=C the answer is 350 (right).
tail -n +2 clean_data.tsv | LC_ALL=C awk -F'\t' '$18>7.5' | wc -l

# WHAT: write the header, then append the movies that pass the filter.
head -1 clean_data.tsv > out/2_vote_gt_7.5.tsv
tail -n +2 clean_data.tsv | LC_ALL=C awk -F'\t' '$18>7.5' >> out/2_vote_gt_7.5.tsv

# CHECK: 351 lines = 1 header + 350 movies.
wc -l out/2_vote_gt_7.5.tsv


# ---------------------------------------------------------------------
# REQUIREMENT 3. HIGHEST AND LOWEST REVENUE
# ---------------------------------------------------------------------

# WHAT: look at columns 5 (revenue) and 6 (original_title) of the first 3 movies.
tail -n +2 clean_data.tsv | head -3 | cut -f5,6

# WHAT: sort by revenue from small to big and look at the first 3.
# CHECK: they are all 0. A revenue of 0 means "no data", not a real revenue.
tail -n +2 clean_data.tsv | sort -t$'\t' -k5,5n | head -3 | cut -f5,6

# WHAT: count the movies with revenue = 0.
# CHECK: 6016 movies.
tail -n +2 clean_data.tsv | awk -F'\t' '$5==0' | wc -l

# WHAT: lowest revenue after removing the movies with revenue = 0.
tail -n +2 clean_data.tsv | awk -F'\t' '$5>0' | sort -t$'\t' -k5,5n | head -5 | cut -f5,6

# WHAT: save the answer. echo writes a title, then each command appends its result.
echo "Highest revenue:" > out/3_revenue.txt
tail -n +2 clean_data.tsv | sort -t$'\t' -k5,5nr | head -1 | cut -f6,5 >> out/3_revenue.txt
echo "" >> out/3_revenue.txt
echo "Number of movies without revenue data (revenue = 0):" >> out/3_revenue.txt
tail -n+2 clean_data.tsv | awk -F'\t' '$5==0' | wc -l >> out/3_revenue.txt
echo "" >> out/3_revenue.txt
echo "Lowest revenue after removing the movies without revenue data:" >> out/3_revenue.txt
tail -n +2 clean_data.tsv | awk -F'\t' '$5>0' | sort -t$'\t' -k5,5n | head -2 | cut -f6,5 >> out/3_revenue.txt

# CHECK: read the result file.
cat out/3_revenue.txt


# ---------------------------------------------------------------------
# REQUIREMENT 4. TOTAL REVENUE OF ALL MOVIES
# ---------------------------------------------------------------------

# WHAT: test the idea on 3 movies. s=s+$5 means "add this movie's revenue to s".
tail -n +2 clean_data.tsv | head -3 | awk -F'\t' '{s=s+$5; print$5 ,s}'

# WHAT: the full command. END{...} runs once, after awk has read all the lines.
#   printf "%.0f"   print the whole number (print alone writes a big number
#                   in scientific form such as 4.3272e+11)
tail -n +2 clean_data.tsv | awk -F'\t' '{s=s+$5} END{printf "%.0f\n", s}'

# WHAT: save the answer.
echo "Total revenue of all movies:" > out/4_total_revenue.txt
tail -n +2 clean_data.tsv | awk -F'\t' '{s=s+$5} END{printf "%.0f\n", s}' >> out/4_total_revenue.txt
cat out/4_total_revenue.txt


# ---------------------------------------------------------------------
# REQUIREMENT 5. TOP 10 MOVIES BY PROFIT
# ---------------------------------------------------------------------

# WHAT: profit = revenue (column 5) - budget (column 4).
#       Look at budget, revenue and title of the first 3 movies.
tail -n +2 clean_data.tsv | head -3 | cut -f4,5,6

# WHAT: calculate the profit for 3 movies. The profit comes first, then the title.
tail -n +2 clean_data.tsv | head -3 | awk -F'\t' '{printf "%.0f\t%s\n", $5-$4, $6}'

# WHAT: do it for all movies, sort by profit (column 1) from biggest, keep 10.
tail -n +2 clean_data.tsv | awk -F'\t' '{printf "%.0f\t%s\n", $5-$4, $6}' | sort -t$'\t' -k1,1nr | head -10

# WHAT: save the answer.
echo "Top 10 movies by profit (revenue - budget):" > out/5_top10_profit.txt
tail -n +2 clean_data.tsv | awk -F'\t' '{printf "%.0f\t%s\n", $5-$4, $6}' | sort -t$'\t' -k1,1nr | head -10 >> out/5_top10_profit.txt
cat out/5_top10_profit.txt


# ---------------------------------------------------------------------
# REQUIREMENT 6. DIRECTOR AND ACTOR WITH THE MOST MOVIES
# ---------------------------------------------------------------------

# WHAT: look at column 9 (director) and column 7 (cast).
# NOTE:  one cell can hold several names separated by "|".
tail -n +2 clean_data.tsv | head -3 | cut -f9
tail -n +2 clean_data.tsv | head -3 | cut -f7

# WHAT: the counting recipe (used again for genres in requirement 7):
#   cut -f9        take the column
#   tr '|' '\n'    put every name on its own line
#   awk 'NF'       delete empty lines
#   sort           put equal names next to each other
#   uniq -c        count each name
#   sort -nr       biggest count first
#   head -5        keep the top 5
tail -n +2 clean_data.tsv | cut -f9 | tr '|' '\n' | awk 'NF' | sort | uniq -c | sort -nr | head -5
tail -n +2 clean_data.tsv | cut -f7 | tr '|' '\n' | awk 'NF' | sort | uniq -c | sort -nr | head -5

# WHAT: save the answer (only the number 1: head -1).
echo "Director with the most movies:" > out/6_director_actor.txt
tail -n +2 clean_data.tsv | cut -f9 | tr '|' '\n' | awk 'NF' | sort | uniq -c | sort -nr | head -1 >> out/6_director_actor.txt
echo "" >> out/6_director_actor.txt
echo "Actor with the most movies:" >> out/6_director_actor.txt
tail -n +2 clean_data.tsv | cut -f7 | tr '|' '\n' | awk 'NF' | sort | uniq -c | sort -nr | head -1 >> out/6_director_actor.txt
cat out/6_director_actor.txt


# ---------------------------------------------------------------------
# REQUIREMENT 7. NUMBER OF MOVIES PER GENRE
# ---------------------------------------------------------------------

# WHAT: same recipe as requirement 6, on column 14 (genres).
# NOTE:  a movie can have several genres (Action|Drama), so the genre counts
#        add up to more than the number of movies.
tail -n +2 clean_data.tsv | cut -f14 | tr '|' '\n' | awk 'NF' | sort | uniq -c | sort -nr

# WHAT: save the answer.
echo "Number of movies per genre:" > out/7_genres.txt
tail -n +2 clean_data.tsv | cut -f14 | tr '|' '\n' | awk 'NF' | sort | uniq -c | sort -nr >> out/7_genres.txt
cat out/7_genres.txt