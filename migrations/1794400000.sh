# Behaviour: two-finger swipe goes back/forward in Brave Origin (only if you still have the Oracle flags file and it lacks the line)
F=$HOME/.config/brave-origin-flags.conf
[[ ! -f $F ]] || grep -q TouchpadOverscrollHistoryNavigation "$F" || printf '%s\n' '--enable-features=TouchpadOverscrollHistoryNavigation' >>"$F"
