# Big 12-hour clock: 3x5 pixel digits (each pixel 2 cells), lit █ unlit ░ like ascii.rest. 32 wide = calendar width.
SEG=(abcdef bc abdeg abcdg bcfg acdfg acdefg abc abcdefg abcdfg)
px() { [[ $S == *["$1"]* ]] && printf %s "$C██" || printf %s "$F░░"; } # lit if any of the segments in $1 is on
digit() { # digit <0-9|x> <row 0-4>
  S=''; [[ $1 == [0-9] ]] && S=${SEG[$1]}
  case $2 in
    0) px af; px a; px ab ;;
    1) px f; printf '  '; px b ;;
    2) px efg; px g; px bcg ;;
    3) px e; printf '  '; px c ;;
    4) px de; px d; px cd ;;
  esac
}
w_clock() {
  local h m r pad; read -r h m < <(date '+%-I %M'); printf -v pad "%$(((LW - 32) / 2))s" ''
  echo
  for r in 0 1 2 3 4; do
    printf %s "$pad"; digit "$( ((h >= 10)) && echo 1 || echo x)" "$r"; printf '  '; digit $((h % 10)) "$r"
    if ((r == 1 || r == 3)); then printf " ${C}██${N} "; else printf '    '; fi
    digit "${m:0:1}" "$r"; printf '  '; digit "${m:1:1}" "$r"; printf "${N}\n"
  done
  echo
}
