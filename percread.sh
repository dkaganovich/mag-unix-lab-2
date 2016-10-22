#!/usr/bin/env bash

function _percread() {
	local path="$1"
	local rec
	if ! rec=$(lsof -oo0 "$path" 2>/dev/null); then # -o show offset -o0 in decimal format
		echo "Failed to read file offset data: file was closed"
		return 1
	fi
	local file_offset=$(cut -c3- <(echo "$rec" | sed -n 2p | awk '{print $7}')) # cut off 0t decimal prefix
	if ! rec=$(lsof -s -o0 "$path" 2>/dev/null); then # -s show size
		echo "Failed to read file size data: file was closed"
		return 1
	fi
	local file_size=$(echo "$rec" | sed -n 2p | awk '{print $7}')
	local file_perc=$(awk "BEGIN {printf \"%6.2f\", 100.0 * ${file_offset} / ${file_size}}")
	echo "$file_perc"
	return 0
}

# SYNOPSIS: 
# 	arg1 - path regular expression (grep BRE)
#	arg2 - interval(optional)
function percread() {
	local path_regex="$1"
	local interval="$2"
	if [ -z $"path_regex" ]; then
		echo "Required argument: path_regex"
		return 1
	fi
	echo "Please wait. It may take a while..."
	# local path=$(lsof | awk -v pattern="$path_regex" '$0 ~ pattern {print $9}') # ERE
	local path=$(lsof | awk '{print $9}' | grep "$path_regex") # BRE
	if [ -z "$path" ]; then
		echo "Illegal argument: regex does not match any files"
		return 1
	fi
	if [[ "$path" =~ $'\n' ]]; then
		echo "Illegal argument: regex matches multiple files"
		return 1
	fi
	echo "Tracking file '$path'"
	local perc
	if [ -n "$interval" ]; then
		while $(lsof "$path" >/dev/null 2>&1); do
			if ! perc=$(_percread "$path"); then
				echo "Unexpected error: $perc"
				return 1
			fi
			echo -ne "File read: $perc%"\\r
			sleep "$interval"
		done
		echo "File '$path' was closed"
	else
		if ! perc=$(_percread "$path"); then
			echo "Unexpected error: $perc"
			return 1
		fi
		echo "$perc"
	fi
	return 0
}

function watchfile() {
	local interval=1
	percread "$1" "$interval"
	return 0
}
