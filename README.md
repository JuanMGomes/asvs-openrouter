# AS Video Studio — fork OpenRouter

Convierte texto/notas en **vídeo narrado y animado** (el grafo original de 8 fases:
ingesta → brief → guion → voz → revision_audio → assets → callouts → render), pero
**sin necesitar la suscripción de Claude**. El CLI de Claude Code se sustituye por
un shim que llama a **OpenRouter**, y la voz/imagen pueden usar alternativas
**gratis o baratas**, elegibles por variable de entorno (sin tocar código).

> Fork de [`NeverBlink/as-video-studio`](https://github.com/NeverBlink/as-video-studio).
> El código del Estudio queda intacto salvo los puntos listados abajo.

## Por qué existe este fork

El repo original exige el **CLI de Claude Code con sesión Pro/Max** (login OAuth
interactivo, inviable en headless) y cobra ~$4.4 en imágenes por vídeo de 4 min.
Este fork:

- Sustituye el CLI por **OpenRouter** (API key, no suscripción).
- Deja la **voz 100% gratis** (Edge TTS) por defecto.
- Deja la **imagen vía OpenRouter** (Seedream/Gemini, ~$0.05/imagen) por defecto.
- Todo es **env-driven**: combinas gratis / barato / pago como quieras.

## Matriz de combinaciones

| Pieza | Variable | Gratis | Barato | Original (pago) |
|---|---|---|---|---|
| Texto | `ASVS_LLM_MODEL` | `openrouter/free` | `google/gemini-3.7-flash` | CLI de Claude (suscripción) |
| Imagen | `ASVS_IMAGEN_MOTOR` + `ASVS_IMAGEN_MODEL` | — | `openrouter` + `bytedance-seed/seedream-4.5` | `openai` + `gpt-image-2` |
| Voz | `ASVS_VOZ_MOTOR` | `edgetts` (Edge TTS) | — | `cartesia` (plan gratis) |

Coste estimado de un vídeo de 4 min: **~$0.1** (solo imágenes) con la combinación
barata; el texto y la voz salen prácticamente gratis.

## Instalación

### A) Local autocontenido (recomendado en tu máquina potente)

```bash
git clone https://github.com/JuanMGomes/asvs-openrouter.git
cd asvs-openrouter
bash instalar_local.sh                 # instala en ~/asvs (todo aislado)
# rellena tu key en ~/asvs/env/.env :  OPENROUTER_API_KEY=tu-key
~/asvs/arrancar.sh
# abre http://127.0.0.1:8020
```

**Desinstalar** (borra solo `~/asvs`, incl. tus vídeos/claves ahí): `~/asvs/desinstalar.sh`.
No toca el resto del sistema.

### B) Docker

```bash
cd asvs-openrouter/repo
cp .env.example .env                   # rellena OPENROUTER_API_KEY
docker compose up -d --build
# abre http://localhost:8020
```

Desinstalar: `docker compose down -v` (borra contenedor + volumen `./data`).

## Cómo funciona

- `bin/claude` — shim que imita `claude -p --model --effort --output-format json`
  y llama a OpenRouter. `pasos/cli_claude.py` no se toca.
- `motores/voz_edgetts/voz.py` — voz Edge TTS gratis (misma interfaz que Cartesia).
- `motores/imagen_openrouter/imagen.py` — imagen vía OpenRouter.
- `motores/imagen_openai/imagen.py` — router que elige `openrouter`/`openai`
  según `ASVS_IMAGEN_MOTOR` (el original queda en `_openai.py`).
- `pasos/p4_voz.py` y `pasos/p6_assets.py` leen las env de selección de motor.

## Prueba real (sin arrancar el Estudio)

```bash
export OPENROUTER_API_KEY=tu-key
python3 probar_real.py        # 1 guion + 3 imágenes reales contra OpenRouter
```

## Avisos

- **Edge TTS** tiene word-boundaries peores que Cartesia: subtítulos/planos pueden
  desfasarse un poco. Para sincronía fiel usa `ASVS_VOZ_MOTOR=cartesia`.
- La mayoría de modelos de OpenRouter **no aceptan referencias de estilo** (edición);
  este fork las ignora y genera desde el prompt. Para edición con referencias usa
  `ASVS_IMAGEN_MOTOR=openai` (gpt-image-2 sí las acepta).
- El tier `openrouter/free` tiene rate-limit (~20/min, 200/día).
- La API del Estudio **no autentica**: en local basta `127.0.0.1`; no la expongas
  a internet sin el proxy login del repo original (`despliegue/login`).
- El upstream no tiene licencia; respeta esa ausencia si redistribuyes.

## Estructura

```
bin/claude                 shim CLI -> OpenRouter
instalar_local.sh          instalador local aislado
probar_real.py             prueba de verdad (3 imágenes + guion)
repo/                      clon del Estudio, parcheado
  motores/voz_edgetts/     voz gratis (Edge TTS)
  motores/imagen_openrouter/  imagen OpenRouter
  motores/imagen_openai/   router openrouter/openai
  pasos/p4_voz.py, p6_assets.py   selección por env
  Dockerfile, docker-compose.yml, .env.example, LEEME_LOCAL.md
```
