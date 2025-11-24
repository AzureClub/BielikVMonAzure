<#
.SYNOPSIS
    Automatyczny deployment Bielik + Ollama na Azure VM

.DESCRIPTION
    Skrypt automatyzuje pełny deployment infrastruktury Azure i instalację Bielik z Ollama.
    Tworzy Resource Group, wdraża VM, instaluje Ollama i pobiera model Bielik.

.PARAMETER Environment
    Środowisko deployment (dev, staging, prod)

.PARAMETER ResourceGroupName
    Nazwa Resource Group (zostanie utworzona jeśli nie istnieje)

.PARAMETER Location
    Lokalizacja Azure

.PARAMETER VmSize
    Rozmiar VM

.PARAMETER AdminPassword
    Hasło administratora (SecureString). Jeśli podane, używa uwierzytelniania hasłem.
    Jeśli nie podane, automatycznie używa klucza SSH.

.PARAMETER SshPublicKeyPath
    Ścieżka do klucza publicznego SSH (opcjonalne).
    Jeśli nie podane, skrypt użyje ~/.ssh/id_rsa.pub lub wygeneruje nowy klucz.

.PARAMETER EnablePublicOllamaAccess
    Czy otworzyć port Ollama API publicznie

.EXAMPLE
    .\deploy.ps1 -Environment dev -ResourceGroupName bielik-rg
    # Domyślnie: SSH key (automatycznie wygenerowany jeśli brak)

.EXAMPLE
    $pwd = ConvertTo-SecureString "MyP@ssw0rd123!" -AsPlainText -Force
    .\deploy.ps1 -Environment prod -ResourceGroupName bielik-rg -AdminPassword $pwd
    # Z hasłem

.EXAMPLE
    .\deploy.ps1 -Environment prod -ResourceGroupName bielik-prod-rg -VmSize Standard_NC24ads_A100_v4 -Location polandcentral -EnablePublicOllamaAccess $true
    # SSH key z customowym VM
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'westeurope',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Standard_D4s_v3', 'Standard_D8s_v3', 'Standard_D16s_v3', 'Standard_NC6s_v3', 'Standard_NC4as_T4_v3', 'Standard_NC24ads_A100_v4', 'Standard_NC48ads_A100_v4', 'Standard_NC96ads_A100_v4')]
    [string]$VmSize = 'Standard_D8s_v3',

    [Parameter(Mandatory = $false)]
    [SecureString]$AdminPassword,

    [Parameter(Mandatory = $false)]
    [string]$SshPublicKeyPath = '',

    [Parameter(Mandatory = $false)]
    [bool]$EnablePublicOllamaAccess = $false,

    [Parameter(Mandatory = $false)]
    [string]$BielikModel = 'SpeakLeash/bielik-11b-v2.6-instruct'
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# FUNKCJE POMOCNICZE
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n===> $Message" -Color Cyan
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✅ $Message" -Color Green
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "❌ $Message" -Color Red
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠️  $Message" -Color Yellow
}

function Test-AzureCLI {
    Write-Step "Sprawdzanie Azure CLI..."
    try {
        $version = az version --query '\"azure-cli\"' -o tsv 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Azure CLI v$version zainstalowane"
            return $true
        }
    }
    catch {
        Write-Error "Azure CLI nie jest zainstalowane!"
        Write-Host "Zainstaluj z: https://learn.microsoft.com/cli/azure/install-azure-cli"
        return $false
    }
    return $false
}

function Test-AzureLogin {
    Write-Step "Sprawdzanie logowania do Azure..."
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Success "Zalogowany jako: $($account.user.name)"
            Write-Host "  Subscription: $($account.name) ($($account.id))"
            return $true
        }
    }
    catch {
        Write-Warning "Nie jesteś zalogowany do Azure"
        Write-Host "Uruchamiam 'az login'..."
        az login
        return $?
    }
    return $false
}

function Get-OrCreateSSHKey {
    param([string]$Path)
    
    Write-Step "Konfiguracja klucza SSH..."
    
    if ($Path -and (Test-Path $Path)) {
        $keyContent = (Get-Content $Path -Raw).Trim()
        if ($keyContent -match '^ssh-rsa |^ecdsa-sha2-|^ssh-ed25519 ') {
            Write-Success "Używam klucza: $Path"
            return $keyContent
        }
        else {
            Write-Warning "Plik $Path nie zawiera prawidłowego klucza publicznego SSH"
        }
    }
    
    # Domyślna lokalizacja
    $defaultKeyPath = Join-Path $env:USERPROFILE ".ssh\id_rsa.pub"
    
    if (Test-Path $defaultKeyPath) {
        $keyContent = (Get-Content $defaultKeyPath -Raw).Trim()
        if ($keyContent -match '^ssh-rsa |^ecdsa-sha2-|^ssh-ed25519 ') {
            Write-Success "Znaleziono klucz: $defaultKeyPath"
            return $keyContent
        }
    }
    
    # Generuj nowy klucz
    Write-Warning "Brak klucza SSH. Generuję nowy..."
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    
    $newKeyPath = Join-Path $sshDir "bielik-azure-key"
    
    # Usuń stary klucz jeśli istnieje
    if (Test-Path $newKeyPath) {
        Remove-Item $newKeyPath -Force
    }
    if (Test-Path "$newKeyPath.pub") {
        Remove-Item "$newKeyPath.pub" -Force
    }
    
    # Generuj nowy klucz bez hasła (-N "")
    $result = ssh-keygen -t rsa -b 4096 -f $newKeyPath -N '""' -C "bielik-azure-vm" 2>&1
    
    if (Test-Path "$newKeyPath.pub") {
        $keyContent = (Get-Content "$newKeyPath.pub" -Raw).Trim()
        if ($keyContent -match '^ssh-rsa ') {
            Write-Success "Wygenerowano nowy klucz: $newKeyPath.pub"
            Write-Host "  Klucz prywatny: $newKeyPath"
            return $keyContent
        }
        else {
            throw "Wygenerowany klucz ma nieprawidłowy format"
        }
    }
    
    throw "Nie można utworzyć klucza SSH. Output: $result"
}

# ============================================================================
# GŁÓWNY SKRYPT
# ============================================================================

Write-ColorOutput @"

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     🚀 Bielik + Ollama - Azure VM Deployment                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -Color Magenta

# Walidacja wymagań
if (-not (Test-AzureCLI)) { exit 1 }
if (-not (Test-AzureLogin)) { exit 1 }

# Automatyczne wykrywanie typu uwierzytelniania
$AuthenticationType = if ($AdminPassword -and $AdminPassword.Length -gt 0) { 'password' } else { 'sshPublicKey' }

# Konfiguracja uwierzytelniania
$sshPublicKey = ""
$passwordPlainText = ""

if ($AuthenticationType -eq 'password') {
    Write-Step "Konfiguracja uwierzytelniania hasłem..."
    $passwordPlainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword))
    Write-Success "Hasło skonfigurowane"
}
else {
    Write-Step "Konfiguracja uwierzytelniania SSH..."
    # Pobierz lub wygeneruj klucz SSH
    try {
        $sshPublicKey = Get-OrCreateSSHKey -Path $SshPublicKeyPath
    }
    catch {
        Write-Error "Błąd konfiguracji klucza SSH: $_"
        exit 1
    }
}

# Informacje o deploymencie
Write-Step "Konfiguracja deployment:"
Write-Host "  Environment: $Environment"
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  Location: $Location"
Write-Host "  VM Size: $VmSize"
Write-Host "  Authentication: $AuthenticationType"
Write-Host "  Model: $BielikModel"
Write-Host "  Public Ollama Access: $EnablePublicOllamaAccess"

# Potwierdzenie
Write-Host ""
$confirmation = Read-Host "Czy kontynuować? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Warning "Deployment anulowany"
    exit 0
}

# Tworzenie Resource Group
Write-Step "Tworzenie Resource Group: $ResourceGroupName"
az group create --name $ResourceGroupName --location $Location --output none

if ($LASTEXITCODE -eq 0) {
    Write-Success "Resource Group utworzony"
}
else {
    Write-Error "Błąd tworzenia Resource Group"
    exit 1
}

# Przygotowanie parametrów
$parametersFile = Join-Path $PSScriptRoot "..\parameters\$Environment.parameters.json"
$bicepFile = Join-Path $PSScriptRoot "..\bicep\main.bicep"

# Walidacja plików
if (-not (Test-Path $bicepFile)) {
    Write-Error "Brak pliku Bicep: $bicepFile"
    exit 1
}

# Deployment
Write-Step "Rozpoczynam deployment (może to potrwać 15-20 minut)..."
Write-Host "Tworzenie infrastruktury i instalacja Ollama + Bielik..."

$deploymentName = "bielik-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Budowanie parametrów jako array dla Azure CLI
$deployParams = @(
    "vmSize=$VmSize"
    "authenticationType=$AuthenticationType"
    "location=$Location"
    "bielikModel=$BielikModel"
    "enablePublicOllamaAccess=$EnablePublicOllamaAccess"
)

# Uruchom deployment
$deploymentCommand = @(
    "deployment", "group", "create"
    "--resource-group", $ResourceGroupName
    "--name", $deploymentName
    "--template-file", $bicepFile
)

# Dodaj parametry z pliku jeśli istnieje
if (Test-Path $parametersFile) {
    Write-Host "  Używam parametrów z: $parametersFile"
    $deploymentCommand += "--parameters"
    $deploymentCommand += "@$parametersFile"
}

# Dodaj runtime parametry
foreach ($param in $deployParams) {
    $deploymentCommand += "--parameters"
    $deploymentCommand += $param
}

# Dodaj hasło lub klucz SSH
if ($AuthenticationType -eq 'password') {
    $deploymentCommand += "--parameters"
    $deploymentCommand += "adminPassword=$passwordPlainText"
}
else {
    $deploymentCommand += "--parameters"
    $deploymentCommand += "sshPublicKey=$sshPublicKey"
}

$deploymentCommand += "--output"
$deploymentCommand += "json"

Write-Host "  Deployment Name: $deploymentName"
Write-Host ""

$deploymentResult = & az @deploymentCommand 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment nie powiódł się!"
    Write-Host $deploymentResult
    exit 1
}

# Pobranie outputs bezpośrednio z Azure (zamiast parsowania wyniku z warnings)
Write-Step "Pobieranie informacji o deploymencie..."

$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --query properties.outputs `
    --output json 2>$null | ConvertFrom-Json

if (-not $outputs) {
    Write-Warning "Nie można pobrać outputs z deploymentu"
    Write-Host "Sprawdź deployment ręcznie:"
    Write-Host "  az deployment group show --resource-group $ResourceGroupName --name $deploymentName"
    exit 1
}

# Wyświetlenie wyników
Write-ColorOutput "`n╔═══════════════════════════════════════════════════════════════╗" -Color Green
Write-ColorOutput "║                                                               ║" -Color Green
Write-ColorOutput "║     ✅ DEPLOYMENT ZAKOŃCZONY POMYŚLNIE!                       ║" -Color Green
Write-ColorOutput "║                                                               ║" -Color Green
Write-ColorOutput "╚═══════════════════════════════════════════════════════════════╝`n" -Color Green

Write-Host "📋 Informacje o VM:" -ForegroundColor Cyan
Write-Host "  VM Name: $($outputs.vmName.value)"
Write-Host "  Public IP: $($outputs.publicIP.value)"
Write-Host "  FQDN: $($outputs.fqdn.value)"
Write-Host "  Model: $($outputs.installedModel.value)"
Write-Host ""

Write-Host "🔐 Połączenie SSH:" -ForegroundColor Cyan
Write-Host "  $($outputs.sshCommand.value)" -ForegroundColor Yellow
Write-Host ""

Write-Host "🌐 Ollama API:" -ForegroundColor Cyan
Write-Host "  $($outputs.ollamaApiUrl.value)" -ForegroundColor Yellow
Write-Host ""

Write-Host "📝 Testowe zapytanie:" -ForegroundColor Cyan
Write-Host @"
  curl $($outputs.ollamaApiUrl.value)/api/chat -d '{
    "model": "$($outputs.installedModel.value)",
    "stream": false,
    "messages": [{"role": "user", "content": "Kim jest Adam Mickiewicz?"}]
  }'
"@ -ForegroundColor Yellow

Write-Host "`n⏳ Uwaga: Instalacja Ollama i pobieranie modelu może jeszcze trwać." -ForegroundColor Yellow
Write-Host "   Sprawdź status: $($outputs.sshCommand.value) 'tail -f /var/log/azure/custom-script/handler.log'" -ForegroundColor Yellow

Write-Host "`n💾 Zapisuję wyniki do pliku..." -ForegroundColor Cyan
$outputFile = Join-Path $PSScriptRoot "..\deployment-output.json"
$outputs | ConvertTo-Json -Depth 10 | Out-File $outputFile
Write-Success "Zapisano: $outputFile"

Write-Host "`n🎉 Deployment zakończony! Miłego korzystania z Bielika! 🎉`n" -ForegroundColor Green

exit 0
