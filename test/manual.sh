#!/usr/bin/env bash
# Fails if a command in bin/oracle is missing from oracle manual (bin/oracle-manual), the manual lists one that doesn't exist,
# an entry has an empty field, or oracle help stops pointing at the manual. No docker needed: bash test/manual.sh
cd "$(dirname "$0")/.." || exit 1
fail=0
cmds=$(sed -nE 's/^  ([a-z][a-z |*-]*)\).*/\1/p' bin/oracle | tr '|' '\n' | tr -d ' *' | grep . | sort -u)
man=$(bash bin/oracle-manual --names | sort)
for c in $(comm -23 <(echo "$cmds") <(echo "$man")); do echo "missing from the manual: oracle $c"; fail=1; done
for c in $(comm -13 <(echo "$cmds") <(echo "$man")); do echo "in the manual, not in bin/oracle: oracle $c"; fail=1; done
[[ -z $(uniq -d <<<"$man") ]] || { echo "listed twice: $(uniq -d <<<"$man")"; fail=1; }
while IFS='|' read -r n u k w when ex extra; do
  [[ -n $n && $u == "oracle $n"* && $k =~ ^(go|ask|tui|auto)$ && -n $w && -n $when && $ex == "oracle $n"* && -z $extra ]] || { echo "bad entry: $n"; fail=1; }
done < <(sed -n '/^CMDS=(/,/^)/p' bin/oracle-manual | sed '1d;$d; s/^"//; s/"$//')
for c in update rollback restore backup; do grep -q "^\"$c|[^|]*|ask|" bin/oracle-manual || { echo "oracle $c must ask first"; fail=1; }; done
bash bin/oracle help | grep -q 'Super+/ or type oracle manual' || { echo "oracle help doesn't point at the manual"; fail=1; }
((fail)) || echo "manual ok: $(wc -l <<<"$man") commands, all in bin/oracle"
exit $fail
