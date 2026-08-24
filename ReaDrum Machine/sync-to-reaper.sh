#!/bin/zsh
# Sync script files from ReaDrum Machine folder to REAPER Scripts folder
# Usage: ./sync-to-reaper.sh "file1.lua" "Modules/file2.lua" ...

TARGET="/Users/Shared/REAPER/Scripts/Suzuki Scripts/ReaDrum Machine"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ $# -eq 0 ]]; then
  echo "No files specified. Syncing all .lua files and index.xml..."
  # Find all .lua files in SOURCE_DIR and subdirectories, plus index.xml from parent
  files_to_sync=()
  while IFS= read -r file; do
    # Store relative path by removing SOURCE_DIR prefix
    relative_path="${file#$SOURCE_DIR/}"
    files_to_sync+=("$relative_path")
  done < <(find "$SOURCE_DIR" -name "*.lua" -type f)
  
  # Add index.xml from parent directory if it exists
  parent_index="$(dirname "$SOURCE_DIR")/index.xml"
  if [[ -f "$parent_index" ]]; then
    files_to_sync+=("../index.xml")
  fi
  
  if [[ ${#files_to_sync[@]} -eq 0 ]]; then
    echo "❌ No .lua files found in $SOURCE_DIR"
    exit 1
  fi
  
  echo "Found ${#files_to_sync[@]} .lua files to sync"
else
  # Use specified files
  files_to_sync=("$@")
fi

for file in "${files_to_sync[@]}"; do
  # Handle index.xml from parent directory - copy to parent Scripts folder
  if [[ "$file" == "../index.xml" ]]; then
    SOURCE="$(dirname "$SOURCE_DIR")/index.xml"
    # TARGET is /Users/Shared/REAPER/Scripts/Suzuki Scripts/ReaDrum Machine
    # We want /Users/Shared/REAPER/Scripts/index.xml
    REAPER_SCRIPTS="$(echo "$TARGET" | sed 's|/Suzuki Scripts/ReaDrum Machine||')"
    cp "$SOURCE" "$REAPER_SCRIPTS/index.xml"
    echo "✓ Copied: index.xml to $REAPER_SCRIPTS/"
    continue
  fi
  
  SOURCE="$SOURCE_DIR/$file"
  
  if [[ ! -f "$SOURCE" ]]; then
    echo "❌ File not found: $file"
    continue
  fi
  
  # Create directory structure in target
  dir="$TARGET/$(dirname "$file")"
  mkdir -p "$dir"
  
  # Copy file
  cp -v "$SOURCE" "$dir/"
  echo "✓ Copied: $file"
done

echo "Done!"
