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

# Pobieranie modelu Bielik
echo "Pobieranie modelu Bielik (może to potrwać 10-15 minut)..."
su - ${ADMIN_USER} -c "ollama pull ${BIELIK_MODEL}"

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

🇵🇱 Model Bielik:
   https://huggingface.co/speakleash
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
