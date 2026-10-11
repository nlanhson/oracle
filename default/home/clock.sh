# Big 12-hour clock, seven segments (lit █, unlit ░), date underneath.
SEG=(abcdef bc abdeg abcdg bcfg acdfg acdefg abc abcdefg abcdfg)
digit() { # digit <0-9|blank> <row 0-6>, 8 wide like ascii.rest
  local s=''; [[ $1 == [0-9] ]] && s=${SEG[$1]}
  on() { if [[ $s == *$1* ]]; then printf %s "$C$2"; else printf %s "$F${2//█/░}"; fi; }
  case $2 in
    0) printf '  '; on a ████; printf '  ' ;;
    1 | 2) on f ██; printf '    '; on b ██ ;;
    3) printf '  '; on g ████; printf '  ' ;;
    4 | 5) on e ██; printf '    '; on c ██ ;;
    6) printf '  '; on d ████; printf '  ' ;;
  esac
}
w_clock() {
  local t h m r p d
  t=$(LC_ALL=C date '+%I %M %p %A %-d %B') && read -r h m p d <<<"$t"
  p=${p,,} d=${d,,} h=$((10#$h))
  local pad; printf -v pad "%$(((LW - 40) / 2))s" ''
  echo
  for r in 0 1 2 3 4 5 6; do
    printf %s "$pad"; digit "$( ((h >= 10)) && echo 1 || echo x)" "$r"; printf '  '; digit $((h % 10)) "$r"
    if ((r == 2 || r == 4)); then printf " ${C}██${N} "; else printf '    '; fi
    digit "${m:0:1}" "$r"; printf '  '; digit "${m:1:1}" "$r"; printf "${N}\n"
  done
  echo; printf "%s${C}%s${D} · %s${N}\n\n" "$pad" "$p" "$d"
}
