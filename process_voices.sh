#!/bin/bash

# Set directories
input_dir="/mnt/d/voices/"
output_dir="/mnt/d/voices/"
temp_dir="$HOME/vocal-remover/"

# Find all .mp3 files in the input directory
find "$input_dir" -type f -iname "*.mp3" | while read -r file; do
    # Run python inference.py for each file
    python inference.py --input "$file"
done

# Move to the temporary directory with vocal remover results
cd "$temp_dir"

# Find all .wav files with "Vocals" in the name
find . -type f -iname "*Vocals*.wav" | while read -r wav_file; do
    # Copy the .wav files to the output directory
    cp "$wav_file" "$output_dir"
done
