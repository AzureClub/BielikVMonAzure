<#
.SYNOPSIS
    Usuwa zasoby Bielik VM z Azure

.DESCRIPTION
    Skrypt usuwa Resource Group i wszystkie powiązane zasoby

.PARAMETER ResourceGroupName
    Nazwa Resource Group do usunięcia

.PARAMETER Force
    Usuń bez potwierdzenia

.EXAMPLE
    .\cleanup.ps1 -ResourceGroupName bielik-rg
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n⚠️  UWAGA: Ta operacja usunie wszystkie zasoby w Resource Group: $ResourceGroupName" -Color Yellow

if (-not $Force) {
    $confirmation = Read-Host "`nCzy na pewno chcesz kontynuować? Wpisz nazwę Resource Group aby potwierdzić"
    
    if ($confirmation -ne $ResourceGroupName) {
        Write-ColorOutput "Operacja anulowana" -Color Green
        exit 0
    }
}

Write-ColorOutput "`nUsuwanie Resource Group: $ResourceGroupName..." -Color Cyan

try {
    az group delete --name $ResourceGroupName --yes --no-wait
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Usuwanie rozpoczęte (operacja w tle)" -Color Green
        Write-ColorOutput "Sprawdź status: az group show -n $ResourceGroupName" -Color White
    }
    else {
        Write-ColorOutput "❌ Błąd podczas usuwania" -Color Red
        exit 1
    }
}
catch {
    Write-ColorOutput "❌ Błąd: $_" -Color Red
    exit 1
}
