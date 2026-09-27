#!/usr/bin/env python3
# =============================================================================
#  PRUEBA REAL contra OpenRouter (requiere OPENROUTER_API_KEY en el entorno)
#  - 1 guion corto via el shim bin/claude (OpenRouter chat)
#  - 3 imagenes via motores/imagen_openrouter (OpenRouter images)
#  Reporta texto generado, tiempos y costes reales (lo que cobra OpenRouter).
#  No se toca el repo del Estudio: es solo para validar precios/tiempos.
# =============================================================================
import os
import subprocess
import sys
import time

RAIZ = os.path.dirname(os.path.abspath(__file__))
BIN_CLUDE = os.path.join(RAIZ, "bin", "claude")
REPO = os.path.join(RAIZ, "repo")
IMAGEN = os.path.join(REPO, "motores", "imagen_openrouter", "imagen.py")

API_KEY = os.environ.get("OPENROUTER_API_KEY")
if not API_KEY:
    print("Falta OPENROUTER_API_KEY en el entorno. No se puede probar de verdad.")
    sys.exit(2)

# 1) GUION CORTO via shim claude (imita el CLI de Claude Code)
print(">> Generando guion corto via shim claude (OpenRouter)...")
t0 = time.time()
r = subprocess.run(
    [sys.executable, BIN_CLUDE, "-p", "--model", "opus", "--effort", "low",
     "--output-format", "json"],
    input="Escribe un guion de 3 frases para un video sobre el cafe de especialidad.",
    capture_output=True, text=True, timeout=300,
    env={**os.environ, "ASVS_LLM_MODEL": os.environ.get("ASVS_LLM_MODEL", "google/gemini-3.7-flash")},
)
dt = time.time() - t0
if r.returncode != 0:
    print("FALLO guion:", r.stderr[:500]); sys.exit(1)
try:
    import json
    sobre = json.loads(r.stdout)
    texto = sobre.get("result", "")
    print(f"   guion ({dt:.1f}s): {texto[:200]!r}")
except Exception as e:
    print("No se pudo parsear el sobre:", e, r.stdout[:300]); sys.exit(1)

# 2) 3 IMAGENES via motor OpenRouter
print(">> Generando 3 imagenes via OpenRouter (modelo:", os.environ.get("ASVS_IMAGEN_MODEL", "bytedance-seed/seedream-4.5"), ")...")
import importlib.util
spec = importlib.util.spec_from_file_location("imagen_or", IMAGEN)
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

prompts = [
    "Plano fijo: taza de cafe de especialidad sobre mesa de madera, luz calida, estilo minimalista.",
    "Primer plano: granos de cafe cayendo, fondo desenfocado, alta calidad.",
    "Plano medio: barista preparando espresso, encuadre limpio, estilo documental.",
]
total_seg = 0.0
total_coste = 0.0
for i, p in enumerate(prompts, 1):
    t0 = time.time()
    png, meta = mod.generar(p, [], tamano="apaisado")
    dt = time.time() - t0
    total_seg += dt
    total_coste += meta.get("coste", 0.0) or 0.0
    print(f"   imagen {i}: {len(png)} bytes, {dt:.1f}s, coste estimado ${meta.get('coste')}, modelo {meta.get('modelo')}")

print("\n=== RESUMEN REAL ===")
print(f"Guion:        {dt:.1f}s (texto de {len(texto)} chars)")
print(f"3 imagenes:   {total_seg:.1f}s totales, ${total_coste:.2f} estimado (medidor)")
print("Nota: el coste del medidor es el estimado en ASVS_IMAGEN_COSTE; el cobro real")
print("lo veras en tu cuenta de OpenRouter. El texto cuesta lo que cobre el modelo elegido.")
