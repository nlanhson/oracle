# Pick lists + network + wallpaper helpers shared by oracle settings and oracle welcome. Needs theme.sh, BW, LINES and a draw() that redraws the screen behind a list.
# shellcheck shell=bash disable=SC2034
place() { read -r ROWS COLS < <(stty size); BX=$(((COLS - BW) / 2)); BY=$(((ROWS - ${#LINES[@]} - 2) / 2)); ((BX < 1)) && BX=1; ((BY < 1)) && BY=1; }
pick() { # pick <title> <options...> → PICK (empty = cancelled). Long lists: type to search.
  local t=$1 s=0 top=0 q='' i h; shift; local all=("$@") v; PICK=''
  while :; do
    v=(); for i in "${all[@]}"; do [[ -z $q || ${i,,} == *"${q,,}"* ]] && v+=("$i"); done
    read -r ROWS COLS < <(stty size); h=$((ROWS - 12)); ((h > 18)) && h=18; ((h < 3)) && h=3
    ((s >= ${#v[@]})) && s=$((${#v[@]} - 1)); ((s < 0)) && s=0
    ((s < top)) && top=$s; ((s >= top + h)) && top=$((s - h + 1))
    LINES=(''); (($# > 8)) && LINES+=("  ${D}search ${W}$q${C}▏$N" ''); local first=${#LINES[@]}
    for ((i = top; i < top + h && i < ${#v[@]}; i++)); do
      if ((i == s)); then LINES+=("$C> ${v[i]:0:BW-6}$N"); else LINES+=("  $W${v[i]:0:BW-6}$N"); fi
    done
    ((${#v[@]})) || LINES+=("  ${D}no match$N"); LINES+=(''); place
    printf '\e[?2026h\e[H\e[2J'; box "$t" "$( (($# > 8)) && printf 'type to search · ')enter choose · esc back"; printf '\e[?2026l'
    key || return
    case $KEY in
      up) ((s--)) ;; down | tab) ((s++)) ;; esc | back) return ;;
      click) i=$((top + MY - BY - 1 - first)); ((i >= top && i < ${#v[@]} && MY - BY - 1 >= first)) && { PICK=${v[i]}; return; } ;;
      enter) ((${#v[@]})) && PICK=${v[s]}; return ;;
      k | j | q) if (($# > 8)); then q+=$KEY; elif [[ $KEY == q ]]; then return; elif [[ $KEY == k ]]; then ((s--)); else ((s++)); fi ;;
      backspace) q=${q%?} ;; space) q+=' ' ;;
      ?) (($# > 8)) && q+=$KEY ;;
    esac
  done
}
prompt() { # prompt <text> → REPLY (hidden input)
  printf '\e[%d;%dH%s%s%s: %s\e[?25h' $((BY + ${#LINES[@]} + 3)) $((BX + 2)) "$NOMOUSE" "$W" "$1" "$N"; read -rs REPLY; printf '\e[?25l'
}
wifi() {
  local l s; MSG="scanning…"; draw
  mapfile -t l < <(nmcli -t -f ssid,signal,security dev wifi list --rescan yes 2>/dev/null | awk -F: '$1!="" && !s[$1]++ {printf "%-28s %3s%%  %s\n", $1, $2, ($3==""?"open":"locked")}')
  ((${#l[@]})) || { MSG="no networks found"; return; }
  pick wifi "${l[@]}"; [[ -n $PICK ]] || return
  s=$(sed 's/ *[0-9]*%.*$//' <<<"$PICK")
  if nmcli dev wifi connect "$s" >/dev/null 2>&1; then MSG="connected to $s"; return; fi
  draw; prompt "password for $s"; nmcli dev wifi connect "$s" password "$REPLY" >/dev/null 2>&1 && MSG="connected to $s" || MSG="could not connect to $s"
}
wallpaper() { # desktop wallpaper (swaybg): a picture from ~/Pictures, or black
  local l; mapfile -t l < <(find ~/Pictures ~/Wallpapers -maxdepth 3 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sed "s|^$HOME|~|" | sort)
  pick wallpaper black "${l[@]}"; [[ -n $PICK ]] || return
  if [[ $PICK == black ]]; then oracle set wallpaper; else oracle set wallpaper "${PICK/#\~/$HOME}"; fi
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && oracle wall; MSG="wallpaper: ${PICK##*/}"
}
