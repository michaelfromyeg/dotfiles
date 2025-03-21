#!/usr/bin/env bash

# Show user stats (commits, files modified, insertions, deletions, and total
# lines modified) for your current repository.

# Fork of https://gist.githubusercontent.com/shitchell/783cc8a892ed1591eca2afeb65e8720a/raw/git-user-stats.

# Process command line arguments
git_log_opts=( "$@" )

# Print header
printf "%-30s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\n" \
       "Email" "Commits" "Files" "Insertions" "Deletions" "Total Lines"
printf "%-30s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\n" \
       "-----" "-------" "-----" "----------" "---------" "-----------"

# Use git log to get data, and process with simple awk script
git log "${git_log_opts[@]}" --format='author: %ae' --numstat \
    | tr '[A-Z]' '[a-z]' \
    | grep -v '^$' \
    | grep -v '^-' \
    | awk '
        {
            if ($1 == "author:") {
                author = $2;
                commits[author]++;
            } else {
                insertions[author] += $1;
                deletions[author] += $2;
                total[author] += $1 + $2;
                # if this is the first time seeing this file for this
                # author, increment their file count
                author_file = author ":" $3;
                if (!(author_file in seen)) {
                    seen[author_file] = 1;
                    files[author]++;
                }
            }
        }
        END {
            # Print the stats for each user
            for (email in total) {
                printf("%-30s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\n",
                       email, commits[email], files[email],
                       insertions[email], deletions[email], total[email]);
            }
        }
    ' | sort -k6,6nr  # Sort by total lines column in descending order
