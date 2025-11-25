# Troubleshooting Guide

Przewodnik rozwiązywania problemów z Bielik VM.

## 🔍 Diagnostyka podstawowa

### Sprawdź status VM

```powershell
# PowerShell
az vm show -g bielik-rg -n bielik-vm --query "provisioningState"

# Sprawdź czy VM działa
az vm get-instance-view -g bielik-rg -n bielik-vm --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
```

### Sprawdź logi extension

```powershell
# Lista extensions
az vm extension list -g bielik-rg --vm-name bielik-vm --output table

# Logi custom script (na VM)
ssh azureuser@<IP> 'sudo cat /var/log/azure/custom-script/handler.log'
ssh azureuser@<IP> 'sudo journalctl -u ollama'
```

---

## ❌ Deployment się nie powiódł

### Problem: Błąd podczas tworzenia VM

**Objawy:**
```
ERROR: The subscription is not registered to use namespace 'Microsoft.Compute'
```

**Rozwiązanie:**
```powershell
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
```

### Problem: Brak dostępnych quotas na VM

**Objawy:**
```
ERROR: Operation could not be completed as it results in exceeding approved quota
```

**Rozwiązanie:**
1. Sprawdź dostępne limity:
```powershell
az vm list-usage --location westeurope --output table
```

2. Zmniejsz rozmiar VM lub zwiększ quota:
   - Portal Azure → Subscriptions → Usage + quotas
   - Wybierz region i typ VM
   - Request quota increase

### Problem: SSH key error

**Objawy:**
```
ERROR: The SSH public key is not valid
```

**Rozwiązanie:**
```powershell
# Wygeneruj nowy klucz
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bielik-azure-key

# Użyj w deploymencie
.\scripts\deploy.ps1 -SshPublicKeyPath "~/.ssh/bielik-azure-key.pub"
```

---

## 🔌 Ollama nie działa

### Problem: Ollama nie odpowiada

**Diagnostyka:**
```bash
# Połącz się przez SSH
ssh azureuser@<IP>

# Sprawdź status
sudo systemctl status ollama

# Sprawdź czy proces działa
ps aux | grep ollama

# Sprawdź logi
sudo journalctl -u ollama -n 100
```

**Rozwiązanie 1: Restart usługi**
```bash
sudo systemctl restart ollama
sleep 5
sudo systemctl status ollama
```

**Rozwiązanie 2: Reinstalacja**
```bash
# Zatrzymaj usługę
sudo systemctl stop ollama

# Usuń Ollama
sudo rm -rf /usr/local/bin/ollama
sudo rm -rf /usr/share/ollama
sudo rm -rf ~/.ollama

# Reinstaluj
curl -fsSL https://ollama.com/install.sh | sh

# Restart
sudo systemctl restart ollama
```

### Problem: Ollama nasłuchuje tylko na localhost

**Objawy:**
```bash
curl http://localhost:11434/api/tags  # Działa
curl http://<PUBLIC_IP>:11434/api/tags  # Timeout
```

**Rozwiązanie:**
```bash
# Sprawdź konfigurację
sudo cat /etc/systemd/system/ollama.service.d/override.conf

# Powinno być:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"

# Jeśli nie ma, utwórz:
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

# Reload i restart
sudo systemctl daemon-reload
sudo systemctl restart ollama

# Sprawdź
sudo netstat -tlnp | grep 11434
```

---

## 📦 Model nie został pobrany

### Problem: Brak modelu na liście

**Diagnostyka:**
```bash
ollama list
# Output: NAME    ID    SIZE    MODIFIED
# (pusty)
```

**Rozwiązanie:**
```bash
# Ręcznie pobierz model
ollama pull SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M

# Sprawdź progress
ollama list

# Jeśli błąd podczas pobierania, sprawdź miejsce na dysku
df -h

# Sprawdź logi
sudo journalctl -u ollama -f
```

### Problem: Brak miejsca na dysku

**Objawy:**
```
Error: no space left on device
```

**Rozwiązanie:**
```bash
# Sprawdź użycie
df -h

# Zwiększ rozmiar dysku OS w Azure
az vm deallocate -g bielik-rg -n bielik-vm
az disk update -g bielik-rg -n bielik-vm-osdisk --size-gb 256
az vm start -g bielik-rg -n bielik-vm

# Na VM - rozszerz partycję
ssh azureuser@<IP>
sudo growpart /dev/sda 1
sudo resize2fs /dev/sda1
```

---

## 🌐 Problemy z siecią

### Problem: Nie można połączyć się przez SSH

**Diagnostyka:**
```powershell
# Sprawdź czy VM działa
az vm get-instance-view -g bielik-rg -n bielik-vm --query "instanceView.statuses"

# Sprawdź NSG rules
az network nsg rule list -g bielik-rg --nsg-name bielik-nsg --output table

# Test połączenia
Test-NetConnection -ComputerName <PUBLIC_IP> -Port 22
```

**Rozwiązanie:**
```powershell
# Otwórz port SSH (jeśli zamknięty)
az network nsg rule create `
    -g bielik-rg `
    --nsg-name bielik-nsg `
    -n SSH `
    --priority 1000 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --destination-port-ranges 22
```

### Problem: Timeout na porcie 11434

**Diagnostyka:**
```bash
# Test z lokalnego komputera
curl -v http://<PUBLIC_IP>:11434/api/tags

# Na VM - sprawdź czy port nasłuchuje
ssh azureuser@<IP>
sudo netstat -tlnp | grep 11434
# Powinno być: 0.0.0.0:11434
```

**Rozwiązanie 1: NSG**
```powershell
# Sprawdź regułę NSG dla Ollama
az network nsg rule show -g bielik-rg --nsg-name bielik-nsg -n Ollama-API

# Otwórz port (jeśli zamknięty)
az network nsg rule update `
    -g bielik-rg `
    --nsg-name bielik-nsg `
    -n Ollama-API `
    --access Allow
```

**Rozwiązanie 2: Ollama bind address**
Zobacz sekcję "Ollama nasłuchuje tylko na localhost" powyżej.

---

## 🐌 Model działa wolno

### Problem: Długi czas odpowiedzi

**Przyczyny i rozwiązania:**

1. **Za mały VM**
   ```powershell
   # Upgrade do większego VM
   az vm deallocate -g bielik-rg -n bielik-vm
   az vm resize -g bielik-rg -n bielik-vm --size Standard_D16s_v3
   az vm start -g bielik-rg -n bielik-vm
   ```

2. **Brak GPU**
   - Dla produkcji rozważ VM z GPU (NC-series)
   - Standard_NC6s_v3 lub Standard_NC4as_T4_v3

3. **Zbyt duży model dla VM**
   - Rozważ mniejszą kwantyzację (Q4_K_S zamiast Q4_K_M)
   - Lub mniejszy model (Bielik-7B zamiast 11B)

**Monitoring:**
```bash
# CPU i RAM
ssh azureuser@<IP> 'htop'

# Dla GPU
ssh azureuser@<IP> 'nvidia-smi -l 1'
```

---

## 🔐 Problemy z autoryzacją

### Problem: SSH key nie działa

**Rozwiązanie:**
```powershell
# Reset password dla VM (emergency access)
az vm user update `
    -g bielik-rg `
    -n bielik-vm `
    --username azureuser `
    --password '<NewPassword123!>'

# Połącz się i dodaj nowy SSH key
ssh azureuser@<IP>
# Wprowadź password
echo "<your-new-public-key>" >> ~/.ssh/authorized_keys
```

---

## 📊 Monitoring i logi

### Ważne logi

```bash
# Logi Ollama
sudo journalctl -u ollama -f

# Logi custom script extension
sudo cat /var/log/azure/custom-script/handler.log

# System logs
sudo journalctl -xe

# Ollama service config
sudo systemctl cat ollama
```

### Azure Portal

1. VM → Diagnostics settings
2. VM → Metrics (CPU, Network, Disk)
3. VM → Activity log (wszystkie operacje)
4. Resource Group → Deployments (deployment history)

---

## 🆘 Ostatnia deska ratunku

### Reset VM

```powershell
# Redeploy VM (zachowuje dane)
az vm redeploy -g bielik-rg -n bielik-vm
```

### Pełny reset

```powershell
# Usuń wszystko i wdróż od nowa
.\scripts\cleanup.ps1 -ResourceGroupName bielik-rg -Force
.\scripts\deploy.ps1 -Environment dev -ResourceGroupName bielik-rg
```

### Azure Support

Jeśli nic nie pomaga:
1. Azure Portal → Help + support
2. New support request
3. Wybierz: Technical > Virtual Machines

---

## 📞 Gdzie szukać pomocy

- **Ollama Issues**: https://github.com/ollama/ollama/issues
- **Bielik Model**: https://github.com/speakleash/Bielik-how-to-start
- **Azure Docs**: https://learn.microsoft.com/azure/virtual-machines/
