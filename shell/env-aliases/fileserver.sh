# Expose files to network
fileserver() {
	filebrowser -r $HOME -a rotom -p 8080 -d ~/.local/share/filebrowser/filebrowser.db
}
