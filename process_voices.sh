#!/bin/bash

# Read directories from config.json
input_dir=$(jq -r '.input_dir' config.json)
output_dir=$(jq -r '.output_dir' config.json)
vocal_remover_dir=$(jq -r '.vocal_remover_dir' config.json)
main_dir=$(jq -r '.main_dir' config.json)
echo "$input_dir"
# Move to the vocal remover directory with the results
# shellcheck disable=SC2164
cd "$vocal_remover_dir"

# Create a temporary directory to store split files
temp_split_dir=$(mktemp -d)

# Find all .mp3 files in the input directory
find "$input_dir" -type f -iname "*.mp3" | while read -r file; do
    # Get the file size in bytes and convert it to megabytes
    file_size_mb=$(($(stat -c%s "$file") / 1048576))

    if [ $file_size_mb -gt 10 ]; then
        # Get the duration of the input file in seconds
        duration=$(ffprobe -i "$file" -show_entries format=duration -v quiet -of csv="p=0")

        # Calculate the number of parts needed to split the file
        num_parts=$((file_size_mb / 10 + 1))

        # Calculate the duration of each part in seconds
        part_duration=$(awk -v d="$duration" -v n="$num_parts" 'BEGIN { printf "%.2f", d / n }')

        # Split the file into parts using ffmpeg
        for ((i = 0; i < num_parts; i++)); do
            start_time=$(awk -v i="$i" -v pd="$part_duration" 'BEGIN { printf "%.2f", i * pd }')
            # Convert decimal start_time to HH:MM:SS format
            start_time_formatted=$(awk -v t="$start_time" 'BEGIN { t=int(t); printf "%02d:%02d:%02d\n", t/3600, t%3600/60, t%60 }')

            output_file="$temp_split_dir/$(basename "$file")_part${i}.mp3"
            ffmpeg -i "$file" -ss "$start_time_formatted" -t "$part_duration" -vn -acodec copy -y "$output_file" < /dev/null
        done

        # Iterate through the split parts and pass them to inference.py
        for part in "$temp_split_dir/"*; do
            python inference.py --input "$part"
        done

        # Clean up the temporary directory
        rm -f "$temp_split_dir/"*
    else
        # Run python inference.py for the file
        python inference.py --input "$file"
    fi
done

# Find all .wav files with "Vocals" in the name
find . -type f -iname "*Vocals*.wav" | while read -r wav_file; do
    # Move the .wav files to the output directory
    mv "$wav_file" "$output_dir"
done

find . -type f -iname "*Instruments*.wav" | while read -r wav_file; do
    # Remove the temp .wav files
    rm "$wav_file"
done

# shellcheck disable=SC2164
cd "$main_dir"
python main.py