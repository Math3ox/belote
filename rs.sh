#!/bin/sh
# lance le port Rust dans WSL (Debian) depuis le dossier du projet
exec wsl.exe -d Debian -e sh -c "cd /mnt/c/Users/User/projets/belote-win && \$HOME/belote_target/release/belote_rs $*" 2>&1 | grep -v "dbhomeXE\|automount"
