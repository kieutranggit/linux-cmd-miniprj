# clean_data.py - turn tmdb-movies.csv into clean_data.tsv (columns separated by a Tab).
#
# Why: some cells contain commas or line breaks (for example the movie overview).
# Linux commands such as awk, cut and sort would split those lines in the wrong place.
# The csv module understands the quotes, so it reads every cell correctly.
# Then I remove line breaks and tabs inside the cells and join the cells with a Tab.

import csv
with open("tmdb-movies.csv", encoding="utf-8", newline="") as fin:
	with open("clean_data.tsv","w", encoding="utf-8") as fout:
		reader = csv.reader(fin)             # reads one row (a list of cells) at a time
		for row in reader:
			new_row = []
			for cell in row:
				cell = cell.replace("\n", "")    # remove line breaks inside the cell
				cell = cell.replace("\r", "")
				cell = cell.replace("\t", "")    # a Tab inside a cell would break the columns
				new_row.append(cell)
			fout.write("\t".join(new_row) + "\n")   # one row = one line, cells joined by a Tab