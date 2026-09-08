#!/bin/bash
# Build JustVPN single-file installer (setup.sh)
set -e
cd "$(dirname "$0")"
OUT="/root/JustVPN/setup.sh"
: > "$OUT"
chmod +x "$OUT"
for f in \
    lib-header.sh \
    lib-deps.sh \
    lib-domain.sh \
    lib-xray.sh \
    lib-web.sh \
    lib-haproxy.sh \
    lib-services.sh \
    lib-slowdns.sh \
    lib-accs-a.sh \
    lib-accs-b1.sh \
    lib-accs-b2.sh \
    lib-accs-b3.sh \
    lib-accs-b4.sh \
    lib-accs-b5.sh \
    lib-accs-b6.sh \
    lib-accs-b7.sh \
    lib-order.sh; do
    printf '\n# ===== %s =====\n' "$f" >> "$OUT"
    cat "src/$f" >> "$OUT"
done
echo "Built $OUT ($(wc -l < "$OUT") lines)"
bash -n "$OUT" && echo "syntax OK"