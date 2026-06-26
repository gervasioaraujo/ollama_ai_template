# Usa a versão LTS atual do Python (3.12)
FROM python:3.12-slim

# Define o diretório de trabalho no container
WORKDIR /app

# Instala dependências de sistema necessárias para compilação
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copia o requirements e instala as bibliotecas
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia o restante do código da aplicação
COPY . .

# Comando padrão caso queira que ele rode algo ao iniciar
# CMD ["python", "main.py"]
