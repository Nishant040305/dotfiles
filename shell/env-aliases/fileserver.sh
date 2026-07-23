# Expose files to network
fileserver() {
	filebrowser -r "$HOME" -a "${HOSTNAME:-fedora}" -p 8080 -d ~/.local/share/filebrowser/filebrowser.db
}
