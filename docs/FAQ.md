# FAQ - Często Zadawane Pytania

## 🚀 Deployment

### Jak długo trwa deployment?

Pełny deployment zajmuje **15-20 minut**:
- Tworzenie infrastruktury: ~5 minut
- Instalacja Ollama: ~2 minuty
- Pobieranie modelu Bielik: ~10-15 minut (zależy od połączenia)

### Jakie uwierzytelnianie jest zalecane?

**Hasło** - prostsze, szybsze setup:
```powershell
.\scripts\deploy.ps1 -ResourceGroupName bielik-rg -AuthenticationType password
# Skrypt zapyta o hasło (min. 12 znaków, małe/wielkie, cyfry, specjalne)
```

**Klucz SSH** - bardziej bezpieczne dla produkcji:
```powershell
.\scripts\deploy.ps1 -ResourceGroupName bielik-rg -AuthenticationType sshPublicKey
```

### Czy mogę użyć istniejącego Resource Group?

Tak! Skrypt sprawdza czy RG istnieje i używa go zamiast tworzyć nowy:
```powershell
.\scripts\deploy.ps1 -ResourceGroupName existing-rg-name
```

### Jak zmienić region Azure?

```powershell
.\scripts\deploy.ps1 -Location northeurope
```

Dostępne regiony: westeurope, northeurope, eastus, westus2, etc.

### Czy potrzebuję GPU?

**Nie jest wymagane.** Model działa na CPU:
- **CPU (Standard_D8s_v3)**: Wystarczające dla większości użyć, wolniejsze
- **GPU Tesla V100 (Standard_NC6s_v3)**: Szybsze inferencje (~3-5x)
- **GPU NVIDIA A100 (Standard_NC24ads_A100_v4)**: Najszybsze (~10-15x CPU), najlepsze dla produkcji

Zacznij od CPU i upgrade jeśli potrzebujesz.

---

## 💰 Koszty

### Ile to kosztuje miesięcznie?

Zależy od użycia:
- **Development** (8h/dzień): ~$85/miesiąc
- **Production 24/7 CPU**: ~$310/miesiąc
- **Production 24/7 GPU V100**: ~$2,267/miesiąc
- **Production 24/7 GPU A100**: ~$2,714/miesiąc (najszybszy!)

Szczegóły: [docs/COSTS.md](docs/COSTS.md)

### Jak przestać płacić gdy nie używam?

```powershell
# Wyłącz VM (przestajesz płacić za compute)
az vm deallocate -g bielik-rg -n bielik-vm

# Włącz ponownie
az vm start -g bielik-rg -n bielik-vm
```

Nadal płacisz za storage (~$23/m), ale oszczędzasz na VM.

### Czy są darmowe opcje?

- **Azure Free Account**: $200 credit na 30 dni
- **Student Account**: $100/rok
- **Microsoft for Startups**: Do $150K w credits

---

## 🔐 Bezpieczeństwo

### Czy moje dane są bezpieczne?

Tak! Model działa **lokalnie na Twojej VM**:
- Dane nie opuszczają Twojego Azure subscription
- Pełna kontrola nad dostępem
- Możliwość szyfrowania dysków

### Jak zabezpieczyć API przed publicnym dostępem?

Domyślnie port 11434 jest **zamknięty** publicznie. Możesz:

1. **VPN/Bastion** - Połącz się przez VPN do VNet
2. **NSG whitelist** - Ogranicz do Twoich IP:
```powershell
az network nsg rule update `
    -g bielik-rg `
    --nsg-name bielik-nsg `
    -n Ollama-API `
    --source-address-prefixes "YOUR.IP.ADD.RESS"
```

3. **Reverse proxy** - Nginx z authentication

### Czy mogę włączyć szyfrowanie dysku?

Tak, ale wymaga modyfikacji Bicep:
```bicep
osDisk: {
  encryptionSettings: {
    enabled: true
  }
}
```

---

## 🛠️ Konfiguracja

### Jak zmienić rozmiar VM po deploymencie?

```powershell
az vm deallocate -g bielik-rg -n bielik-vm
az vm resize -g bielik-rg -n bielik-vm --size Standard_NC24ads_A100_v4  # lub inny rozmiar
az vm start -g bielik-rg -n bielik-vm
```

**Dostępne rozmiary**: Standard_D8s_v3, Standard_D16s_v3, Standard_NC6s_v3, Standard_NC24ads_A100_v4, Standard_NC48ads_A100_v4, itd.

### Jak zmienić model Bielik?

Na VM:
```bash
ssh azureuser@<IP>

# Usuń stary model
ollama rm SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M

# Pobierz inny
ollama pull SpeakLeash/bielik-7b-instruct-v0.1

# Sprawdź
ollama list
```

### Jak dodać więcej miejsca na dysku?

```powershell
# Zwiększ rozmiar dysku
az disk update -g bielik-rg -n bielik-vm-osdisk --size-gb 256

# Na VM rozszerz partycję
ssh azureuser@<IP>
sudo growpart /dev/sda 1
sudo resize2fs /dev/sda1
df -h
```

### Czy mogę mieć multiple modele?

Tak!
```bash
ollama pull llama2
ollama pull mistral
ollama list
```

Wszystkie będą dostępne przez to samo API.

---

## 🔧 Troubleshooting

### Model nie odpowiada / timeout

**Check:**
1. Czy VM ma wystarczająco RAM?
2. Czy model został pobrany? `ollama list`
3. Czy Ollama działa? `sudo systemctl status ollama`

**Fix:**
```bash
# Restart Ollama
sudo systemctl restart ollama

# Sprawdź logi
sudo journalctl -u ollama -f
```

### "No space left on device"

**Fix:**
Zobacz "Jak dodać więcej miejsca na dysku" powyżej.

### Nie mogę się połączyć przez SSH

**Check:**
1. Czy VM działa? `az vm get-instance-view ...`
2. Czy port 22 jest otwarty? `az network nsg rule list...`
3. Czy używasz właściwego klucza SSH?

**Fix:**
```powershell
# Reset SSH
az vm user reset-ssh -g bielik-rg -n bielik-vm
```

### API zwraca 404

**Możliwe przyczyny:**
1. Ollama nie nasłuchuje na 0.0.0.0
2. NSG blokuje port 11434
3. Model nie został pobrany

**Diagnostyka:**
```bash
ssh azureuser@<IP>

# Sprawdź czy nasłuchuje
sudo netstat -tlnp | grep 11434
# Powinno być: 0.0.0.0:11434

# Sprawdź modele
ollama list
```

Więcej: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 🌐 Networking

### Jak ustawić własną domenę?

1. Kup domenę (np. GoDaddy, Namecheap)
2. Dodaj A record wskazujący na Public IP VM
3. (Opcjonalnie) Zainstaluj Nginx z SSL:

```bash
sudo apt install nginx certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

### Czy mogę użyć prywatnego IP tylko?

Tak, usuń Public IP z Bicep i używaj:
- Azure Bastion do SSH
- VPN Gateway do dostępu API
- Private Endpoint

### Jak dodać Load Balancer?

Wymaga modyfikacji Bicep - przykład w [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#high-availability-options)

---

## 🔄 Integracja

### Jak używać z Python?

Zobacz [examples/python-client.py](examples/python-client.py)

```python
import requests

response = requests.post(
    "http://<VM_IP>:11434/api/chat",
    json={
        "model": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M",
        "messages": [{"role": "user", "content": "Cześć!"}]
    }
)
print(response.json()['message']['content'])
```

### Jak używać z Node.js?

```javascript
const axios = require('axios');

const response = await axios.post('http://<VM_IP>:11434/api/chat', {
  model: 'SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M',
  messages: [{role: 'user', content: 'Cześć!'}]
});

console.log(response.data.message.content);
```

### Czy mogę użyć Langchain?

Tak! Ollama jest wspierane przez Langchain:

```python
from langchain.llms import Ollama

llm = Ollama(
    base_url="http://<VM_IP>:11434",
    model="SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M"
)

response = llm("Kim jest Adam Mickiewicz?")
print(response)
```

---

## 📊 Performance

### Jak szybko działa Bielik?

**Standard_D8s_v3 (CPU):**
- Tokens/s: ~5-15 tokens/s
- Response time: 5-15 sekund dla krótkiej odpowiedzi

**Standard_NC6s_v3 (GPU):**
- Tokens/s: ~50-100 tokens/s
- Response time: 1-3 sekundy

### Jak zwiększyć performance?

1. **Większy VM** - więcej vCPU/RAM
2. **GPU VM** - NC-series
3. **Mniejsza kwantyzacja** - Q2_K zamiast Q4_K_M (gorsza jakość)
4. **Batch requests** - wysyłaj multiple queries razem

### Ile równoczesnych użytkowników obsłuży?

**Standard_D8s_v3:**
- ~5-10 równoczesnych requests
- Więcej przy krótkich queries

**Standard_NC6s_v3:**
- ~20-50 równoczesnych requests

Dla większych obciążeń: multiple VMs + Load Balancer

---

## 🔄 Updates

### Jak zaktualizować Ollama?

```bash
ssh azureuser@<IP>
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl restart ollama
```

### Jak zaktualizować model Bielik?

```bash
ollama pull SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M
# Jeśli jest nowa wersja, zostanie pobrana
```

### Jak zaktualizować system?

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

---

## 📱 Monitoring

### Jak monitorować użycie?

**Azure Portal:**
- VM → Metrics (CPU, RAM, Network)
- VM → Insights (jeśli włączone)

**Na VM:**
```bash
# CPU/RAM real-time
htop

# GPU (jeśli jest)
nvidia-smi -l 1

# Ollama logs
sudo journalctl -u ollama -f
```

### Jak ustawić alerty?

Azure Portal:
1. VM → Alerts
2. New alert rule
3. Add condition (np. CPU > 80%)
4. Add action group (email, SMS, webhook)

---

## 🎓 Learning Resources

### Gdzie nauczyć się więcej o Bielik?

- [Bielik Model Card](https://huggingface.co/speakleash/Bielik-11B-v2.2-Instruct-GGUF)
- [SpeakLeash GitHub](https://github.com/speakleash/Bielik-how-to-start)
- [Polski AI Research](https://speakleash.org/)

### Gdzie nauczyć się więcej o Ollama?

- [Ollama Documentation](https://github.com/ollama/ollama)
- [Ollama API Docs](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Ollama Discord](https://discord.gg/ollama)

### Gdzie nauczyć się więcej o Azure?

- [Azure Docs](https://learn.microsoft.com/azure/)
- [Azure Bicep Docs](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Microsoft Learn (darmowe kursy)](https://learn.microsoft.com/)

---

## ❓ Inne pytania?

Nie znalazłeś odpowiedzi?

1. Sprawdź [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. Przeczytaj [README.md](README.md)
3. Otwórz Issue na GitHub
4. Sprawdź [Ollama Issues](https://github.com/ollama/ollama/issues)
