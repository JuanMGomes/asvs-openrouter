# =============================================================================
#  AS Video Studio (fork OpenRouter) — imagen de servicio
#  Build:  docker build -t asvs-openrouter .
#  Run:    docker run --env-file .env -p 8020:8020 asvs-openrouter
#  Recomendado: usar docker-compose.yml (monta /data y el bin/claude en el PATH).
# =============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Paquetes base: ffmpeg, fuentes MS (de paquetes Ubuntu, no del repo), Python, nginx no hace falta.
RUN apt-get update -qq && apt-get install -y -qq \
    ca-certificates curl gnupg fonts-liberation fonts-mscorefonts-installer \
    ffmpeg python3 python3-venv python3-pip \
    software-properties-common fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Microsoft Edge (estable) para rasterizar planos via Chrome DevTools Protocol.
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" \
       > /etc/apt/sources.list.d/microsoft-edge.list \
    && apt-get update -qq && apt-get install -y -qq microsoft-edge-stable \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencias Python (versiones fijadas en requirements.txt del repo + extras).
COPY requirements.txt /app/requirements.txt
RUN python3 -m pip install --no-cache-dir -r requirements.txt \
    && python3 -m pip install --no-cache-dir edge-tts

# Codigo del repo (ya parcheado para usar motores alternativos).
COPY . /app

# bin/claude es el shim que imita el CLI y llama a OpenRouter. Va PRIMERO en PATH.
RUN chmod +x /app/bin/claude \
    && mkdir -p /usr/local/bin \
    && ln -sf /app/bin/claude /usr/local/bin/claude

# Carpetas de datos persistentes.
RUN mkdir -p /data

EXPOSE 8020

# Arranca el servicio. El repo: python app.py --puerto 8020
CMD ["python3", "app.py", "--puerto", "8020"]
