#!/usr/bin/env bash
# Lance les scénarios de test sans interface et résume : toute ligne SCRIPT ERROR / Parse Error / ÉCHEC, un délai
# dépassé, ou l'absence de « RÉSULTAT : OK » (pour les tests qui l'affichent) compte comme un échec.
#   tools/tests/run_all.sh            -> tous les tests (sauf rendu et mesures)
#   tools/tests/run_all.sh quick      -> tests de campagne + un échantillon rapide
#   tools/tests/run_all.sh a.gd b.gd  -> seulement ceux-là
cd "$(dirname "$0")/../.." || exit 1
root=$(pwd)
out=${TEST_OUT:-/tmp/blocus-tests/$(basename "$root")}
mkdir -p "$out"
skip="capture_police.gd shot1.gd perf3.gd prof1.gd"
if [ "$1" = "quick" ]; then
	list=$(ls tools/tests/campaign*.gd tools/tests/story*.gd 2>/dev/null; echo tools/tests/police2.gd tools/tests/fuzz_joueur.gd)
elif [ $# -gt 0 ]; then
	list=""; for a in "$@"; do list="$list tools/tests/$(basename "$a")"; done
else
	list=$(ls tools/tests/*.gd)
fi
fail=0; n=0
for t in $list; do
	b=$(basename "$t")
	case " $skip " in *" $b "*) continue;; esac
	[ -f "$t" ] || continue
	n=$((n+1))
	log="$out/${b%.gd}.log"
	timeout ${TEST_TIMEOUT:-1500} "$root/tools/dev/gd" --headless --path . --fixed-fps 30 -s "$t" > "$log" 2>&1
	rc=$?
	bad=$(grep -E "SCRIPT ERROR|Parse Error|ÉCHEC|Invalid call|Invalid access|Nonexistent function|Cannot call method|Attempt to call|Out of bounds" "$log" | head -3)
	if [ $rc -eq 124 ]; then bad="DÉLAI DÉPASSÉ $bad"; fi
	if grep -q "RÉSULTAT" "$t" && ! grep -q "RÉSULTAT : OK" "$log"; then bad="pas de « RÉSULTAT : OK » $bad"; fi
	if [ -n "$bad" ]; then echo "✗ $b : $bad   (journal : $log)"; fail=$((fail+1)); else echo "✓ $b"; fi
done
echo "---- $((n-fail))/$n tests OK"
[ $fail -eq 0 ]
