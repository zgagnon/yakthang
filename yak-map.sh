#!/usr/bin/env bash
set -euo pipefail

DIM='\033[2m'
CYAN='\033[36m'
RESET='\033[0m'
CLEAR='\033[2J\033[H'

render_yak_map() {
	yx_output=$(yx ls)

	declare -a path_stack=()
	declare -A depth_map
	output_buffer=""

	while IFS= read -r line; do
		clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')

		if [ -z "$clean_line" ]; then
			output_buffer+="${line}"$'\n'
			continue
		fi

		task_name=$(echo "$clean_line" | sed -E 's/^[[:space:]│├─╰]*[[:space:]]*[●○][[:space:]]*//')

		if [ -z "$task_name" ]; then
			output_buffer+="${line}"$'\n'
			continue
		fi

		indent=$(echo "$clean_line" | awk '{match($0, /^[[:space:]│]*/); print RLENGTH}')
		has_connector="no"
		if echo "$clean_line" | grep -q -E '^[[:space:]│]*[├╰]'; then
			has_connector="yes"
		fi

		depth=-1
		if [ "$has_connector" = "no" ]; then
			depth=0
			path_stack=()
		else
			for d in "${!depth_map[@]}"; do
				if [ "${depth_map[$d]}" = "$indent" ]; then
					depth=$d
					break
				fi
			done

			if [ "$depth" = -1 ]; then
				depth=$((${#path_stack[@]}))
				depth_map[$depth]=$indent
			fi

			while [ ${#path_stack[@]} -gt $depth ]; do
				unset 'path_stack[-1]'
			done
		fi

		path_stack+=("$task_name")

		full_path=$(
			IFS=/
			echo "${path_stack[*]}"
		)

		assigned_to=""
		field_file=".yaks/${full_path}/assigned-to"

		if [ -f "$field_file" ]; then
			assigned_to=$(cat "$field_file" | tr -d '\n')
		fi

		if [ -n "$assigned_to" ]; then
			prefix=$(echo "$line" | sed -E 's/(.*[●○][[:space:]]*).*/\1/')
			suffix=$(echo "$line" | sed -E 's/.*[●○][[:space:]]*(.*)/\1/')
			output_buffer+=$(echo -e "${prefix}${DIM}${CYAN}[${assigned_to}]${RESET} ${suffix}")$'\n'
		else
			output_buffer+="${line}"$'\n'
		fi
	done <<<"$yx_output"

	printf '%s' "$output_buffer"
}

while true; do
	buffer=$(render_yak_map)
	echo -ne "$CLEAR"
	printf '%s' "$buffer"
	sleep 2
done
