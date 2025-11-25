# Szybki start - Quick Start Guide

Najszybsza ścieżka do uruchomienia Bielik na Azure VM.

## ⚡ 5 kroków do działającego Bielika

### 1️⃣ Zaloguj się do Azure

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

### 2️⃣ Uruchom deployment

```powershell
cd c:\repos\BielikVM
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName bielik-rg
# Skrypt zapyta o hasło dla VM (min. 12 znaków)
```

**Lub z kluczem SSH:**
```powershell
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName bielik-rg -AuthenticationType sshPublicKey
```

### 3️⃣ Czekaj ~15-20 minut ☕

Skrypt automatycznie:
- Utworzy VM w Azure
- Zainstaluje Ollama
- Pobierze model Bielik

### 4️⃣ Zapisz informacje

Po zakończeniu zobaczysz:
```
✅ DEPLOYMENT ZAKOŃCZONY POMYŚLNIE!

📋 Informacje o VM:
  Public IP: 20.82.123.45
  SSH: ssh azureuser@20.82.123.45
  Ollama API: http://20.82.123.45:11434
```

### 5️⃣ Testuj!

```bash
# Połącz się przez SSH (użyj hasła podanego przy deployment)
ssh azureuser@<PUBLIC_IP>

# Sprawdź modele
ollama list

# Uruchom interaktywnie
ollama run SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M

# Lub testuj API
curl http://localhost:11434/api/chat -d '{
  "model": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M",
  "messages": [{"role": "user", "content": "Cześć!"}]
}'
```

## 🎯 Gotowe!

Teraz masz działającego Bielika na Azure VM!

---

## 📚 Następne kroki

- Przeczytaj [README.md](../README.md) dla pełnej dokumentacji
- Zobacz [przykłady API](../examples/api-examples.md)
- Sprawdź [Python client](../examples/python-client.py)

## 🛑 Wyłączanie VM (oszczędzaj koszty!)

```powershell
# Wyłącz (deallocate - nie płacisz za compute)
az vm deallocate -g bielik-rg -n bielik-vm

# Włącz ponownie
az vm start -g bielik-rg -n bielik-vm
```

## 🗑️ Usuwanie wszystkiego

```powershell
.\scripts\cleanup.ps1 -ResourceGroupName bielik-rg
```
