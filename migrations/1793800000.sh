# Snapshot boot menu: limine-snapper-sync needs inotifywait to keep watching (doctor showed it "not running")
sudo pacman -S --needed --noconfirm inotify-tools
sudo systemctl restart limine-snapper-sync.service
