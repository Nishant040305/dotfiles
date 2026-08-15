ipynb2pdf() {
    local zoom=100
    local notebook=""
    local output=""
    local tmp_dir=""
    local browser=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
Usage:
  ipynb2pdf [OPTIONS] notebook.ipynb [output.pdf]

Convert a Jupyter notebook to PDF using nbconvert + Chromium.
The notebook is NOT executed.

Options:
  -h, --help          Show this help message
  --zoom PERCENT      Set print zoom (default: 100)
  --zoom=PERCENT      Same as above

Examples:
  ipynb2pdf assignment.ipynb
  ipynb2pdf assignment.ipynb assignment.pdf
  ipynb2pdf --zoom 85 assignment.ipynb
  ipynb2pdf --zoom=85 assignment.ipynb assignment.pdf
EOF
                return 0
                ;;

            --zoom)
                if [[ -z "$2" ]]; then
                    echo "Error: --zoom requires a value."
                    return 1
                fi
                zoom="$2"
                shift 2
                ;;

            --zoom=*)
                zoom="${1#*=}"
                shift
                ;;

            -*)
                echo "Error: unknown option: $1"
                echo "Use 'ipynb2pdf --help' for usage."
                return 1
                ;;

            *)
                if [[ -z "$notebook" ]]; then
                    notebook="$1"
                elif [[ -z "$output" ]]; then
                    output="$1"
                else
                    echo "Error: too many arguments."
                    echo "Use 'ipynb2pdf --help' for usage."
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate notebook argument
    if [[ -z "$notebook" ]]; then
        echo "Error: no notebook specified."
        echo "Use 'ipynb2pdf --help' for usage."
        return 1
    fi

    if [[ ! -f "$notebook" ]]; then
        echo "Error: notebook not found: $notebook"
        return 1
    fi

    # Validate zoom
    if ! [[ "$zoom" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "Error: zoom must be a positive number."
        return 1
    fi

    if (( $(echo "$zoom <= 0" | bc -l) )); then
        echo "Error: zoom must be greater than 0."
        return 1
    fi

    # Default output name
    if [[ -z "$output" ]]; then
        output="${notebook%.ipynb}.pdf"
    fi

    # Find Chromium/Chrome
    for browser in chromium chromium-browser google-chrome google-chrome-stable; do
        if command -v "$browser" >/dev/null 2>&1; then
            break
        fi
    done

    if ! command -v "$browser" >/dev/null 2>&1; then
        echo "Error: Chromium/Chrome not found."
        echo "Install with: sudo dnf install chromium"
        return 1
    fi

    # Create temporary directory
    tmp_dir="$(mktemp -d)"

    echo "→ Converting notebook to HTML..."

    if ! jupyter nbconvert \
        --to html \
        --output-dir="$tmp_dir" \
        "$notebook"; then
        rm -rf "$tmp_dir"
        return 1
    fi

    local html="$tmp_dir/$(basename "${notebook%.ipynb}.html")"

    if [[ ! -f "$html" ]]; then
        echo "Error: nbconvert did not produce the expected HTML file."
        rm -rf "$tmp_dir"
        return 1
    fi

    # Inject print CSS
    python3 - "$html" "$zoom" <<'PY'
import sys

path = sys.argv[1]
zoom = float(sys.argv[2]) / 100

with open(path, "r", encoding="utf-8") as f:
    html = f.read()

css = f"""
<style>
@media print {{
    body {{
        zoom: {zoom};
    }}

    .input_area pre,
    .input_area .highlight pre,
    .highlight pre {{
        white-space: pre-wrap !important;
        overflow-wrap: anywhere !important;
        word-break: break-word !important;
    }}
}}
</style>
"""

html = html.replace("</head>", css + "</head>", 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(html)
PY

    echo "→ Printing HTML to PDF (${zoom}% zoom)..."

    if ! "$browser" \
        --headless \
        --disable-gpu \
        --no-sandbox \
        --no-pdf-header-footer \
        --print-to-pdf="$(realpath "$output")" \
        "file://$(realpath "$html")" \
        >/dev/null 2>&1; then

        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$tmp_dir"

    echo "✓ Created: $output"
}
