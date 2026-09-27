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
- Deja la **imagen vía OpenRouter** (OpenAI gpt-image-2 por defecto, ~$0.035/imagen).
- Todo es **env-driven**: combinas gratis / barato / pago como quieras.

## Matriz de combinaciones

| Pieza | Variable | Gratis | Barato | Original (pago) |
|---|---|---|---|---|
| Texto | `ASVS_LLM_MODEL` | `openrouter/free` | `google/gemini-3.7-flash` | CLI de Claude (suscripción) |
| Imagen | `ASVS_IMAGEN_MOTOR` + `ASVS_IMAGEN_MODEL` | — | `openrouter` + `openai/gpt-image-2` (~$0.035) | `openai` + `gpt-image-2` |
| Voz | `ASVS_VOZ_MOTOR` | `voz_edgetts` (Edge TTS) | — | `voz_cartesia` (plan gratis) |

Coste estimado de un vídeo de 4 min (126 imágenes): **~$4.41** con `openai/gpt-image-2`,
**~$6.30** con `bytedance-seed/seedream-4.5`, **~$2.52** con `openai/gpt-5-image-mini`.
Texto y voz salen prácticamente gratis. El medidor dentro de la app anota el coste
real por proyecto (`/api/proyectos/{id}/coste`).

## Instalación en Windows 11 (WSL2) — recomendado

El instalador es bash y solo cubre Linux/macOS. En Win11 la vía limpia es **WSL2 + Ubuntu**,
donde se instala también Microsoft Edge (Linux, headless) que es el que usa el render de planos.

**1. PowerShell (admin):**
```
wsl --install
```
Reinicia cuando lo pida. Luego abre "Ubuntu" desde el menú Inicio y crea usuario/contraseña.

**2. En la terminal de Ubuntu (WSL), corre el instalador:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JuanMGomes/asvs-openrouter/main/instalar_local.sh)"
```
Te pedirá la `OPENROUTER_API_KEY` (la consigues en https://openrouter.ai/keys).

> El script instala solo lo que falte: python3.12, ffmpeg, Edge-Linux, fuentes MS,
> venv, dependencias y `edge-tts`. Crea todo en `~/asvs` y arranca el servicio.

**3. Abre el estudio** en el navegador de Windows (Edge o Chrome):
```
http://localhost:8020
```
Win11 reenvía `localhost` al WSL. Si no carga, usa la IP de WSL:
en Ubuntu `ip addr` → IP de `eth0` → `http://<ip>:8020`.

**Comandos de arranque/parada:**
```
~/asvs/arrancar.sh     # arrancar
pkill -f app.py        # parar
~/asvs/desinstalar.sh  # borrar todo (~/asvs, incl. vídeos y claves ahí)
```

**Reinstalar desde cero** (si algo se corrompió):
```
rm -rf ~/asvs
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JuanMGomes/asvs-openrouter/main/instalar_local.sh)"
```

## Instalación en Linux/macOS nativo

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/JuanMGomes/asvs-openrouter/main/instalar_local.sh)"
# abre http://localhost:8020
```

## Instalación con Docker

```bash
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
- `nucleo/coste.py` — medidor por proyecto append-only (coste real de imagen+texto).

## Prueba real (sin arrancar el Estudio)

```bash
export OPENROUTER_API_KEY=tu-key
python3 probar_real.py        # 1 guion + 3 imágenes reales contra OpenRouter
```

## Errores conocidos y solución

Estos ya están corregidos en el instalador/`main`, pero si instalaste antes de los
arreglos o editas el `.env` a mano, aquí están las causas:

| Síntoma | Causa | Solución |
|---|---|---|
| `Video: command not found` al arrancar | `OPENROUTER_SITE_NAME=AS Video Studio` sin comillas rompe el `source` del `.env` | Ponlo entre comillas: `OPENROUTER_SITE_NAME="AS Video Studio"` |
| `falta el motor ... no existe motores/edgetts/voz.py` | `ASVS_VOZ_MOTOR` debe ser `voz_edgetts` (nombre de carpeta) | En `.env`: `ASVS_VOZ_MOTOR=voz_edgetts` |
| `cp: cannot create ... /env/.env` | falta crear `~/asvs/env` | El instalador ya lo crea; si lo haces a mano: `mkdir -p ~/asvs/env` |
| `address already in use` (puerto 8020) | instancia previa colgada | `pkill -f app.py` y re-arranca |
| `ensurepip` / venv falla | faltaba `python3.12-venv` | El instalador ya lo reinstala; si a mano: `sudo apt-get install -y python3.12-venv` |

## Avisos

- **Edge TTS** tiene word-boundaries peores que Cartesia: subtítulos/planos pueden
  desfasarse un poco. Para sincronía fiel usa `ASVS_VOZ_MOTOR=voz_cartesia`.
- La mayoría de modelos de OpenRouter **no aceptan referencias de estilo** (edición);
  este fork las ignora y genera desde el prompt. Para edición con referencias usa
  `ASVS_IMAGEN_MOTOR=openai` (gpt-image-2 sí las acepta).
- El tier `openrouter/free` tiene rate-limit (~20/min, 200/día).
- La API del Estudio **no autentica**: en local basta `127.0.0.1`; no la expongas
  a internet sin el proxy login del repo original (`despliegue/login`).
- El upstream no tiene licencia; respeta esa ausencia si redistribuyes.
- **Seguridad**: nunca pongas tu API key en el chat ni la commitees. El `.env` está
  en `.gitignore`. Si tu key estuvo expuesta, rotala en https://openrouter.ai/keys.

## Estructura (plana)

```
bin/claude                 shim CLI -> OpenRouter
instalar_local.sh          instalador local aislado (crea ~/asvs)
actualizar.sh              actualiza el fork sin tocar tu .env/data
estado.sh, medir_coste.sh  estado del servicio / coste por snapshot de OpenRouter
probar_real.py             prueba de verdad (3 imágenes + guion)
.env.example               plantilla de variables (cópiala a ~/asvs/env/.env)
app.py, requirements.txt   Estudio (FastAPI, 8 fases)
nucleo/coste.py            medidor de coste por proyecto
motores/voz_edgetts/       voz gratis (Edge TTS)
motores/imagen_openrouter/ imagen OpenRouter
motores/imagen_openai/     router openrouter/openai
pasos/p4_voz.py, p6_assets.py   selección de motor por env
Dockerfile, docker-compose.yml, LEEME_LOCAL.md
```
