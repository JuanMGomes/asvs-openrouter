# =============================================================================
#  Motor de VOZ gratuito: Edge TTS  (sustituye a voz_cartesia/voz.py)
# -----------------------------------------------------------------------------
#  Misma superficie publica que usa pasos/p4_voz.py:
#      SR, VOCES, API_VERSION, API_SSE,
#      cargar_api_key() -> str (no necesaria, devuelve "")
#      tts_sse(api_key, voz_id, idioma, transcript) -> (wav, duracion, palabras)
#      tts_bytes(api_key, voz_id, idioma, transcript) -> (wav, duracion, palabras)
#      wav_desde_pcm(pcm) -> wav
#      espaciar / aplicar_desplazamiento / _repartir_palabras  (reutilizados del
#      motor original; son genericos y no dependen de Cartesia)
#
#  Edge TTS es 100% gratis y no pide clave. Las voces se mapean por idioma a
#  voces neuronales de Microsoft. Las marcas de palabra las da Edge TTS en ticks
#  de 100 ns; se convierten al formato {w, s, e} que espera el Estudio.
#
#  Dependencias:  pip install edge-tts
# =============================================================================
import asyncio
import base64
import re
import struct
import sys

SR = 24000  # Edge TTS entrega PCM mono 24 kHz por defecto

# Voces neuronales gratuitas de Microsoft por idioma.
# voz_id es el nombre largo que espera el Estudio (lo normalizamos abajo).
VOCES = {
    "es": {"id": "es-ES-AlvaroNeural", "nombre": "Alvaro (es-ES)"},
    "en": {"id": "en-US-AndrewNeural", "nombre": "Andrew (en-US)"},
    "fr": {"id": "fr-FR-HenriNeural", "nombre": "Henri (fr-FR)"},
    "de": {"id": "de-DE-ConradNeural", "nombre": "Conrad (de-DE)"},
    "it": {"id": "it-IT-DiegoNeural", "nombre": "Diego (it-IT)"},
    "pt": {"id": "pt-BR-AntonioNeural", "nombre": "Antonio (pt-BR)"},
}

# El repo pasa el "id" de Cartesia; lo dejamos pasar, pero para Edge TTS
# usamos el mapa por idioma. Si el id ya parece una voz de Edge (contiene "-"),
# y el idioma coincide, lo respetamos; si no, caemos al defecto del idioma.
API_VERSION = "edge-tts"
API_SSE = "edge-tts://tts"  # no se usa de red; solo para no romper imports


def cargar_api_key():
    """Edge TTS no necesita clave. Devolvemos cadena vacia."""
    return ""


def wav_desde_pcm(pcm: bytes) -> bytes:
    """Cabecera WAV PCM s16le mono sobre PCM crudo."""
    cabecera = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE"
    cabecera += b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16)
    cabecera += b"data" + struct.pack("<I", len(pcm))
    return cabecera + pcm


def _voz_para(voz_id, idioma):
    voz = VOCES.get(idioma, VOCES["es"])["id"]
    # Si el caller paso un voice id estilo Edge (p.ej. es-ES-AlvaroNeural)
    # y coincide con el idioma pedido, usalo.
    if isinstance(voz_id, str) and "-" in voz_id:
        prefijo = idioma.split("-")[0] if "-" in idioma else idioma
        if voz_id.lower().startswith(prefijo.lower() + "-"):
            voz = voz_id
    return voz


async def _sintetizar(voz, transcript):
    """Devuelve (pcm_bytes, [(palabra, inicio_s, fin_s), ...])."""
    import edge_tts  # import perezoso: el repo no lo carga si no se usa voz

    pcm = bytearray()
    palabras = []
    subproceso = edge_tts.Communicate(text=transcript, voice=voz)
    async for evento in subproceso.stream():
        if evento["type"] == "audio":
            pcm.extend(evento["data"])
        elif evento["type"] == "word":
            # offset/duration vienen en ticks de 100 ns (1e7 por segundo)
            ini = evento["offset"] / 10_000_000.0
            fin = (evento["offset"] + evento["duration"]) / 10_000_000.0
            palabras.append((evento["text"], round(ini, 3), round(fin, 3)))
    return bytes(pcm), palabras


def _ejecutar(voz, transcript):
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            # Dentro de un thread con loop vivo: nuevo loop en el thread.
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor(1) as ex:
                return ex.submit(asyncio.run, _sintetizar(voz, transcript)).result()
        return loop.run_until_complete(_sintetizar(voz, transcript))
    except RuntimeError:
        return asyncio.run(_sintetizar(voz, transcript))


def tts_sse(api_key, voz_id, idioma, transcript):
    voz = _voz_para(voz_id, idioma)
    pcm, palabras = _ejecutar(voz, transcript)
    if not pcm:
        raise RuntimeError("Edge TTS no devolvio audio")
    wav = wav_desde_pcm(pcm)
    duracion = len(pcm) / (SR * 2)
    salida = [{"w": p, "s": s, "e": e} for (p, s, e) in palabras]
    return wav, duracion, salida


def tts_bytes(api_key, voz_id, idioma, transcript):
    # Mismo camino: Edge TTS no distingue SSE/bytes.
    return tts_sse(api_key, voz_id, idioma, transcript)


# Alias por si el repo llama sintetizar_* (no se usa en el flujo web, pero
# existen en el motor original y prueba_piezas puede referenciarlos).
def listar_voces(idioma=None, refrescar=False, solo_nativas=False):
    if idioma:
        return [VOCES.get(idioma, VOCES["es"])]
    return [v for v in VOCES.values()]


# ---------------------------------------------------------------------------
#  Utilidades reutilizadas del motor original de Cartesia (genericamente
#  aplicables a cualquier WAV PCM mono s16le; no dependen del proveedor).
# ---------------------------------------------------------------------------
def _normalizar(palabra):
    return re.sub(r"[^\wáéíóúüñ]", "", palabra.lower())


def _repartir_palabras(escenas, palabras):
    """Asigna a cada escena el tramo de palabras que le corresponde."""
    reparto = {}
    i = 0
    for escena in escenas:
        esperadas = [_normalizar(p) for p in (escena.get("narracion") or "").split()]
        esperadas = [p for p in esperadas if p]
        tramo = []
        for esperada in esperadas:
            j = i
            while j < min(i + 3, len(palabras)):
                if _normalizar(palabras[j]["w"]) == esperada:
                    break
                j += 1
            if j < min(i + 3, len(palabras)):
                tramo.extend(palabras[i:j + 1])
                i = j + 1
            elif i < len(palabras):
                tramo.append(palabras[i])
                i += 1
        reparto[escena["id"]] = tramo
    if i < len(palabras) and reparto:
        ultimo = [e["id"] for e in escenas if (e.get("narracion") or "").strip()]
        if ultimo:
            reparto[ultimo[-1]].extend(palabras[i:])
    return reparto


def _pcm_de_wav(wav: bytes) -> bytes:
    return wav[44:]


FUNDIDO_MS = 12


def _relleno_de_sala(pcm, desde_seg, hasta_seg, duracion):
    bytes_por_seg = SR * 2
    necesarios = int(duracion * bytes_por_seg) & ~1
    if necesarios <= 0:
        return b""
    ancho = max(0.0, hasta_seg - desde_seg)
    if ancho < 0.04:
        return b"\x00" * necesarios
    toma = min(0.2, ancho * 0.8)
    centro = (desde_seg + hasta_seg) / 2.0
    ini = int((centro - toma / 2) * bytes_por_seg) & ~1
    fin = (ini + (int(toma * bytes_por_seg) & ~1))
    semilla = pcm[max(0, ini):min(len(pcm), fin)]
    if len(semilla) < 4:
        return b"\x00" * necesarios
    reverso = semilla[::-1]
    reverso = b"".join(reverso[i:i + 2][::-1] for i in range(0, len(reverso) - 1, 2))
    trozos, largo, vuelta = [], 0, 0
    while largo < necesarios:
        pieza = semilla if vuelta % 2 == 0 else reverso
        trozos.append(pieza)
        largo += len(pieza)
        vuelta += 1
    relleno = bytearray(b"".join(trozos)[:necesarios])
    muestras = FUNDIDO_MS * SR // 1000
    for i in range(min(muestras, len(relleno) // 2)):
        factor = i / muestras
        for pos in (i * 2, len(relleno) - 2 - i * 2):
            valor = int.from_bytes(relleno[pos:pos + 2], "little", signed=True)
            relleno[pos:pos + 2] = int(valor * factor).to_bytes(2, "little", signed=True)
    return bytes(relleno)


def espaciar(wav, palabras, reparto, escenas, hueco_minimo=1.0):
    """Ensancha los silencios ENTRE escenas sin re-sintetizar nada."""
    pcm = _pcm_de_wav(wav)
    bytes_por_seg = SR * 2
    cortes = []
    con_voz = [e for e in escenas if reparto.get(e["id"])]
    for anterior, siguiente in zip(con_voz, con_voz[1:]):
        fin = reparto[anterior["id"]][-1]["e"]
        inicio = reparto[siguiente["id"]][0]["s"]
        falta = hueco_minimo - (inicio - fin)
        if falta > 0.01:
            cortes.append((fin + (inicio - fin) / 2, falta, fin, inicio))
    if not cortes:
        return wav, []
    trozos = []
    anterior_byte = 0
    acumulado = 0.0
    desplazamientos = []
    for instante, silencio, desde, hasta in cortes:
        corte_byte = int(instante * bytes_por_seg) & ~1
        trozos.append(pcm[anterior_byte:corte_byte])
        trozos.append(_relleno_de_sala(pcm, desde, hasta, silencio))
        anterior_byte = corte_byte
        acumulado += silencio
        desplazamientos.append({"desde": instante, "retardo": round(acumulado, 3)})
    trozos.append(pcm[anterior_byte:])
    return wav_desde_pcm(b"".join(trozos)), desplazamientos


def aplicar_desplazamiento(instante, desplazamientos):
    retardo = 0.0
    for d in desplazamientos:
        if instante >= d["desde"]:
            retardo = d["retardo"]
    return round(instante + retardo, 3)


if __name__ == "__main__":
    # Uso manual:  python voz.py --texto "hola" --idioma es --out prueba.wav
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--texto", default="Esto es una prueba de voz gratuita.")
    ap.add_argument("--idioma", default="es")
    ap.add_argument("--out", default="prueba.wav")
    args = ap.parse_args()
    wav, dur, _ = tts_sse("", VOCES[args.idioma]["id"], args.idioma, args.texto)
    with open(args.out, "wb") as f:
        f.write(wav)
    print(f"escrito {args.out} ({dur:.2f} s)")
