#!/bin/bash

# Create directories
mkdir -p $1/conversion
mkdir -p $1/converted
mkdir -p $1/old

# Loopie
for file in $(find $1 -maxdepth 1 -type f -printf "%f\n")
do
  # Create file names
  extension="${file##*.}"
  filename="${file%.*}"
  new="$filename.x265.mp4" 
  filetoconvert="$1/$file"
  conversionfile1="$1/conversion/${new,,}.tmp"
  conversionfile2="$1/conversion/${new,,}"
  convertedfile="$1/converted/${new,,}"
  donefile="$1/old/$file"
  
  echo "Conversion for $filetoconvert to $convertedfile"

  # Do the actual conversion
  docker run --rm --device /dev/dri:/dev/dri -v $1:$1 jrottenberg/ffmpeg:vaapi -hwaccel vaapi -hwaccel_output_format vaapi -i $filetoconvert -vf 'yadif' $conversionfile1
  docker run --rm --device /dev/dri:/dev/dri -v $1:$1 jrottenberg/ffmpeg:vaapi -hwaccel vaapi -hwaccel_output_format vaapi -i $conversionfile1 -vf 'scale_vaapi=w=1280:h=720' -c:v hevc_vaapi $conversionfile2

  # Move/Cleanuo
  rm conversionfile1
  mv $conversionfile2 $convertedfile
  mv $filetoconvert $donefile

done
