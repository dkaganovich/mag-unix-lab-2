#!/usr/bin/env bash

# SYNOPSIS: 
# 	arg1 - path regular expression (grep BRE)
#	arg2 - interval(optional)
function percread() {
	# utility method to calculate file size
	function _calc_file_size() {
		local path="$1"
		if ! rec=$(lsof -s -F s "$path" 2>/dev/null); then # -s show size
			echo "Failed to read file size data: file was closed" >&2
			return 1
		fi
		if [ -z "$rec" ]; then
			echo "Failed to read file size data: no data provided" >&2
			return 1
		fi
		file_size=$(cut -c2- <(echo "$rec" | sed -n 2p))
		echo "$file_size"
		return 0
	}
	# convenience method
	function _percread() {
		local path="$1"
		local file_size="$2"
		local rec
		if ! rec=$(lsof -oo0 -F o "$path" 2>/dev/null); then # -o show offset -o0 in decimal format
			echo "Failed to read file offset data: file was closed" >&2
			return 1
		fi
		if [ -z "$rec" ]; then
			echo "Failed to read file offset data: no data provided" >&2
			return 1
		fi
		local file_offset=$(cut -c4- <(echo "$rec" | sed -n 2p)) # cut off 0t decimal prefix
		if [ -z "$file_size" ]; then
			file
		fi
		local file_perc=$(awk "BEGIN {printf \"%6.2f\", 100.0 * ${file_offset} / ${file_size}}")
		echo "$file_perc"
		return 0
	}
	#
	local path_regex="$1"
	local interval="$2"
	if [ -z $"path_regex" ]; then
		echo "Required argument: path_regex" >&2
		return 1
	fi
	echo "Please wait. It may take a while..."
	# local path=$(lsof | awk -v pattern="$path_regex" '$0 ~ pattern {print $9}') # ERE
	local path_str=$(lsof | awk '{if(NR>1){print $9}}' | grep "$path_regex") # BRE
	if [ -z "$path_str" ]; then
		echo "Illegal argument: regex does not match any files" >&2
		return 1
	fi
	local m_cnt=$(echo "$path_str" | wc -l)
	if [ "$m_cnt" -gt 1 ]; then
		echo "Illegal argument: regex matches multiple files" >&2
		return 1
	fi
	local path=$(echo -e "$path_str")
	echo "Tracking file '$path_str'"
	local file_size # persist file size to speed up perc% calculations
	if ! file_size=$(_calc_file_size "$path"); then
		echo "Unexpected error: $file_size" >&2
		return 1
	fi
	echo "File size: $file_size"
	local perc
	if [ -n "$interval" ]; then
		while $(lsof "$path" >/dev/null 2>&1); do
			if ! perc=$(_percread "$path" "$file_size" 2>&1); then
				echo "Unexpected error: $perc" >&2
				return 1
			fi
			echo -ne "File read: $perc%"\\r
			sleep "$interval"
		done
		echo "File '$path_str' was closed"
	else
		if ! perc=$(_percread "$path" "$file_size" 2>&1); then
			echo "Unexpected error: $perc" >&2
			return 1
		fi
		echo "$perc"
	fi
	return 0
}

function watchfile() {
	local interval=1
	percread "$1" "$interval"
	return "$?"
}
