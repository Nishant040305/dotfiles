# Create a bootable url file
mkopen() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: mkopen <url> <filename>"
    return 1
  fi

  local url="$1"
  local filename="$2"

  echo "<meta http-equiv=\"refresh\" content=\"0; url=${url}\">" > "${filename}.html"
}
