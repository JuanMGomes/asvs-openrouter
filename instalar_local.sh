#!/usr/bin/env bash
# =============================================================================
#  AS Video Studio (fork OpenRouter) — INSTALADOR TODO-EN-UNO, SIN PASOS
# -----------------------------------------------------------------------------
#  Una sola linea. Detecta el SO, instala lo que falte (python, ffmpeg, navegador,
#  fuentes), crea el venv, instala dependencias, prepara el .env y ARRANCA.
#
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/JuanMGomes/asvs-openrouter/main/instalar_local.sh)"
#
#  Al final pide la OPENROUTER_API_KEY (no la guardamos nosotros; va al .env).
#  Todo vive en $PREFIJO (defecto ~/asvs) y se desinstala con desinstalar.sh.
# =============================================================================
set -euo pipefail

PREFIJO="${PREFIJO:-$HOME/asvs}"
PORT="${ASVS_PORT:-8020}"
REPO_URL="https://github.com/JuanMGomes/asvs-openrouter"

# Detecta sudo si no somos root (para apt/brew)
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo "=============================================="
echo " AS Video Studio (OpenRouter) — instalador"
echo " Destino: $PREFIJO"
echo "=============================================="

# ---------------------------------------------------------------- 1. SO
echo "[1/7] Detectando sistema..."
if [ -f /etc/os-release ]; then . /etc/os-release; OS="$ID"; else OS="$(uname -s)"; fi
echo "  SO: $OS"

# ---------------------------------------------------------------- 2. deps sistema
echo "[2/7] Dependencias del sistema (solo lo que falte)..."
case "$OS" in
  ubuntu|debian|linuxmint|pop|kali)
    $SUDO apt-get update -qq
    # python3.12 + venv
    if ! command -v python3.12 >/dev/null 2>&1; then
      $SUDO apt-get install -y -qq software-properties-common >/dev/null 2>&1 || true
      $SUDO add-apt-repository -y ppa:deadsnakes/ppa >/dev/null 2>&1 || true
      $SUDO apt-get update -qq
    fi
    for pkg in ffmpeg git python3.12 python3.12-venv python3-pip fonts-mscorefonts-installer curl; do
      if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "  instalando $pkg..."; $SUDO apt-get install -y -qq "$pkg" >/dev/null 2>&1 || true
      fi
    done
    # navegador: edge o chromium
    if ! command -v microsoft-edge >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
      echo "  instalando microsoft-edge (navegador para render)..."
      curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | $SUDO gpg --dearmor -o /usr/share/keyrings/microsoft.gpg 2>/dev/null || true
      echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" | $SUDO tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
      $SUDO apt-get update -qq && $SUDO apt-get install -y -qq microsoft-edge-stable >/dev/null 2>&1 || echo "  (edge fallo; instala chromium manual si el render falla)"
    fi
    PY=python3.12
    ;;
  darwin)
    if ! command -v brew >/dev/null 2>&1; then
      echo "  instalando Homebrew..."; /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1 || true
    fi
    for pkg in ffmpeg git python@3.12 microsoft-edge; do
      brew list "$pkg" >/dev/null 2>&1 || { echo "  instalando $pkg..."; brew install "$pkg" >/dev/null 2>&1 || true; }
    done
    PY="$(brew --prefix python@3.12)/bin/python3.12"
    ;;
  fedora|centos|rhel|rocky|almalinux)
    $SUDO dnf install -y -q ffmpeg git python3.12 python3.12-pip python3.12-virtualenv msttcore-fonts-installer curl 2>/dev/null || \
    $SUDO yum install -y -q epel-release ffmpeg git python312 2>/dev/null || true
    if ! command -v microsoft-edge >/dev/null 2>&1; then
      $SUDO dnf install -y -q microsoft-edge-stable 2>/dev/null || echo "  (edge fallo; instala chromium manual)"
    fi
    PY=python3.12
    ;;
  *)
    echo "  SO no reconocido ($OS). Instala a mano: ffmpeg, python3.12, edge/chromium, fuentes MS."
    PY="$(command -v python3.12 || command -v python3)"
    ;;
esac

if ! command -v "$PY" >/dev/null 2>&1; then
  echo "ERROR: no se encontro python3.12 ($PY). Instalalo y reejecuta."; exit 1
fi
echo "  python: $($PY --version 2>&1)"

# ---------------------------------------------------------------- 3. clonar
echo "[3/7] Clonando repo..."
if [ -d "$PREFIJO/repo/.git" ] || [ -d "$PREFIJO/venv" ]; then
  echo "  ya existe $PREFIJO; reusando."
else
  rm -rf "$PREFIJO"
  mkdir -p "$PREFIJO"
  git clone --depth 1 "$REPO_URL" "$PREFIJO/repo" 2>&1 | tail -1
fi
REPO="$PREFIJO/repo"

# ---------------------------------------------------------------- 4. venv + deps
echo "[4/7] Entorno virtual y dependencias Python..."
if [ ! -f "$PREFIJO/venv/bin/activate" ]; then
  if ! "$PY" -m venv "$PREFIJO/venv" 2>/dev/null; then
    echo "  venv fallo (faltaba python3.12-venv). Instalandolo..."
    $SUDO apt-get install -y -qq python3.12-venv >/dev/null 2>&1 || true
    "$PY" -m venv "$PREFIJO/venv"
  fi
fi
# shellcheck disable=SC1091
source "$PREFIJO/venv/bin/activate"
python -m pip install --upgrade pip -q
python -m pip install -r "$REPO/requirements.txt" -q
python -m pip install edge-tts -q
echo "  Python: $(python --version 2>&1)"

# ---------------------------------------------------------------- 5. shim + env
echo "[5/7] Preparando shim y .env..."
mkdir -p "$PREFIJO/bin" "$PREFIJO/data"
ln -sf "$REPO/bin/claude" "$PREFIJO/bin/claude"
chmod +x "$REPO/bin/claude"
if [ ! -f "$PREFIJO/env/.env" ]; then
  cp "$REPO/.env.example" "$PREFIJO/env/.env"
fi

# ---------------------------------------------------------------- 6. arrancar.sh
echo "[6/7] Script de arranque + desinstalador..."
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

# ---------------------------------------------------------------- 7. key + arranque
echo "[7/7] Clave de OpenRouter y arranque"
if ! grep -q "OPENROUTER_API_KEY=.\{10,\}" "$PREFIJO/env/.env" 2>/dev/null; then
  echo "  Necesito tu OPENROUTER_API_KEY (la pones en el .env, no la vemos nosotros)."
  echo "  La consigues en https://openrouter.ai/keys"
  read -r -p "  Pega tu OPENROUTER_API_KEY: " ORKEY
  if [ -n "${ORKEY:-}" ]; then
    # inserta/sustituye la linea en el .env sin tocar el resto
    grep -v '^OPENROUTER_API_KEY=' "$PREFIJO/env/.env" > "$PREFIJO/env/.env.tmp" || true
    echo "OPENROUTER_API_KEY=$ORKEY" >> "$PREFIJO/env/.env.tmp"
    mv "$PREFIJO/env/.env.tmp" "$PREFIJO/env/.env"
    echo "  Clave guardada en $PREFIJO/env/.env"
  else
    echo "  No pusiste clave. Arranca luego con:  ~/asvs/arrancar.sh  (y edita el .env)"
  fi
else
  echo "  OPENROUTER_API_KEY ya presente en el .env."
fi

echo
echo "=============================================="
echo " LISTO. Arrancando el estudio en segundo plano..."
echo " Luego abre:  http://127.0.0.1:$PORT"
echo " Para parar:  Ctrl+C  (o mata el proceso)"
echo " Desinstalar: $PREFIJO/desinstalar.sh"
echo "=============================================="

# arranque en segundo plano con log
nohup "$PREFIJO/arrancar.sh" > "$PREFIJO/data/estudio.log" 2>&1 &
echo "  PID: $!"
echo "  Log: $PREFIJO/data/estudio.log"
sleep 4
if curl -fsS --max-time 5 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
  echo "  Servicio ARRIBA en http://127.0.0.1:$PORT"
else
  echo "  Aun arrancando o fallo. Revisa: tail -f $PREFIJO/data/estudio.log"
fi
