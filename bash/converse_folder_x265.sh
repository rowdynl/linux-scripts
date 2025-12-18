#!/bin/bash

# Create directories
cd "$1"
mkdir -p conversion
mkdir -p converted
mkdir -p old

# Loopie
for file in $(find ./ -maxdepth 1 -type f -printf "%f\n")
do
  # Create file names
  extension="${file##*.}"
  filename="${file%.*}"
  new="$filename.x265.mp4" 
  filetoconvert="/work/$file"
  conversionfile="/work/conversion/${new,,}"
  convertedfile="/work/converted/${new,,}"
  donefile="/work/old/$file"
  
  echo "Conversion for $filetoconvert to $convertedfile"

  # Do the actual conversion
  docker run --rm --device /dev/dri:/dev/dri -v "$1":/work jrottenberg/ffmpeg:vaapi -hwaccel vaapi -hwaccel_output_format vaapi -i $filetoconvert -vf 'scale_vaapi=w=1280:h=720' -c:v hevc_vaapi $conversionfile

  # Move/Cleanuo  
  mv $conversionfile $convertedfile
  mv $filetoconvert $donefile

done
