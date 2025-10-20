#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  echo "[i] Modalità DRY-RUN: non cancello nulla, mostro solo i comandi."
fi

# Richiede bash >= 4 (associative arrays)
declare -A SEEN

TABLES=("filter" "nat" "mangle" "raw" "security")

BK="/root/iptables-livebk-$(date +%F-%H%M%S).save"
echo "[*] Backup: $BK"
iptables-save > "$BK"

for t in "${TABLES[@]}"; do
  echo "[*] Scansiono tabella *$t"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^-A\  ]] || continue

    key="*$t|$line"

    if [[ -z "${SEEN[$key]+x}" ]]; then
      SEEN["$key"]=1
    else
      chain=$(awk '{print $2}' <<< "$line")
      spec=$(sed -E 's/^-A [^ ]+ //;' <<< "$line")

      echo "[del] iptables -t $t -D $chain $spec"
      if [[ $DRY_RUN -eq 0 ]]; then
        # shellcheck disable=SC2086
        iptables -t "$t" -D "$chain" $spec || true
      fi
    fi
  done < <(iptables-save | awk -v T="*$t" '
    BEGIN{table=""}
    /^\*/{table=$1; next}
    table==T && /^-A /{print}
  ')
done

echo "[✓] Deduplicazione completata."