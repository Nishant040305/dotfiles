# GNU Stow

Clone the repository
```bash
cd ~
git clone https://github.com/Aryan10/dotfiles .dotfiles
```

Install GNU Stow
```bash
sudo dnf install stow
```

From your dotfiles directory:
```bash
cd ~/.dotfiles
stow *
```

Run the above to symlink all stow packages into your home directory.