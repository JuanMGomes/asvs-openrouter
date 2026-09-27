# AS Video Studio — fork OpenRouter (alternativas gratis / baratas / de pago, combinables)

Este directorio es un clon del repo `NeverBlink/as-video-studio` con tres cambios
para correrlo **en local o en Docker** usando OpenRouter en vez del CLI de Claude
Code (que exige suscripcion Pro/Max + login OAuth, inviable en headless).

**Lo clave: todo es env-driven.** No tienes que tocar codigo para elegir entre
gratis / barato / de pago. Combinas como quieras.

## Matriz de combinaciones (la parte que te interesa)

| Pieza | Variable | Opcion gratis | Opcion barata | Opcion de pago (original) |
|---|---|---|---|---|
| **Texto** (guion, rotulos) | `ASVS_LLM_MODEL` | `openrouter/free` (rota gratis, rate-limit) | `google/gemini-3.7-flash` (~$0.2/M out) | CLI de Claude (suscripcion) |
| **Imagen** | `ASVS_IMAGEN_MOTOR` + `ASVS_IMAGEN_MODEL` | (ninguna 100% gratis fiable) | `openrouter` + `bytedance-seed/seedream-4.5` (~$0.05/img) | `openai` + `gpt-image-2` (~$0.035 low) |
| **Voz** | `ASVS_VOZ_MOTOR` | `edgetts` (Edge TTS, sin clave) | — | `cartesia` (plan gratis) |

**Combinaciones favorables típicas:**
- **Maximo ahorro:** texto `openrouter/free` + imagen `seedream-4.5` + voz `edgetts`
  → solo pagas imagenes (~$0.05–0.10 por video de 4 min). Sujeto a rate-limit del
  tier gratis en el texto.
- **Calidad decente y barata:** texto `gemini-3.7-flash` + imagen `seedream-4.5`
  + voz `edgetts` → ~$0.1/video total.
- **Fidelidad maxima (original):** texto `opus` via CLI + imagen `openai/gpt-image-2`
  + voz `cartesia`. Esto requiere suscripcion de Claude y las claves de OpenAI/Cartesia.

Para volver a OpenAI/Cartesia puras: `ASVS_IMAGEN_MOTOR=openai` y
`ASVS_VOZ_MOTOR=cartesia` (y pon las claves en Configuracion). El codigo original
queda intacto en `motores/imagen_openai/_openai.py`.

## Via A — Instalador local autocontenido (recomendado en tu maquina potente)

Todo vive bajo UN prefijo (defecto `~/asvs`) y **no toca el resto del sistema**.
El desinstalador borra solo eso.

```bash
cd asvs-openrouter
bash instalar_local.sh                 # instala en ~/asvs
# opcional: PREFIJO=/opt/asvs bash instalar_local.sh
```

Esto crea venv, instala deps (+ `edge-tts`), deja el shim `claude` y un `.env`.
Rellena tu key en `~/asvs/env/.env` (`OPENROUTER_API_KEY`) y arranca:

```bash
~/asvs/arrancar.sh
# abre http://127.0.0.1:8020
```

**Desinstalar (borra SOLO el prefijo, incluidos tus videos/claves ahi):**
```bash
~/asvs/desinstalar.sh
```
No desinstala paquetes del sistema (ffmpeg, edge) salvo que tu los quites a mano;
el script no toca nada fuera de `~/asvs`.

## Via B — Docker

```bash
cd asvs-openrouter/repo
cp .env.example .env        # rellena OPENROUTER_API_KEY
docker compose up -d --build
# abre http://localhost:8020
```
`docker-compose.yml` monta `./data` y pone `bin/` primero en el PATH. Para
desinstalar: `docker compose down -v` (borra el volumen `./data` y el contenedor;
no toca tu host). Sube `cpus`/`memory` del compose si tu maquina tiene mas de
4 nucleos / 8 GB.

## Como funciona el shim `claude`

`pasos/cli_claude.py` invoca `claude -p --model <m> --effort <e> --output-format
json` y espera `{"result": "<texto>"}`. `bin/claude` se pone primero en el PATH y
reproduce ESE contrato, pero llama a OpenRouter con tu `OPENROUTER_API_KEY`. El
repo no se toca en esa parte. Mapeo de alias del repo a modelos (editable en
`bin/claude`): `haiku`→deepseek-v4.1-flash, `sonnet`→qwen-3.7-flash,
`opus`→gemini-3.7-flash.

## Parches mínimos al repo (por si aplicas a tu propio clon)

1. `bin/claude` — shim CLI → OpenRouter (NUEVO, fuera de `repo/`).
2. `motores/voz_edgetts/voz.py` — voz Edge TTS (NUEVO, copiado a `repo/motores/`).
3. `motores/imagen_openrouter/imagen.py` — imagen OpenRouter (NUEVO).
4. `motores/imagen_openai/imagen.py` — router que elige OpenRouter/OpenAI segun
   `ASVS_IMAGEN_MOTOR` (el original queda en `_openai.py`).
5. `pasos/p4_voz.py` — `cargar_motor(os.environ.get("ASVS_VOZ_MOTOR","edgetts"), "voz.py")`.
6. `pasos/p6_assets.py` — sin cambios (sigue llamando `imagen_openai/imagen.py`,
   que ahora es el router).

El resto del repo es intacto. Para volver al original: revierte 4–6 y borra los
motores nuevos.

## Avisos honestos

- **Word boundaries de Edge TTS** son peores que los de Cartesia; subtitulos/planos
  pueden desfasarse un poco. Si te importa la sincronia, usa `cartesia`.
- **Imagen con referencias de estilo:** la mayoria de modelos de OpenRouter NO
  aceptan `image[]` (edicion). Este fork las IGNORA y genera desde el prompt; el
  estilo viaja en texto. Para edicion fiel con referencias usa `openai/gpt-image-2`
  (`ASVS_IMAGEN_MOTOR=openai`), que sí acepta adjuntos.
- **El tier `openrouter/free`** tiene rate-limit (~20/min, 200/dia): suficiente
  para uso personal, justo para produccion continua. Para volumen, paga lo barato.
- **La API del Estudio no autentica.** No la expongas a internet sin el proxy login
  del repo (`despliegue/login`). En local basta `127.0.0.1`.
- **Sin licencia** en el upstream: respeta esa ausencia si redistribuyes.
