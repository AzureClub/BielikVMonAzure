#!/bin/bash
# ============================================================================
# Bielik + Ollama - Azure VM Deployment Script (Bash)
# ============================================================================

set -e

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================================================
# FUNKCJE POMOCNICZE
# ============================================================================

log_step() {
    echo -e "\n${CYAN}===> $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_azure_cli() {
    log_step "Sprawdzanie Azure CLI..."
    if command -v az &> /dev/null; then
        version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null)
        log_success "Azure CLI v${version} zainstalowane"
        return 0
    else
        log_error "Azure CLI nie jest zainstalowane!"
        echo "Zainstaluj z: https://learn.microsoft.com/cli/azure/install-azure-cli"
        return 1
    fi
}

check_azure_login() {
    log_step "Sprawdzanie logowania do Azure..."
    if az account show &> /dev/null; then
        account=$(az account show --query '{name:name, user:user.name, id:id}' -o json)
        user=$(echo $account | jq -r '.user')
        subscription=$(echo $account | jq -r '.name')
        log_success "Zalogowany jako: ${user}"
        echo "  Subscription: ${subscription}"
        return 0
    else
        log_warning "Nie jesteś zalogowany do Azure"
        echo "Uruchamiam 'az login'..."
        az login
        return $?
    fi
}

get_or_create_ssh_key() {
    log_step "Konfiguracja klucza SSH..."
    
    local ssh_key_path="$1"
    
    # Jeśli podano ścieżkę i plik istnieje
    if [[ -n "$ssh_key_path" && -f "$ssh_key_path" ]]; then
        log_success "Używam klucza: ${ssh_key_path}"
        cat "$ssh_key_path"
        return 0
    fi
    
    # Domyślna lokalizacja
    local default_key_path="$HOME/.ssh/id_rsa.pub"
    
    if [[ -f "$default_key_path" ]]; then
        log_success "Znaleziono klucz: ${default_key_path}"
        cat "$default_key_path"
        return 0
    fi
    
    # Generuj nowy klucz
    log_warning "Brak klucza SSH. Generuję nowy..."
    local new_key_path="$HOME/.ssh/bielik-azure-key"
    
    ssh-keygen -t rsa -b 4096 -f "$new_key_path" -N "" -C "bielik-azure-vm"
    
    if [[ -f "${new_key_path}.pub" ]]; then
        log_success "Wygenerowano nowy klucz: ${new_key_path}.pub"
        cat "${new_key_path}.pub"
        return 0
    fi
    
    log_error "Nie można utworzyć klucza SSH"
    return 1
}

# ============================================================================
# PARAMETRY
# ============================================================================

ENVIRONMENT="${1:-dev}"
RESOURCE_GROUP_NAME="${2:-bielik-rg}"
LOCATION="${3:-westeurope}"
VM_SIZE="${4:-Standard_D8s_v3}"
AUTH_TYPE="${5:-password}"  # password or sshPublicKey
ADMIN_PASSWORD="${6:-}"
SSH_PUBLIC_KEY_PATH="${7:-}"
ENABLE_PUBLIC_OLLAMA="${8:-false}"
BIELIK_MODEL="SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M"

# ============================================================================
# GŁÓWNY SKRYPT
# ============================================================================

echo -e "${MAGENTA}"
cat << "EOF"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     🚀 Bielik + Ollama - Azure VM Deployment                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
echo -e "${NC}"

# Walidacja wymagań
check_azure_cli || exit 1
check_azure_login || exit 1

# Konfiguracja uwierzytelniania
SSH_PUBLIC_KEY=""
if [[ "$AUTH_TYPE" == "password" ]]; then
    log_step "Konfiguracja uwierzytelniania hasłem..."
    
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        echo "Wprowadź hasło dla użytkownika administratora:"
        echo "(Wymagania: min. 12 znaków, małe/wielkie litery, cyfry, znaki specjalne)"
        read -s -p "Hasło: " ADMIN_PASSWORD
        echo ""
        read -s -p "Potwierdź hasło: " ADMIN_PASSWORD_CONFIRM
        echo ""
        
        if [[ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]]; then
            log_error "Hasła nie pasują!"
            exit 1
        fi
    fi
    
    log_success "Hasło skonfigurowane"
else
    # Pobierz klucz SSH
    SSH_PUBLIC_KEY=$(get_or_create_ssh_key "$SSH_PUBLIC_KEY_PATH")
    if [[ $? -ne 0 ]]; then
        log_error "Błąd konfiguracji klucza SSH"
        exit 1
    fi
fi

# Informacje o deploymencie
log_step "Konfiguracja deployment:"
echo "  Environment: ${ENVIRONMENT}"
echo "  Resource Group: ${RESOURCE_GROUP_NAME}"
echo "  Location: ${LOCATION}"
echo "  VM Size: ${VM_SIZE}"
echo "  Model: ${BIELIK_MODEL}"
echo "  Public Ollama Access: ${ENABLE_PUBLIC_OLLAMA}"

# Potwierdzenie
echo ""
read -p "Czy kontynuować? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Deployment anulowany"
    exit 0
fi

# Tworzenie Resource Group
log_step "Tworzenie Resource Group: ${RESOURCE_GROUP_NAME}"
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" --output none

if [[ $? -eq 0 ]]; then
    log_success "Resource Group utworzony"
else
    log_error "Błąd tworzenia Resource Group"
    exit 1
fi

# Ścieżki do plików
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARAMETERS_FILE="${SCRIPT_DIR}/../parameters/${ENVIRONMENT}.parameters.json"
BICEP_FILE="${SCRIPT_DIR}/../bicep/main.bicep"

# Walidacja plików
if [[ ! -f "$BICEP_FILE" ]]; then
    log_error "Brak pliku Bicep: ${BICEP_FILE}"
    exit 1
fi

# Deployment
log_step "Rozpoczynam deployment (może to potrwać 15-20 minut)..."
echo "Tworzenie infrastruktury i instalacja Ollama + Bielik..."

DEPLOYMENT_NAME="bielik-deployment-$(date +%Y%m%d-%H%M%S)"

# Budowanie parametrów
PARAMS="vmSize=${VM_SIZE} authenticationType=${AUTH_TYPE} location=${LOCATION} bielikModel=${BIELIK_MODEL} enablePublicOllamaAccess=${ENABLE_PUBLIC_OLLAMA}"

if [[ "$AUTH_TYPE" == "password" ]]; then
    PARAMS="${PARAMS} adminPassword='${ADMIN_PASSWORD}'"
else
    PARAMS="${PARAMS} sshPublicKey='${SSH_PUBLIC_KEY}'"
fi

# Dodaj parametry z pliku jeśli istnieje
if [[ -f "$PARAMETERS_FILE" ]]; then
    echo "  Używam parametrów z: ${PARAMETERS_FILE}"
    PARAMS="${PARAMS} @${PARAMETERS_FILE}"
fi

echo "  Deployment Name: ${DEPLOYMENT_NAME}"
echo ""

# Uruchom deployment
az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$BICEP_FILE" \
    --parameters $PARAMS \
    --output json > /tmp/deployment-result.json

if [[ $? -ne 0 ]]; then
    log_error "Deployment nie powiódł się!"
    cat /tmp/deployment-result.json
    exit 1
fi

# Pobranie outputs
log_step "Pobieranie informacji o deploymencie..."

OUTPUTS=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs \
    --output json)

# Parsowanie outputs
VM_NAME=$(echo $OUTPUTS | jq -r '.vmName.value')
PUBLIC_IP=$(echo $OUTPUTS | jq -r '.publicIP.value')
FQDN=$(echo $OUTPUTS | jq -r '.fqdn.value')
SSH_COMMAND=$(echo $OUTPUTS | jq -r '.sshCommand.value')
OLLAMA_URL=$(echo $OUTPUTS | jq -r '.ollamaApiUrl.value')
INSTALLED_MODEL=$(echo $OUTPUTS | jq -r '.installedModel.value')

# Wyświetlenie wyników
echo -e "\n${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     ✅ DEPLOYMENT ZAKOŃCZONY POMYŚLNIE!                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${CYAN}📋 Informacje o VM:${NC}"
echo "  VM Name: ${VM_NAME}"
echo "  Public IP: ${PUBLIC_IP}"
echo "  FQDN: ${FQDN}"
echo "  Model: ${INSTALLED_MODEL}"
echo ""

echo -e "${CYAN}🔐 Połączenie SSH:${NC}"
echo -e "  ${YELLOW}${SSH_COMMAND}${NC}"
echo ""

echo -e "${CYAN}🌐 Ollama API:${NC}"
echo -e "  ${YELLOW}${OLLAMA_URL}${NC}"
echo ""

echo -e "${CYAN}📝 Testowe zapytanie:${NC}"
echo -e "${YELLOW}  curl ${OLLAMA_URL}/api/chat -d '{
    \"model\": \"${INSTALLED_MODEL}\",
    \"stream\": false,
    \"messages\": [{\"role\": \"user\", \"content\": \"Kim jest Adam Mickiewicz?\"}]
  }'${NC}"

echo -e "\n${YELLOW}⏳ Uwaga: Instalacja Ollama i pobieranie modelu może jeszcze trwać.${NC}"
echo -e "${YELLOW}   Sprawdź status: ${SSH_COMMAND} 'tail -f /var/log/azure/custom-script/handler.log'${NC}"

echo -e "\n${CYAN}💾 Zapisuję wyniki do pliku...${NC}"
OUTPUT_FILE="${SCRIPT_DIR}/../deployment-output.json"
echo $OUTPUTS | jq '.' > "$OUTPUT_FILE"
log_success "Zapisano: ${OUTPUT_FILE}"

echo -e "\n${GREEN}🎉 Deployment zakończony! Miłego korzystania z Bielika! 🎉${NC}\n"

exit 0
