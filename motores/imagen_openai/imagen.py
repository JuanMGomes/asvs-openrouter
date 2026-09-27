# =============================================================================
#  Router de motor de IMAGEN  (imagen_openai/imagen.py)
# -----------------------------------------------------------------------------
#  Los pasos llaman siempre a "imagen_openai/imagen.py". Este fichero delega al
#  motor real segun ASVS_IMAGEN_MOTOR:
#      openrouter -> motores/imagen_openrouter/imagen.py  (OpenRouter; por imagen)
#      openai     -> motores/imagen_openai/_openai.py     (OpenAI gpt-image-2)
#
#  Ambos motores exponen la misma superficie publica:
#      generar(prompt, referencias, *, quality, tamano, api_key=None,
#              reintentos=6) -> (png_bytes, meta)
#      normalizar(ruta, cache) -> ruta normalizada
#  de modo que cambiar de proveedor es solo cambiar la variable de entorno, sin
#  tocar pasos/p6_assets.py.
# =============================================================================
import importlib.util
import os

_MOTOR = os.environ.get("ASVS_IMAGEN_MOTOR", "openrouter").strip().lower()

# Carga por ruta (igual que hace medios.motor) para no depender de sys.path.
_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _cargar(rel):
    ruta = os.path.join(_BASE, rel)
    spec = importlib.util.spec_from_file_location("motor_" + rel.replace("/", "_").replace(".", "_"), ruta)
    assert spec is not None, f"no se pudo cargar el motor {ruta}"
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


if _MOTOR == "openai":
    _mod = _cargar("imagen_openai/_openai.py")
else:
    # por defecto OpenRouter (barato; configurable con ASVS_IMAGEN_MODEL)
    _mod = _cargar("imagen_openrouter/imagen.py")

# Re-exporta todo lo publico del motor elegido.
generar = _mod.generar
normalizar = getattr(_mod, "normalizar", lambda ruta, cache=None: ruta)
for _k in ("TAMANOS", "MODELO", "PRECIO", "API_URL"):
    if hasattr(_mod, _k):
        globals()[_k] = getattr(_mod, _k)

MOTOR_ACTIVO = _MOTOR
