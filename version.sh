#!/bin/bash
# Increment build number across all targets and append country + username

cd "$SRCROOT"

# Current date
current_date=$(date "+%Y%m%d")

# Get macOS username
build_user=$(whoami)

# Get locale like: en_US@rg=DEZZZZ
locale=$(defaults read -g AppleLocale 2>/dev/null)

# Remove anything after @
locale_no_variant="${locale%%@*}"

# Extract country code (part after underscore)
country_code="${locale_no_variant##*_}"

# Fallback
if [ -z "$country_code" ]; then
  country_code="XX"
fi

# Read previous build number
previous_build_number=$(awk -F "=" '/BUILD_NUMBER/ {print $2}' Config.xcconfig | tr -d ' ')

# Extract date + counter from previous build number
previous_date="${previous_build_number%%.*}"
rest="${previous_build_number#*.}"
counter="${rest%%.*}"

# Increment or reset counter
if [[ "$current_date" == "$previous_date" ]]; then
  new_counter=$((counter + 1))
else
  new_counter=1
fi

# New build number with country + user
new_build_number="${current_date}.${new_counter}.${country_code}.${build_user}"

# Replace in config
sed -i -e "/BUILD_NUMBER =/ s/= .*/= $new_build_number/" Config.xcconfig

# Remove sed backup
rm -f Config.xcconfig-e
