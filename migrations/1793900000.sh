# Existing installs don't get the first-run welcome guide after an update (fresh installs mark migrations done without running them, so they do). oracle welcome still works by hand.
mkdir -p ~/.local/state/oracle/done && touch ~/.local/state/oracle/done/welcome
