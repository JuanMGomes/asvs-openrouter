#!/usr/bin/env bash
# =============================================================================
#  AS Video Studio (fork OpenRouter) — ACTUALIZADOR
# -----------------------------------------------------------------------------
#  Hace git pull del repo, reinstala dependencias y reescribe arrancar.sh /
#  desinstalar.sh. NO toca tu .env ni tus datos en ~/asvs/data.
#
#  Uso:  bash actualizar.sh
# =============================================================================
set -euo pipefail

PREFIJO="${PREFIJO:-$HOME/asvs}"
REPO="$PREFIJO/repo"

if [ ! -d "$REPO/.git" ]; then
  echo "No encuentro la instalacion en $PREFIJO. Ejecuta primero instalar_local.sh."
  exit 1
fi

echo "=============================================="
echo " Actualizando AS Video Studio en $PREFIJO"
echo "=============================================="

# 1) Pull (respeta cambios locales en motores si los hubiera; stash por si acaso)
echo "[1/4] Descargando cambios..."
cd "$REPO"
git stash -u >/dev/null 2>&1 || true
git checkout -q main 2>/dev/null || true
git pull --ff-only 2>&1 | tail -3 || { echo "git pull fallo (sin red o conflicto). Abortando."; exit 1; }
git stash pop >/dev/null 2>&1 || true

# 2) Reinstalar deps del venv (idempotente)
echo "[2/4] Reinstalando dependencias Python..."
# shellcheck disable=SC1091
source "$PREFIJO/venv/bin/activate"
python -m pip install --upgrade pip -q
python -m pip install -r "$REPO/requirements.txt" -q
python -m pip install edge-tts -q

# 3) Reenlazar shim y regenerar scripts (sin tocar .env ni data)
echo "[3/4] Reenlazando shim y scripts..."
mkdir -p "$PREFIJO/bin" "$PREFIJO/data"
ln -sf "$REPO/bin/claude" "$PREFIJO/bin/claude"
chmod +x "$REPO/bin/claude"

PORT="${ASVS_PORT:-8020}"
DATOS="$PREFIJO/data"
cat > "$PREFIJO/arrancar.sh" <<EOF
#!/usr/bin/env bash
set -a
[ -f "$PREFIJO/env/.env" ] && . "$PREFIJO/env/.env"
set +a
export PATH="$PREFIJO/bin:\$PATH"
export ESTUDIO_PROYECTOS="$DATOS/proyectos"
export ESTUDIO_PRESETS="$DATOS/presets"
export ESTUDIO_BANCO="$DATOS/banco"
export ESTUDIO_BANCO_PRESETS="$DATOS/banco_presets"
export ESTUDIO_SECRETOS="$DATOS/secretos"
export ESTUDIO_AJUSTES="$DATOS/ajustes"
export ESTUDIO_RECETAS="$DATOS/recetas"
export ESTUDIO_TARIFAS="$DATOS/tarifas"
export ESTUDIO_ESTADISTICAS="$DATOS/estadisticas"
export ESTUDIO_COSTE_GLOBAL="$DATOS/coste_global"
export ESTUDIO_BITACORA_GLOBAL="$DATOS/bitacora"
export ESTUDIO_MOTORES="$REPO/motores"
export ESTUDIO_FUENTES="\${ESTUDIO_FUENTES:-/usr/local/share/fonts/estudio}"
exec "$PREFIJO/venv/bin/python" "$REPO/app.py" --puerto "${ASVS_PORT:-$PORT}"
EOF
chmod +x "$PREFIJO/arrancar.sh"

cat > "$PREFIJO/desinstalar.sh" <<EOF
#!/usr/bin/env bash
read -r -p "Borra $PREFIJO (videos, estilos, claves ahi). ¿Continuar? [s/N] " r
[ "\$r" = "s" ] || [ "\$r" = "S" ] || { echo "Cancelado."; exit 1; }
rm -rf "$PREFIJO"
echo "Desinstalado. (Los paquetes del sistema no se tocan.)"
EOF
chmod +x "$PREFIJO/desinstalar.sh"

# 4) Reiniciar el servicio (mata el anterior y arranca de nuevo)
echo "[4/4] Reiniciando el servicio..."
pkill -f "$REPO/app.py" 2>/dev/null || true
sleep 1
nohup "$PREFIJO/arrancar.sh" > "$PREFIJO/data/estudio.log" 2>&1 &
echo "  PID: $!"
sleep 4
if curl -fsS --max-time 5 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
  echo "  Servicio ARRIBA en http://127.0.0.1:$PORT"
else
  echo "  Aun arrancando o fallo. Revisa: tail -f $PREFIJO/data/estudio.log"
fi
echo "=============================================="
echo " Actualizado. Tu .env y tus datos NO se tocaron."
echo "=============================================="
