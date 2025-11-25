#!/bin/bash
set -e

ADMIN_USER="__ADMIN_USER__"
BIELIK_MODEL="__BIELIK_MODEL__"

echo "======================================"
echo "Rozpoczynam instalację Ollama i Bielik"
echo "======================================"
echo "Użytkownik: $ADMIN_USER"
echo "Model: $BIELIK_MODEL"

# Aktualizacja systemu
echo "Aktualizacja pakietów..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Instalacja zależności
echo "Instalacja zależności..."
apt-get install -y curl wget git htop

# Instalacja Ollama
echo "Instalacja Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# Czekaj aż usługa Ollama się uruchomi
echo "Oczekiwanie na uruchomienie Ollama..."
sleep 5

# Sprawdź status usługi
systemctl status ollama --no-pager || true

# Konfiguracja Ollama do nasłuchiwania na wszystkich interfejsach
echo "Konfiguracja Ollama..."
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

# Restart usługi Ollama
systemctl daemon-reload
systemctl restart ollama
sleep 5

# Pobieranie modelu Bielik v2.6 z HuggingFace
echo "Pobieranie modelu Bielik v2.6 z HuggingFace (może to potrwać 10-15 minut)..."

# Model jest dostępny tylko jako GGUF na HuggingFace, nie w bibliotece Ollama
GGUF_URL="https://huggingface.co/speakleash/Bielik-11B-v2.6-Instruct-GGUF/resolve/main/Bielik-11B-v2.6-Instruct.Q4_K_M.gguf"
GGUF_FILE="/tmp/bielik-v2.6-q4km.gguf"
MODELFILE="/tmp/Modelfile.bielik-v2.6"

# Pobierz plik GGUF
echo "Pobieranie pliku GGUF (6.72GB)..."
wget -q --show-progress -O "${GGUF_FILE}" "${GGUF_URL}" || {
    echo "❌ Błąd pobierania pliku GGUF"
    exit 1
}

# Utwórz Modelfile zgodnie z dokumentacją HuggingFace
echo "Tworzenie Modelfile..."
cat > "${MODELFILE}" << 'MODELFILE_EOF'
FROM /tmp/bielik-v2.6-q4km.gguf

TEMPLATE """<|im_start|>system
{{ .System }}<|im_end|>
<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant
"""

PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
PARAMETER temperature 0.6
PARAMETER top_p 0.9
MODELFILE_EOF

# Utwórz model w Ollama z pobranego GGUF
echo "Tworzenie modelu w Ollama..."
su - ${ADMIN_USER} -c "ollama create ${BIELIK_MODEL} -f ${MODELFILE}" || {
    echo "❌ Błąd tworzenia modelu w Ollama"
    exit 1
}

# Opcjonalne: Usuń pliki tymczasowe (GGUF jest ~7GB)
# rm -f "${GGUF_FILE}" "${MODELFILE}"
echo "Plik GGUF pozostawiony w: ${GGUF_FILE}"

# Weryfikacja instalacji
echo "Weryfikacja instalacji..."
su - ${ADMIN_USER} -c "ollama list"

# Tworzenie skryptu testowego
cat > /home/${ADMIN_USER}/test-bielik.sh << TESTEOF
#!/bin/bash
echo "Test Bielik API..."
curl http://localhost:11434/api/chat -d '{
  "model": "${BIELIK_MODEL}",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": "Kim jest Adam Mickiewicz?"
    }
  ]
}'
TESTEOF

chmod +x /home/${ADMIN_USER}/test-bielik.sh
chown ${ADMIN_USER}:${ADMIN_USER} /home/${ADMIN_USER}/test-bielik.sh

# Tworzenie skryptu informacyjnego
cat > /home/${ADMIN_USER}/bielik-info.txt << INFOEOF
============================================
Bielik + Ollama - Informacje o instalacji
============================================

✅ Instalacja zakończona pomyślnie!

Model: ${BIELIK_MODEL}

📝 Podstawowe komendy:

1. Sprawdź zainstalowane modele:
   ollama list

2. Uruchom model interaktywnie:
   ollama run ${BIELIK_MODEL}

3. Test API:
   ./test-bielik.sh

4. Status usługi Ollama:
   systemctl status ollama

5. Logi Ollama:
   journalctl -u ollama -f

🌐 API Endpoint:
   http://localhost:11434

📚 Dokumentacja Ollama:
   https://github.com/ollama/ollama

🇵🇱 Model Bielik v2.6:
   https://huggingface.co/speakleash/Bielik-11B-v2.6-Instruct-GGUF

⚠️ Uwaga:
   Model v2.6 jest instalowany z HuggingFace (GGUF),
   ponieważ nie jest jeszcze dostępny w bibliotece Ollama.
   Plik GGUF (~7GB) znajduje się w /tmp/bielik-v2.6-q4km.gguf
INFOEOF

chown ${ADMIN_USER}:${ADMIN_USER} /home/${ADMIN_USER}/bielik-info.txt

echo "======================================"
echo "✅ Instalacja zakończona!"
echo "======================================"
echo ""
echo "Ollama API: http://localhost:11434"
echo "Model: ${BIELIK_MODEL}"
echo ""
echo "Sprawdź: cat ~/bielik-info.txt"

exit 0
