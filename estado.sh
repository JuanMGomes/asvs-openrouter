#!/usr/bin/env bash
# =============================================================================
#  AS Video Studio — ESTADO del servicio
#  Muestra si esta arriba, en que puerto, PID, uptime, y ultimo coste medido.
#  Uso:  bash estado.sh
# =============================================================================
set -uo pipefail
PREFIJO="${PREFIJO:-$HOME/asvs}"
REPO="$PREFIJO/repo"
PORT="${ASVS_PORT:-8020}"

if [ ! -d "$REPO" ]; then echo "No hay instalacion en $PREFIJO."; exit 1; fi

echo "=== AS Video Studio ($PREFIJO) ==="

# PID del servicio
PID=$(pgrep -f "$REPO/app.py" | head -1 || true)
if [ -n "$PID" ]; then
  echo "Estado:   ARRIBA (PID $PID)"
  echo "URL:      http://127.0.0.1:$PORT"
  # uptime del proceso
  if [ -r /proc/$PID/stat ]; then
    start=$(awk '{print $22}' /proc/$PID/stat)
    now=$(awk '{print $1*1000+$2}' /proc/uptime 2>/dev/null | cut -d. -f1)
    up=$(( (now*1000 - start)/1000/60 ))
    echo "Uptime:   ${up} min"
  fi
  if curl -fsS --max-time 4 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
    echo "HTTP:     responde OK"
  else
    echo "HTTP:     proceso vivo pero sin respuesta (revisa log)"
  fi
else
  echo "Estado:   PARADO"
  echo "Arranca:  ~/asvs/arrancar.sh"
fi

# Ultimo coste medido (si existe snapshot)
SNAP="$PREFIJO/data/coste_snapshot.json"
if [ -f "$SNAP" ]; then
  ini=$(grep -o '"inicio_usage"[^,]*' "$SNAP" | grep -o '[0-9.]*' | head -1)
  ts=$(grep -o '"inicio_ts"[^,]*' "$SNAP" | grep -o '[0-9]*' | head -1)
  if [ -n "$ini" ]; then
    echo "Coste:    sesion iniciada hace $(( ($(date +%s) - ${ts:-0})/60 )) min; usage inicial=$ini"
    echo "          corre 'medir_coste.sh fin' para ver el coste real del video."
  fi
fi

echo "Log:      $PREFIJO/data/estudio.log"
