#!/usr/bin/env bash
# =============================================================================
#  AS Video Studio (fork OpenRouter) — INSTALADOR LOCAL AUTOCONTENIDO
# -----------------------------------------------------------------------------
#  Deja todo bajo un unico prefijo (PREFIJO, defecto $HOME/asvs) y NO toca el
#  resto del sistema. Crea un venv, instala dependencias, prepara el shim claude
#  y deja un .env plantilla. Para quitarlo:  desinstalar.sh  (borra solo PREFIJO).
#
#  Uso:
#    bash instalar_local.sh            # instala en $HOME/asvs
#    PREFIJO=/opt/asvs bash instalar_local.sh
#
#  Requisitos del sistema (los instala el script si hay apt):
#    python3.12, ffmpeg, Microsoft Edge/Chrome, fuentes MS (Verdana/Georgia/Arial)
# =============================================================================
set -euo pipefail

PREFIJO="${PREFIJO:-$HOME/asvs}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/repo" && pwd)"
PORT="${ASVS_PORT:-8020}"

echo "Instalando AS Video Studio (OpenRouter) en: $PREFIJO"

# 1) carpeta raiz y datos
mkdir -p "$PREFIJO"/{venv,data,bin,env}
DATOS="$PREFIJO/data"

# 2) venv + dependencias
python3 -m venv "$PREFIJO/venv"
# shellcheck disable=SC1091
source "$PREFIJO/venv/bin/activate"
python -m pip install --upgrade pip -q
python -m pip install -r "$REPO/requirements.txt" -q
python -m pip install edge-tts -q

# 3) shim 'claude' primero en el PATH del arranque
ln -sf "$REPO/bin/claude" "$PREFIJO/bin/claude"
chmod +x "$REPO/bin/claude"

# 4) .env plantilla (no sobreescribe si ya existe)
if [ ! -f "$PREFIJO/env/.env" ]; then
  cp "$REPO/.env.example" "$PREFIJO/env/.env"
  echo "Creado $PREFIJO/env/.env — rellena OPENROUTER_API_KEY antes de arrancar."
fi

# 5) script de arranque que pone bin/ primero en PATH y carga el .env
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
export ESTUDIO_FUENTES="${ESTUDIO_FUENTES:-/usr/local/share/fonts/estudio}"
exec "$PREFIJO/venv/bin/python" "$REPO/app.py" --puerto "${ASVS_PORT:-$PORT}"
EOF
chmod +x "$PREFIJO/arrancar.sh"

# 6) desinstalador (borra SOLO PREFIJO)
cat > "$PREFIJO/desinstalar.sh" <<EOF
#!/usr/bin/env bash
# Borra toda la instalacion. SOLO toca $PREFIJO. No desinstala paquetes del sistema.
read -r -p "Esto borrara $PREFIJO (tus videos, estilos y claves ahi guardados). ¿Continuar? [s/N] " r
[ "\$r" = "s" ] || [ "\$r" = "S" ] || { echo "Cancelado."; exit 1; }
rm -rf "$PREFIJO"
echo "Desinstalado. Tambien puedes quitar los paquetes del sistema si quieres (no obligatorio)."
EOF
chmod +x "$PREFIJO/desinstalar.sh"

echo
echo "Listo. Para arrancar:"
echo "    $PREFIJO/arrancar.sh"
echo "Luego abre:  http://127.0.0.1:$PORT"
echo "Para quitar todo:  $PREFIJO/desinstalar.sh"
