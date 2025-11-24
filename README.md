# 🚀 Bielik na Azure VM - Automatyczny Deployment

[![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com/)
[![Bicep](https://img.shields.io/badge/Bicep-blue?style=flat&logo=microsoft&logoColor=white)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
[![Ollama](https://img.shields.io/badge/Ollama-000000?style=flat&logo=ollama&logoColor=white)](https://ollama.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Security Audit](https://img.shields.io/badge/Security-Audited-green.svg)](SECURITY_AUDIT.md)

Kompletne, gotowe do użycia rozwiązanie do automatycznego wdrożenia polskiego modelu językowego **Bielik** z **Ollama** na maszynie wirtualnej **Azure**.

🎯 **One-click deployment** | 🔒 **Pełna kontrola** | 💰 **Optymalizacja kosztów** | 📚 **Pełna dokumentacja**

## 📋 Spis treści

- [Wymagania](#wymagania)
- [Architektura](#architektura)
- [Szybki start](#szybki-start)
- [Konfiguracja](#konfiguracja)
- [Deployment](#deployment)
- [Weryfikacja](#weryfikacja)
- [Troubleshooting](#troubleshooting)
- [Bezpieczeństwo](#bezpieczeństwo)

## 🔧 Wymagania

### Azure
- Aktywna subskrypcja Azure
- Azure CLI zainstalowane ([instrukcja](https://learn.microsoft.com/cli/azure/install-azure-cli))
- Wystarczające limity na VM (zalecane Standard_NC6s_v3 lub Standard_D8s_v3)

### Lokalne
- PowerShell 7+ lub Bash
- Git (opcjonalnie)

## 🏗️ Architektura

Rozwiązanie automatycznie tworzy:

- **Virtual Machine**: Ubuntu 22.04 LTS (Standard_D8s_v3 lub z GPU)
- **Networking**: VNet, Subnet, Public IP, NSG
- **Storage**: OS Disk (Premium SSD)
- **Ollama**: Automatycznie zainstalowane
- **Bielik**: Model `SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M` pobrany i gotowy

### Porty otwarte w NSG
- **22**: SSH
- **11434**: Ollama API
- **8080**: Opcjonalny web interface

## 🚀 Szybki start

### Najszybsza metoda (A100 GPU w Polsce) 🚀

```powershell
# 1. Ustaw hasło (będzie zapisane w zmiennej $pwd)
$pwd = ConvertTo-SecureString "TwojeHaslo123!" -AsPlainText -Force

# 2. Uruchom deployment z A100 GPU
.\scripts\deploy.ps1 `
    -Environment prod `
    -ResourceGroupName bielik-rg `
    -VmSize Standard_NC24ads_A100_v4 `
    -Location polandcentral `
    -AdminPassword $pwd `
    -EnablePublicOllamaAccess $true

# 3. Po ~15-20 minutach testuj API (zastąp IP otrzymanym po deployment)
curl http://20.20.20.20:11434/api/chat -d '{
  "model": "SpeakLeash/bielik-11b-v2.6-instruct",
  "stream": false,
  "messages": [{"role": "user", "content": "Kim jest Adam Mickiewicz?"}]
}'
```

### Krok po kroku

#### 1. Sklonuj repozytorium

```bash
git clone https://github.com/AzureClub/BielikVMonAzure.git
cd BielikVMonAzure
```

#### 2. Zaloguj się do Azure

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

#### 3. Dostosuj parametry (opcjonalnie)

Edytuj plik `parameters/dev.parameters.json`:

```json
{
  "vmSize": "Standard_D8s_v3",
  "adminUsername": "azureuser",
  "location": "westeurope"
}
```

#### 4. Uruchom deployment

```powershell
# PowerShell - podstawowy deployment
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName bielik-rg

# Bash
./scripts/deploy.sh dev bielik-rg
```

#### 5. Czekaj na zakończenie (~15-20 minut)

Skrypt automatycznie:
- Utworzy resource group
- Wdroży infrastrukturę (VM, network, itp.)
- Zainstaluje Ollama
- Pobierze model Bielik
- Wyświetli informacje o połączeniu

## ⚙️ Konfiguracja

### Rozmiary VM

| Rozmiar | vCPU | RAM | GPU | Zalecenia |
|---------|------|-----|-----|-----------||
| Standard_D4s_v3 | 4 | 16 GB | - | Minimum, wolniejsze |
| Standard_D8s_v3 | 8 | 32 GB | - | **Zalecane** dla CPU |
| Standard_NC6s_v3 | 6 | 112 GB | Tesla V100 | GPU starszej generacji |
| Standard_NC4as_T4_v3 | 4 | 28 GB | Tesla T4 | GPU entry-level |
| Standard_NC24ads_A100_v4 | 24 | 220 GB | **NVIDIA A100** | **Najlepsze** dla LLM |
| Standard_NC48ads_A100_v4 | 48 | 440 GB | **NVIDIA A100** | Duże modele |
| Standard_NC96ads_A100_v4 | 96 | 880 GB | **NVIDIA A100** | Enterprise |

### Dostępne parametry

Pełna lista w `bicep/main.bicep`:

```bicep
param vmName string = 'bielik-vm'
param vmSize string = 'Standard_D8s_v3'
param adminUsername string = 'azureuser'
param location string = resourceGroup().location
param bielikModel string = 'SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M'
```

### Uwierzytelnianie

**Domyślnie: Hasło** (prostsze, zalecane)
```powershell
# Skrypt zapyta o hasło podczas deployment
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName bielik-rg

# Lub podaj hasło w parametrze
$pwd = ConvertTo-SecureString "TwojeHaslo123!" -AsPlainText -Force
.\scripts\deploy.ps1 -AuthenticationType password -AdminPassword $pwd -ResourceGroupName bielik-rg
```

**Opcjonalnie: Klucz SSH** (bardziej bezpieczne)
```powershell
# Wygeneruj nowy klucz
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bielik-azure-key

# Użyj w deploymencie
.\scripts\deploy.ps1 -AuthenticationType sshPublicKey -SshPublicKeyPath "~/.ssh/bielik-azure-key.pub" -ResourceGroupName bielik-rg
```

## 📦 Deployment

### Standardowy deployment

```powershell
.\scripts\deploy.ps1 `
    -Environment dev `
    -ResourceGroupName bielik-rg `
    -Location westeurope
```

### Z niestandardowymi parametrami

```powershell
.\scripts\deploy.ps1 `
    -Environment prod `
    -ResourceGroupName bielik-prod-rg `
    -VmSize Standard_NC6s_v3 `
    -Location northeurope
```

### Tylko infrastruktura (bez instalacji)

```powershell
az deployment group create `
    --resource-group bielik-rg `
    --template-file bicep/main.bicep `
    --parameters @parameters/dev.parameters.json
```

## ✅ Weryfikacja

### 1. Sprawdź status VM

```powershell
az vm show -g bielik-rg -n bielik-vm --query "provisioningState"
```

### 2. Podłącz się przez SSH

```bash
ssh azureuser@<PUBLIC_IP>
```

### 3. Sprawdź status Ollama

```bash
ollama list
# Powinien pokazać: SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M

curl http://localhost:11434/api/tags
```

### 4. Testowe zapytanie

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": "Kim jest Adam Mickiewicz?"
    }
  ]
}'
```

### 5. Z zewnątrz (jeśli otwarty port)

```bash
curl http://<PUBLIC_IP>:11434/api/tags
```

## 🔍 Troubleshooting

### Ollama nie działa

```bash
# Sprawdź status usługi
sudo systemctl status ollama

# Sprawdź logi
sudo journalctl -u ollama -f

# Restart usługi
sudo systemctl restart ollama
```

### Model nie został pobrany

```bash
# Ręcznie pobierz model
ollama pull SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M

# Sprawdź dostępne modele
ollama list
```

### Brak połączenia z API

```bash
# Sprawdź czy Ollama nasłuchuje
sudo netstat -tlnp | grep 11434

# Sprawdź NSG rules
az network nsg rule list -g bielik-rg --nsg-name bielik-nsg --output table
```

### VM działa wolno

- Rozważ większy VM size: Standard_D8s_v3 lub z GPU
- Sprawdź użycie zasobów: `htop`, `nvidia-smi` (dla GPU)

### Deployment się nie powiódł

```powershell
# Sprawdź logi deployment
az deployment group show `
    -g bielik-rg `
    -n <deployment-name> `
    --query properties.error

# Sprawdź logi extension
az vm extension list -g bielik-rg --vm-name bielik-vm
```

## 📚 Dodatkowe zasoby

### Dokumentacja projektu
- 📖 [Quick Start Guide](QUICKSTART.md) - Szybki start w 5 krokach
- 🏗️ [Architektura](docs/ARCHITECTURE.md) - Szczegółowy opis architektury
- 💰 [Analiza kosztów](docs/COSTS.md) - Szacowanie i optymalizacja kosztów
- ❓ [FAQ](docs/FAQ.md) - Często zadawane pytania
- 🔧 [Troubleshooting](docs/TROUBLESHOOTING.md) - Rozwiązywanie problemów

### Zewnętrzne zasoby
- [Dokumentacja Ollama](https://github.com/ollama/ollama) - Ollama GitHub
- [Bielik Model](https://huggingface.co/speakleash/Bielik-11B-v2.2-Instruct-GGUF) - HuggingFace
- [SpeakLeash](https://github.com/speakleash/Bielik-how-to-start) - Bielik how-to-start
- [Azure VM Sizes](https://learn.microsoft.com/azure/virtual-machines/sizes) - Rozmiary VM
- [Azure Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/) - Dokumentacja Bicep

## 🤝 Wkład w projekt

Chcesz pomóc? Świetnie! Sprawdź [CONTRIBUTING.md](CONTRIBUTING.md)

Możesz:
- 🐛 Zgłaszać błędy
- 💡 Proponować nowe funkcje
- 📝 Poprawiać dokumentację
- 🔧 Dodawać nowe features

## 🆘 Wsparcie

W przypadku problemów:

1. 📖 Sprawdź [FAQ](docs/FAQ.md)
2. 🔍 Zobacz [Troubleshooting](docs/TROUBLESHOOTING.md)
3. 💬 Otwórz [Issue na GitHub](../../issues)
4. 📧 Przejrzyj logi: `sudo journalctl -u ollama -f`

## 🎓 O Bielik

**Bielik** to polski model językowy (LLM) rozwijany przez społeczność [SpeakLeash](https://speakleash.org/). Model jest wytrenowany na polskich danych i oferuje lepszą jakość dla języka polskiego niż międzynarodowe modele.

### Dostępne wersje
- **Bielik-7B** - 7 miliardów parametrów
- **Bielik-11B** - 11 miliardów parametrów (używane w tym projekcie)

### Kwantyzacje
- Q2_K - Najmniejszy, najszybszy, najniższa jakość
- **Q4_K_M** - Zbalansowany (domyślny w projekcie)
- Q5_K_M - Wyższa jakość, więcej RAM
- Q8_0 - Najwyższa jakość, najwięcej RAM

## 📝 Licencja

Projekt udostępniony na licencji [MIT License](LICENSE).

**Uwaga**: Model Bielik i Ollama mają własne licencje:
- Bielik: [Sprawdź SpeakLeash](https://github.com/speakleash/Bielik-how-to-start)
- Ollama: [MIT License](https://github.com/ollama/ollama/blob/main/LICENSE)

## ⭐ Stars & Forks

Jeśli projekt Ci pomógł, zostaw ⭐ na GitHub!

## 📞 Kontakt

- 💬 Issues: [GitHub Issues](../../issues)
- 🌐 SpeakLeash: [https://speakleash.org/](https://speakleash.org/)
- 📧 Bielik: [GitHub Discussions](https://github.com/speakleash/Bielik-how-to-start/discussions)

---

## ⚠️ Ważne przypomnienie

**Pamiętaj o kosztach Azure VM!**

```powershell
# Wyłącz gdy nie używasz (oszczędzasz ~$280/m dla D8s_v3)
az vm deallocate -g bielik-rg -n bielik-vm

# Włącz ponownie gdy potrzebujesz
az vm start -g bielik-rg -n bielik-vm
```

**Autoshutdown** - Ustaw automatyczne wyłączanie:
```powershell
az vm auto-shutdown -g bielik-rg -n bielik-vm --time 1800  # 18:00 UTC
```

---

## 🔒 Bezpieczeństwo

To repozytorium zostało poddane audytowi bezpieczeństwa i jest bezpieczne dla użytku publicznego.

### Dokumentacja Bezpieczeństwa
- 📋 [**Audyt Bezpieczeństwa**](SECURITY_AUDIT.md) - Szczegółowy raport z audytu
- 🛡️ [**Polityka Bezpieczeństwa**](SECURITY.md) - Jak zgłaszać podatności

### Najlepsze Praktyki
- ✅ Używaj silnych haseł (12+ znaków) lub kluczy SSH
- ✅ Ogranicz NSG do zaufanych IP (SSH port 22)
- ✅ Ustaw `enablePublicOllamaAccess: false` jeśli nie potrzebujesz publicznego API
- ❌ NIGDY nie commituj haseł lub kluczy SSH do repozytorium
- ❌ NIGDY nie używaj przykładowych haseł z dokumentacji w produkcji

### Zgłaszanie Podatności
Znalazłeś lukę bezpieczeństwa? Zobacz [SECURITY.md](SECURITY.md) dla instrukcji zgłaszania.

---

<div align="center">

**Zbudowane z ❤️ dla polskiej społeczności AI**

[⬆ Powrót na górę](#-bielik-na-azure-vm---automatyczny-deployment)

</div>
