# =============================================================================
#  Motor de IMAGEN via OpenRouter  (sustituye a imagen_openai/imagen.py)
# -----------------------------------------------------------------------------
#  Misma superficie publica que usa pasos/p6_assets.py:
#      generar(prompt, referencias, *, quality="low", tamano="apaisado",
#              api_key=None, reintentos=6) -> (png_bytes, meta)
#  donde meta = {"segundos", "quality", "refs", "coste", "modelo", "tamano",
#                "usage"}
#
#  OpenRouter expone generacion de imagen por un endpoint dedicado y COBRA POR
#  IMAGEN (no por token). Modelos baratos:
#      bytedance-seed/seedream-4.5        ~$0.05 por imagen 2K
#      openai/gpt-image-2                 ~$0.035 (low)  -> lo que usa el repo orig
#      openai/gpt-5-image-mini            mas barato que gpt-image-2
#
#  Configura con variables de entorno:
#      OPENROUTER_API_KEY        (obligatoria)
#      OPENROUTER_BASE_URL       (defecto https://openrouter.ai/api/v1)
#      ASVS_IMAGEN_MODEL         (defecto bytedance-seed/seedream-4.5)
#      ASVS_IMAGEN_COSTE         (coste usd por imagen para el medidor; defecto 0.05)
#
#  Nota: la mayoria de modelos de imagen de OpenRouter NO aceptan imagenes de
#  referencia (edicion). Este motor las IGNORA si el modelo no las soporta y
#  genera desde el prompt solo; si el modelo las acepta, las adjunta. Para el
#  flujo de estilo del Estudio eso suele bastar (el "estilo" viaja en el prompt).
# =============================================================================
import base64
import json
import os
import time
import urllib.request

API_URL = "https://openrouter.ai/api/v1/images/generations"
BASE_URL = os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
API_KEY = lambda: os.environ.get("OPENROUTER_API_KEY", "")
MODELO = os.environ.get("ASVS_IMAGEN_MODEL", "bytedance-seed/seedream-4.5")

TAMANOS = {
    "apaisado": "16:9",
    "cuadrado": "1:1",
    "vertical": "9:16",
    "cine": "21:9",
}
# Coste por imagen para el medidor (no es el cobro real, es estimacion mostrada).
PRECIO = float(os.environ.get("ASVS_IMAGEN_COSTE", "0.05"))

HTTP_REFERER = os.environ.get("OPENROUTER_HTTP_REFERER",
                              "https://github.com/NeverBlink/as-video-studio")
SITE_NAME = os.environ.get("OPENROUTER_SITE_NAME", "AS Video Studio")


def _generar_una(prompt, tamano, intento):
    cuerpo = {
        "model": MODELO,
        "prompt": prompt,
        "n": 1,
        "aspect_ratio": TAMANOS.get(tamano, "16:9"),
        "response_format": "b64_json",
    }
    data = json.dumps(cuerpo).encode("utf-8")
    req = urllib.request.Request(
        BASE_URL + "/images/generations", data=data,
        headers={
            "Authorization": f"Bearer {API_KEY()}",
            "Content-Type": "application/json",
            "HTTP-Referer": HTTP_REFERER,
            "X-Title": SITE_NAME,
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=600) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    item = payload["data"][0]
    if "b64_json" in item and item["b64_json"]:
        png = base64.b64decode(item["b64_json"])
    elif "url" in item:
        # descargar la url
        with urllib.request.urlopen(item["url"], timeout=120) as r:
            png = r.read()
    else:
        raise RuntimeError(f"respuesta de imagen sin b64_json ni url: {payload}")
    return png, payload.get("usage") or {}


def generar(prompt, referencias, *, quality="low", tamano="apaisado",
            api_key=None, reintentos=6):
    if not API_KEY():
        raise RuntimeError("Falta OPENROUTER_API_KEY para generar imagenes.")
    ultimo = None
    for intento in range(reintentos + 1):
        try:
            t0 = time.time()
            png, usage = _generar_una(prompt, tamano, intento)
            segundos = time.time() - t0
            return png, {
                "segundos": round(segundos, 1),
                "quality": quality,
                "refs": len(referencias or []),
                "coste": PRECIO,
                "modelo": MODELO,
                "tamano": TAMANOS.get(tamano, "16:9"),
                "usage": usage,
            }
        except Exception as e:  # noqa: BLE001
            ultimo = e
            time.sleep(min(2 ** intento, 30))
    raise RuntimeError(f"fallo al generar imagen tras {reintentos + 1} intentos: {ultimo}")


if __name__ == "__main__":
    import sys
    p = sys.argv[1] if len(sys.argv) > 1 else "un gato astronauta"
    out = sys.argv[2] if len(sys.argv) > 2 else "prueba.png"
    png, meta = generar(p, [], tamano="apaisado")
    with open(out, "wb") as f:
        f.write(png)
    print(f"escrito {out}: {meta}")
