#!/usr/bin/env bash
# =====================================================================
# check_data.sh - check the data BEFORE and AFTER the analysis.
# It only reads files. It does not change anything.
#
# Part 1 - input:   is the raw CSV what I think it is?
# Part 2 - clean:   is clean_data.tsv complete and usable? (profile of the data)
# Part 3 - results: is each result in out/ right? Every number is calculated
#                   a SECOND way with a different command, and the two must match.
#
# Run from the project folder (after bash cmd.sh):   bash check_data.sh
# =====================================================================

F=clean_data.tsv

# A small helper: compare two values and print PASS or FAIL.
#   usage: check "what I check" "value 1" "value 2"
check() {
  if [ "$2" = "$3" ]; then
    echo "  PASS  $1  ($2)"
  else
    echo "  FAIL  $1  ($2 is not $3)"
  fi
}


echo "=== Part 1: input (tmdb-movies.csv) ==="

# Lines in the CSV file. This is MORE than the number of movies (line breaks inside cells).
echo "Lines in the file:                 $(wc -l < tmdb-movies.csv)"

# Every real movie line starts with its id (a number). The header does not.
echo "Movie lines (start with a digit):  $(grep -c '^[0-9]' tmdb-movies.csv)"


echo
echo "=== Part 2: clean data (clean_data.tsv) ==="

# Number of movies = lines without the header.
MOVIES=$(tail -n +2 $F | wc -l)
echo "Movies:                            $MOVIES"

check "movies in clean file = movie lines in the CSV" "$MOVIES" "$(grep -c '^[0-9]' tmdb-movies.csv)"

# Every line must have 21 columns. This prints the lines that do NOT have 21.
check "lines that do not have 21 columns" "$(awk -F'\t' 'NF!=21' $F | wc -l)" "0"

# Empty ids.
check "movies with an empty id" "$(tail -n +2 $F | awk -F'\t' '$1==""' | wc -l)" "0"

# Duplicates. sort | uniq -d prints the values that appear more than once.
DUP_IDS=$(tail -n +2 $F | cut -f1 | sort | uniq -d | wc -l)
DUP_LINES=$(tail -n +2 $F | sort | uniq -d | wc -l)
echo "Duplicate ids:                     $DUP_IDS   (known: movie id 42194, TEKKEN)"
echo "Duplicate full lines:              $DUP_LINES"
echo "Different movies without the duplicates: $(tail -n +2 $F | sort -u | wc -l)"

# Zeros. In this data a 0 means "unknown", not a real value.
echo "Movies with budget = 0:            $(tail -n +2 $F | awk -F'\t' '$4==0' | wc -l)"
echo "Movies with revenue = 0:           $(tail -n +2 $F | awk -F'\t' '$5==0' | wc -l)"
echo "Movies without genres:             $(tail -n +2 $F | awk -F'\t' '$14==""' | wc -l)"


echo
echo "=== Part 3: results (each one calculated a second way) ==="

# --- Requirement 1: sorted file ---
check "req 1: sorted file has all movies" "$(( $(wc -l < out/1_sorted_by_release_date_desc.tsv) - 1 ))" "$MOVIES"
# Build the key yyyymmdd again for every line. Count the places where it goes UP.
# In a "newest first" file this must never happen.
check "req 1: places where the date goes up" "$(tail -n +2 out/1_sorted_by_release_date_desc.tsv | awk -F'\t' '{split($16,d,"/"); k=sprintf("%04d%02d%02d",$19,d[1],d[2])+0; if (NR>1 && k>prev) bad++; prev=k} END{print bad+0}')" "0"

# --- Requirement 2: vote_average > 7.5 ---
# Second way: take only column 18, sort it, and count the values bigger than 7.5.
check "req 2: movies with vote_average > 7.5" "$(( $(wc -l < out/2_vote_gt_7.5.tsv) - 1 ))" "$(tail -n +2 $F | cut -f18 | LC_ALL=C awk '$1>7.5' | wc -l)"
check "req 2: smallest vote_average in the file (must be > 7.5)" "$(tail -n +2 out/2_vote_gt_7.5.tsv | cut -f18 | sort -n | head -1 | LC_ALL=C awk '{print ($1>7.5) ? "ok" : "too small"}')" "ok"

# --- Requirement 3: highest revenue ---
# Second way: keep a running maximum with awk instead of sorting.
check "req 3: highest revenue" "$(sed -n '2p' out/3_revenue.txt | cut -f1)" "$(tail -n +2 $F | awk -F'\t' '$5>m {m=$5} END{printf "%.0f\n", m}')"

# --- Requirement 4: total revenue ---
# Second way: put "+" between all revenues and let bc add them.
check "req 4: total revenue" "$(sed -n '2p' out/4_total_revenue.txt)" "$(tail -n +2 $F | cut -f5 | paste -sd+ | bc)"

# --- Requirement 5: top 10 by profit ---
# Second way: sort by profit ascending and take the LAST line.
check "req 5: biggest profit" "$(sed -n '2p' out/5_top10_profit.txt | cut -f1)" "$(tail -n +2 $F | awk -F'\t' '{printf "%.0f\n", $5-$4}' | sort -n | tail -1)"
check "req 5: lines in the top list" "$(tail -n +2 out/5_top10_profit.txt | wc -l)" "10"

# --- Requirement 6: director and actor ---
# Second way: count with grep. The name must be between "|" or at the edge of the cell.
DIRECTOR=$(sed -n '2p' out/6_director_actor.txt | awk '{$1=""; print substr($0,2)}')
ACTOR=$(sed -n '5p' out/6_director_actor.txt | awk '{$1=""; print substr($0,2)}')
check "req 6: director '$DIRECTOR'" "$(sed -n '2p' out/6_director_actor.txt | awk '{print $1}')" "$(tail -n +2 $F | cut -f9 | tr '|' '\n' | grep -c -x "$DIRECTOR")"
check "req 6: actor '$ACTOR'" "$(sed -n '5p' out/6_director_actor.txt | awk '{print $1}')" "$(tail -n +2 $F | cut -f7 | tr '|' '\n' | grep -c -x "$ACTOR")"

# --- Requirement 7: genres ---
# Second way: the genre counts must add up to the number of all genre names in column 14.
check "req 7: sum of the genre counts" "$(tail -n +2 out/7_genres.txt | awk '{s=s+$1} END{print s}')" "$(tail -n +2 $F | cut -f14 | tr '|' '\n' | awk 'NF' | wc -l)"

echo
echo "Done. If a check above did not pass, look at it before using the results."