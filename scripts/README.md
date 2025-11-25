# Deployment skrypty

Skrypty do automatycznego wdrażania i zarządzania Bielik VM w Azure.

## deploy.ps1 / deploy.sh

Główny skrypt deploymentu.

### Użycie PowerShell

```powershell
.\deploy.ps1 `
    -Environment <dev|staging|prod> `
    -ResourceGroupName <nazwa-rg> `
    [-Location <region>] `
    [-VmSize <rozmiar>] `
    [-SshPublicKeyPath <ścieżka>] `
    [-EnablePublicOllamaAccess <bool>]
```

### Przykłady

```powershell
# Development z domyślnymi ustawieniami
.\deploy.ps1 -Environment dev -ResourceGroupName bielik-dev-rg

# Production z GPU
.\deploy.ps1 `
    -Environment prod `
    -ResourceGroupName bielik-prod-rg `
    -VmSize Standard_NC6s_v3 `
    -Location northeurope `
    -EnablePublicOllamaAccess $true

# Z własnym kluczem SSH
.\deploy.ps1 `
    -Environment dev `
    -ResourceGroupName bielik-rg `
    -SshPublicKeyPath "~/.ssh/my-key.pub"
```

### Użycie Bash

```bash
./deploy.sh <environment> <resource-group> [location] [vm-size] [ssh-key-path] [enable-public]
```

### Przykłady

```bash
# Development
./deploy.sh dev bielik-dev-rg

# Production z GPU
./deploy.sh prod bielik-prod-rg northeurope Standard_NC6s_v3

# Z własnym kluczem
./deploy.sh dev bielik-rg westeurope Standard_D8s_v3 ~/.ssh/my-key.pub
```

## cleanup.ps1

Usuwa wszystkie zasoby.

```powershell
# Z potwierdzeniem
.\cleanup.ps1 -ResourceGroupName bielik-rg

# Bez potwierdzenia
.\cleanup.ps1 -ResourceGroupName bielik-rg -Force
```

## validate.ps1

Waliduje template Bicep przed deploymentem.

```powershell
.\validate.ps1 -ResourceGroupName bielik-rg -Environment dev
```

## Outputs

Wszystkie skrypty zapisują wyniki deployment do `deployment-output.json` w głównym katalogu projektu.

## Wymagania

- Azure CLI zainstalowane i skonfigurowane
- PowerShell 7+ (dla skryptów .ps1)
- Bash (dla skryptów .sh)
- Uprawnienia do tworzenia zasobów w Azure subscription
