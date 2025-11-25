#!/bin/bash
# ============================================================================
# Testowanie połączenia z Bielik VM
# ============================================================================

set -e

# Kolory
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parametry
VM_IP="${1}"
MODEL="${2:-SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M}"

if [[ -z "$VM_IP" ]]; then
    echo -e "${RED}Użycie: $0 <VM_IP_ADDRESS> [MODEL_NAME]${NC}"
    echo "Przykład: $0 20.82.123.45"
    exit 1
fi

BASE_URL="http://${VM_IP}:11434"

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        Test połączenia z Bielik VM                     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "VM IP: ${VM_IP}"
echo "Model: ${MODEL}"
echo "Base URL: ${BASE_URL}"
echo ""

# Test 1: Ping
echo -e "${CYAN}[1/5] Test ping...${NC}"
if ping -c 3 "${VM_IP}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ping OK${NC}"
else
    echo -e "${YELLOW}⚠️  Ping failed (może być zablokowany ICMP)${NC}"
fi
echo ""

# Test 2: Port 11434
echo -e "${CYAN}[2/5] Test portu 11434...${NC}"
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${VM_IP}/11434" 2>/dev/null; then
    echo -e "${GREEN}✅ Port 11434 otwarty${NC}"
else
    echo -e "${RED}❌ Port 11434 zamknięty lub niedostępny${NC}"
    echo "Sprawdź NSG rules i czy Ollama nasłuchuje na 0.0.0.0"
    exit 1
fi
echo ""

# Test 3: Ollama API - lista tagów
echo -e "${CYAN}[3/5] Test Ollama API - lista modeli...${NC}"
TAGS_RESPONSE=$(curl -s -m 10 "${BASE_URL}/api/tags" 2>&1)
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Ollama API odpowiada${NC}"
    echo "Dostępne modele:"
    echo "$TAGS_RESPONSE" | jq -r '.models[]?.name' 2>/dev/null || echo "$TAGS_RESPONSE"
else
    echo -e "${RED}❌ Brak odpowiedzi z Ollama API${NC}"
    echo "Response: $TAGS_RESPONSE"
    exit 1
fi
echo ""

# Test 4: Sprawdź czy model jest dostępny
echo -e "${CYAN}[4/5] Sprawdzanie dostępności modelu...${NC}"
MODEL_EXISTS=$(echo "$TAGS_RESPONSE" | jq -r ".models[]? | select(.name==\"${MODEL}\") | .name" 2>/dev/null)
if [[ "$MODEL_EXISTS" == "$MODEL" ]]; then
    echo -e "${GREEN}✅ Model ${MODEL} jest dostępny${NC}"
else
    echo -e "${RED}❌ Model ${MODEL} nie jest dostępny${NC}"
    echo "Sprawdź dostępne modele powyżej"
    exit 1
fi
echo ""

# Test 5: Testowe zapytanie
echo -e "${CYAN}[5/5] Testowe zapytanie do modelu...${NC}"
echo "Pytanie: Kim jest Adam Mickiewicz?"

CHAT_RESPONSE=$(curl -s -m 60 "${BASE_URL}/api/chat" -d "{
  \"model\": \"${MODEL}\",
  \"stream\": false,
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": \"Kim jest Adam Mickiewicz?\"
    }
  ]
}" 2>&1)

if [[ $? -eq 0 ]]; then
    ANSWER=$(echo "$CHAT_RESPONSE" | jq -r '.message.content' 2>/dev/null)
    if [[ -n "$ANSWER" && "$ANSWER" != "null" ]]; then
        echo -e "${GREEN}✅ Model odpowiedział${NC}"
        echo ""
        echo -e "${YELLOW}Odpowiedź:${NC}"
        echo "$ANSWER"
        echo ""
    else
        echo -e "${RED}❌ Błąd parsowania odpowiedzi${NC}"
        echo "Response: $CHAT_RESPONSE"
        exit 1
    fi
else
    echo -e "${RED}❌ Błąd podczas zapytania${NC}"
    echo "Response: $CHAT_RESPONSE"
    exit 1
fi

# Podsumowanie
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ Wszystkie testy zakończone pomyślnie!        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Bielik VM działa poprawnie i jest gotowy do użycia!"
echo ""
echo "Przykładowe komendy:"
echo "  curl ${BASE_URL}/api/tags"
echo "  curl ${BASE_URL}/api/chat -d '{...}'"
echo ""

exit 0
