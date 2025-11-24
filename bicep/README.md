# Bicep Templates

Template Bicep do deploymentu Bielik na Azure VM.

## main.bicep

Główny template zawierający wszystkie zasoby:

### Zasoby
- **Virtual Machine**: Ubuntu 22.04 LTS
- **Network Security Group**: Reguły dla SSH, Ollama API, HTTP
- **Virtual Network**: VNet i Subnet
- **Public IP**: Statyczny IP z DNS label
- **Network Interface**: Połączenie VM z siecią
- **VM Extension**: Custom Script do instalacji Ollama i Bielik

### Parametry

| Parametr | Typ | Domyślna wartość | Opis |
|----------|-----|------------------|------|
| `vmName` | string | bielik-vm | Nazwa maszyny wirtualnej |
| `vmSize` | string | Standard_D8s_v3 | Rozmiar VM |
| `adminUsername` | string | azureuser | Nazwa użytkownika administratora |
| `sshPublicKey` | securestring | - | Klucz publiczny SSH (wymagany) |
| `location` | string | resourceGroup().location | Lokalizacja zasobów |
| `bielikModel` | string | SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M | Model do zainstalowania |
| `enablePublicOllamaAccess` | bool | false | Czy otworzyć port 11434 publicznie |
| `resourcePrefix` | string | bielik | Prefiks dla nazw zasobów |
| `tags` | object | {...} | Tagi dla zasobów |

### Outputs

| Output | Typ | Opis |
|--------|-----|------|
| `publicIP` | string | Publiczny adres IP |
| `fqdn` | string | Pełna nazwa DNS |
| `sshCommand` | string | Komenda do połączenia SSH |
| `ollamaApiUrl` | string | URL Ollama API |
| `installedModel` | string | Zainstalowany model |
| `vmName` | string | Nazwa VM |
| `vmResourceId` | string | Resource ID VM |

## Dostępne rozmiary VM

### CPU Only
- **Standard_D4s_v3**: 4 vCPU, 16 GB RAM - Minimum
- **Standard_D8s_v3**: 8 vCPU, 32 GB RAM - **Zalecane**
- **Standard_D16s_v3**: 16 vCPU, 64 GB RAM - Dla dużych obciążeń

### GPU
- **Standard_NC6s_v3**: 6 vCPU, 112 GB RAM, Tesla V100 16GB
- **Standard_NC4as_T4_v3**: 4 vCPU, 28 GB RAM, Tesla T4 16GB
- **Standard_NC8as_T4_v3**: 8 vCPU, 56 GB RAM, Tesla T4 16GB

## Custom Script Extension

Extension automatycznie:
1. Aktualizuje system
2. Instaluje zależności (curl, wget, git, htop)
3. Instaluje Ollama
4. Konfiguruje Ollama do nasłuchiwania na 0.0.0.0:11434
5. Pobiera model Bielik (10-15 minut)
6. Tworzy skrypty testowe i informacyjne w home directory

## Walidacja template

```powershell
az deployment group validate `
    --resource-group <rg-name> `
    --template-file bicep/main.bicep `
    --parameters @parameters/dev.parameters.json `
    --parameters sshPublicKey="<your-ssh-key>"
```

## Podgląd zmian (What-If)

```powershell
az deployment group what-if `
    --resource-group <rg-name> `
    --template-file bicep/main.bicep `
    --parameters @parameters/dev.parameters.json `
    --parameters sshPublicKey="<your-ssh-key>"
```

## Manualny deployment

```powershell
az deployment group create `
    --resource-group <rg-name> `
    --template-file bicep/main.bicep `
    --parameters @parameters/dev.parameters.json `
    --parameters sshPublicKey="<your-ssh-key>"
```

## Network Security Group Rules

| Nazwa | Port | Protokół | Priorytet | Domyślnie |
|-------|------|----------|-----------|-----------|
| SSH | 22 | TCP | 1000 | Allow |
| Ollama-API | 11434 | TCP | 1100 | Zależny od parametru |
| HTTP | 8080 | TCP | 1200 | Allow |

## Modyfikacje

### Zmień rozmiar VM

Edytuj parametr w pliku parameters:
```json
{
  "vmSize": {
    "value": "Standard_NC6s_v3"
  }
}
```

### Dodaj dysk danych

Dodaj do `storageProfile` w VM:
```bicep
dataDisks: [
  {
    name: '${vmName}-datadisk'
    diskSizeGB: 1024
    lun: 0
    createOption: 'Empty'
    managedDisk: {
      storageAccountType: 'Premium_LRS'
    }
  }
]
```

### Zmień obraz OS

Zmień `imageReference`:
```bicep
imageReference: {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts-gen2'
  version: 'latest'
}
```
