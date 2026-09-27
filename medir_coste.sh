#!/usr/bin/env bash
# =============================================================================
#  AS Video Studio — MEDIDOR DE COSTE REAL (OpenRouter)
# -----------------------------------------------------------------------------
#  Usa una API key de OpenRouter EXCLUSIVA del Estudio (crea una en
#  https://openrouter.ai/keys y ponla en ~/asvs/env/.env como OPENROUTER_API_KEY).
#  Asi la delta de 'total_usage' entre inicio y fin es el costo real del video.
#
#    bash medir_coste.sh inicio   -> guarda el saldo actual (snapshot)
#    bash medir_coste.sh fin      -> consulta de nuevo y muestra la delta en USD
#    bash medir_coste.sh estado   -> muestra el snapshot sin cerrar
#
#  OpenRouter /api/v1/credits devuelve data.total_usage (gastado en cuenta).
#  La diferencia fin - inicio = costo real del lote de trabajo del Estudio.
# =============================================================================
set -uo pipefail
PREFIJO="${PREFIJO:-$HOME/asvs}"
ENVF="$PREFIJO/env/.env"
SNAP="$PREFIJO/data/coste_snapshot.json"
mkdir -p "$PREFIJO/data"

# lee OPENROUTER_API_KEY del .env sin sourcear todo
KEY="$(grep -E '^OPENROUTER_API_KEY=' "$ENVF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' "')"
if [ -z "$KEY" ]; then echo "No encuentro OPENROUTER_API_KEY en $ENVF"; exit 2; fi

usage_actual() {
  curl -fsS --max-time 20 -H "Authorization: Bearer $KEY" \
    https://openrouter.ai/api/v1/credits 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['total_usage'])" 2>/dev/null
}

case "${1:-estado}" in
  inicio)
    u=$(usage_actual)
    [ -z "$u" ] && { echo "No se pudo leer el saldo (revisa la key / red)."; exit 1; }
    ts=$(date +%s)
    cat > "$SNAP" <<EOF
{"inicio_usage": $u, "inicio_ts": $ts}
EOF
    echo "Snapshot guardado: usage inicial = $u  ($(date))"
    echo "Ahora genera tu video. Al terminar corre:  bash medir_coste.sh fin"
    ;;
  fin)
    if [ ! -f "$SNAP" ]; then echo "No hay snapshot. Corre 'medir_coste.sh inicio' antes."; exit 1; fi
    ini=$(python3 -c "import json;print(json.load(open('$SNAP'))['inicio_usage'])")
    u=$(usage_actual)
    [ -z "$u" ] && { echo "No se pudo leer el saldo final."; exit 1; }
    delta=$(python3 -c "print(round($u - $ini, 6))")
    ts_ini=$(python3 -c "import json;print(json.load(open('$SNAP'))['inicio_ts'])")
    mins=$(( ($(date +%s) - ts_ini)/60 ))
    echo "=============================================="
    echo " COSTE REAL DEL VIDEO (OpenRouter)"
    echo "   usage inicio : $ini"
    echo "   usage fin    : $u"
    echo "   DELTA (USD)  : $delta"
    echo "   sesion       : ${mins} min"
    echo "=============================================="
    rm -f "$SNAP"
    ;;
  estado|*)
    if [ -f "$SNAP" ]; then
      ini=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d['inicio_usage'], d['inicio_ts'])")
      echo "Snapshot activo: inicio_usage=${ini% *}  ($(date -d @${ini#* } 2>/dev/null || echo 'en curso'))"
      echo "Corre 'medir_coste.sh fin' para cerrar y ver el coste."
    else
      echo "Sin snapshot. Corre 'medir_coste.sh inicio' antes de generar el video."
    fi
    ;;
esac
