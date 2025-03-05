#!/bin/zsh

# Configuration
CLAUSES_DIR="/Users/steffenbuhlert/Downloads/clauses"
OUTPUT_MD="output.md"
OUTPUT_DOCX="output.docx"

# Check dependencies
type dialog >/dev/null 2>&1 || { echo "dialog is required but not installed. Install it with 'brew install dialog'"; exit 1; }
type pandoc >/dev/null 2>&1 || { echo "pandoc is required but not installed. Install it with 'brew install pandoc'"; exit 1; }

# Ensure clauses directory exists
if [[ ! -d "$CLAUSES_DIR" ]]; then
    echo "Clauses directory '$CLAUSES_DIR' does not exist. Create it and add plaintext clauses." >&2
    exit 1
fi

# Step 1: Select clauses
selected_clauses=()
while IFS= read -r file; do
    selected_clauses+=("$(basename "$file")")
done < <(find "$CLAUSES_DIR" -type f)

if [[ ${#selected_clauses[@]} -eq 0 ]]; then
    echo "No clauses found in '$CLAUSES_DIR'. Add some plaintext files and try again." >&2
    exit 1
fi

choices=()
for clause in "${selected_clauses[@]}"; do
    choices+=("$clause" "Clause from $clause" "off")
done

selected=$(dialog --stdout --checklist "Select clauses for the agreement" 20 60 15 ${choices[@]})

if [[ -z "$selected" ]]; then
    echo "No clauses selected. Exiting."
    exit 1
fi

selected_clauses=(${(z)selected})

# Step 2: Order and Structure
ordered_clauses=()
temp_clauses=(${selected_clauses[@]})
while [[ ${#temp_clauses[@]} -gt 0 ]]; do
    menu_items=()
    for clause in "${temp_clauses[@]}"; do
        menu_items+=("$clause" "Select to reorder")
    done
    menu_items+=("CUSTOM_HEADER" "Add a custom header")
    ordered=$(dialog --stdout --menu "Reorder clauses or add a custom header" 20 60 15 ${menu_items[@]})
    if [[ -z "$ordered" ]]; then
        break
    fi
    if [[ "$ordered" == "CUSTOM_HEADER" ]]; then
        custom_header=$(dialog --stdout --inputbox "Enter custom header title" 10 50)
        header_level=$(dialog --stdout --menu "Select header level for $custom_header" 10 30 3 "#" "Main Header" "##" "Subheader" "###" "Sub-subheader")
        ordered_clauses+=("$header_level $custom_header CUSTOM")
    else
        header_level=$(dialog --stdout --menu "Select header level for $ordered" 10 30 3 "#" "Main Header" "##" "Subheader" "###" "Sub-subheader")
        ordered_clauses+=("$header_level $ordered")
        temp_clauses=(${temp_clauses:#$ordered})
    fi

done

# Step 3: Generate Markdown
cat /dev/null > "$OUTPUT_MD"
echo "# Draft Agreement" >> "$OUTPUT_MD"
for entry in "${ordered_clauses[@]}"; do
    header=$(echo "$entry" | awk '{print $1}')
    clause=$(echo "$entry" | cut -d' ' -f2-)
    if [[ "$clause" == *" CUSTOM" ]]; then
        echo "$header ${clause% CUSTOM}" >> "$OUTPUT_MD"
    else
        echo "$header ${clause%.*}" >> "$OUTPUT_MD"
        cat "$CLAUSES_DIR/$clause" >> "$OUTPUT_MD"
    fi
    echo "" >> "$OUTPUT_MD"
done

# Step 4: Preview
dialog --stdout --textbox "$OUTPUT_MD" 30 80

# Step 5: Confirm
if dialog --stdout --yesno "Is the draft acceptable?" 10 30; then
    pandoc "$OUTPUT_MD" -o "$OUTPUT_DOCX"
    echo "DOCX file generated: $OUTPUT_DOCX"
else
    echo "Restarting selection process..."
    exec "$0"
fi
