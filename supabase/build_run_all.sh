#!/usr/bin/env bash
#
# Genskaber supabase/RUN_ALL.sql ud fra supabase/migrations/.
#
# RUN_ALL.sql er migrationerne sat efter hinanden i navnerækkefølge, så hele
# udrulningen kan indsættes i Supabases SQL Editor på én gang. Filen blev
# tidligere vedligeholdt i hånden, og så drev den fra migrationerne uden at
# nogen opdagede det. Kør dette script i stedet, hver gang du tilføjer en
# migration:
#
#     ./supabase/build_run_all.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

HEADER="supabase/run_all_header.sql"
OUT="supabase/RUN_ALL.sql"

mapfile -t FILES < <(ls supabase/migrations/*.sql | sort)
TOTAL=${#FILES[@]}

if [ "$TOTAL" -eq 0 ]; then
  echo "Ingen migrationer fundet." >&2
  exit 1
fi

{
  cat "$HEADER"
  n=0
  for f in "${FILES[@]}"; do
    n=$((n + 1))
    printf '\n\n\n'
    echo "-- ############################################################################"
    echo "-- ## AFSNIT $n af $TOTAL: $(basename "$f")"
    echo "-- ############################################################################"
    printf '\n'
    cat "$f"
  done
} > "$OUT"

echo "$OUT genskabt: $TOTAL migrationer, $(wc -l < "$OUT") linjer"
