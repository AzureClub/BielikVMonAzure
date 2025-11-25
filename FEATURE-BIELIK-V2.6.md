# Feature Branch: Bielik v2.6 z HuggingFace

## 🎯 Cel

Implementacja modelu **Bielik 11B v2.6** z HuggingFace, który nie jest jeszcze dostępny w bibliotece Ollama.

## 📋 Zmiany

### 1. Metoda instalacji modelu
**Przed (main branch - v2.3):**
```bash
ollama pull SpeakLeash/bielik-11b-v2.3-instruct:Q4_K_M
```

**Teraz (feature branch - v2.6):**
```bash
# Pobierz plik GGUF z HuggingFace
wget https://huggingface.co/speakleash/Bielik-11B-v2.6-Instruct-GGUF/resolve/main/Bielik-11B-v2.6-Instruct.Q4_K_M.gguf

# Utwórz Modelfile z szablonem ChatML
ollama create SpeakLeash/bielik-11b-v2.6-instruct:Q4_K_M -f Modelfile
```

### 2. Modelfile Template
Model v2.6 używa formatu ChatML z tokenami:
- `<|im_start|>` - początek wiadomości
- `<|im_end|>` - koniec wiadomości

```modelfile
FROM /tmp/bielik-v2.6-q4km.gguf

TEMPLATE """<|im_start|>system
{{ .System }}<|im_end|>
<|im_start|>user
{{ .Prompt }}<|im_end|>
<|im_start|>assistant
"""

PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
PARAMETER temperature 0.6
PARAMETER top_p 0.9
```

### 3. Zmodyfikowane pliki

**scripts/deploy.ps1**
- Zmieniono domyślny model z v2.3 na v2.6

**scripts/install-ollama-bielik.sh**
- Dodano pobieranie GGUF z HuggingFace (6.72GB)
- Dodano tworzenie Modelfile z szablonem ChatML
- Zastąpiono `ollama pull` przez `ollama create`
- Zaktualizowano dokumentację w `bielik-info.txt`

## 🔬 Dlaczego osobny branch?

1. **Stabilność main branch**: Wersja v2.3 działa z prostym `ollama pull`
2. **Testowanie v2.6**: Nowa metoda instalacji wymaga walidacji
3. **Różne metody instalacji**: GGUF vs biblioteka Ollama
4. **Większy plik**: v2.6 wymaga pobrania 6.72GB bezpośrednio z HuggingFace

## 📦 Dane techniczne

### Model v2.6
- **Źródło**: https://huggingface.co/speakleash/Bielik-11B-v2.6-Instruct-GGUF
- **Rozmiar**: 6.72GB (Q4_K_M quantization)
- **Format**: GGUF (dla llama.cpp/Ollama)
- **Pobrane**: 890 razy (według HuggingFace)

### Dostępne kwantyzacje
- `Q4_K_M` - 6.72GB (domyślna)
- `Q5_K_M` - 7.91GB
- `Q6_K` - 9.16GB
- `Q8_0` - 11.9GB

## 🚀 Testowanie

### Deployment
```powershell
# Przełącz się na feature branch
git checkout feature/bielik-v2.6

# Deploy z v2.6
$pwd = ConvertTo-SecureString "TwojeHaslo123!" -AsPlainText -Force
.\scripts\deploy.ps1 -Environment test `
    -ResourceGroupName bielik-v26-test-rg `
    -VmSize Standard_NC24ads_A100_v4 `
    -Location polandcentral `
    -AdminPassword $pwd `
    -EnablePublicOllamaAccess $true
```

### Weryfikacja na VM
```bash
# SSH do maszyny
ssh azureuser@<PUBLIC_IP>

# Sprawdź zainstalowane modele
ollama list
# Powinno pokazać: SpeakLeash/bielik-11b-v2.6-instruct:Q4_K_M

# Test modelu
ollama run SpeakLeash/bielik-11b-v2.6-instruct:Q4_K_M "Kim był Adam Mickiewicz?"

# Sprawdź plik GGUF
ls -lh /tmp/bielik-v2.6-q4km.gguf
```

### Test API
```bash
curl http://<PUBLIC_IP>:11434/api/chat -d '{
  "model": "SpeakLeash/bielik-11b-v2.6-instruct:Q4_K_M",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": "Napisz wiersz o Azure w stylu Mickiewicza"
    }
  ]
}'
```

## ⚠️ Znane ograniczenia

1. **Czas pobierania**: Plik GGUF (6.72GB) pobiera się ~10-15 minut
2. **Miejsce na dysku**: Wymaga dodatkowych 7GB w `/tmp`
3. **Brak aktualizacji**: Model nie będzie automatycznie aktualizowany przez Ollama
4. **HuggingFace zależność**: Wymaga dostępu do huggingface.co podczas deploymentu

## 🔄 Plan dalszych działań

### Opcja A: Merge do main (jeśli testy przejdą)
```bash
git checkout main
git merge feature/bielik-v2.6
git push origin main
```

### Opcja B: Utrzymanie obu wersji
- **main**: v2.3 (stabilna, prosta instalacja)
- **feature/bielik-v2.6**: v2.6 (najnowsza, wymaga GGUF)
- Parametr w `deploy.ps1` do wyboru wersji

### Opcja C: Czekanie na Ollama library
- Monitorowanie https://ollama.com/speakleash
- Gdy v2.6 pojawi się w bibliotece, powrót do prostego `ollama pull`

## 📊 Porównanie wydajności

| Metryka | v2.3 (main) | v2.6 (feature) | Uwagi |
|---------|-------------|----------------|-------|
| Rozmiar | ~6.5GB | 6.72GB | Q4_K_M quantization |
| Instalacja | `ollama pull` | wget + create | v2.6 dłuższa |
| Czas pobierania | ~8-10 min | ~10-15 min | Zależy od połączenia |
| Aktualizacje | Automatyczne | Manualne | Ollama vs HuggingFace |
| Jakość odpowiedzi | ? | ? | Wymaga testów |

## 🔗 Linki

- **HuggingFace Model**: https://huggingface.co/speakleash/Bielik-11B-v2.6-Instruct-GGUF
- **Ollama Library**: https://ollama.com/speakleash (brak v2.6)
- **GitHub Branch**: https://github.com/AzureClub/BielikVMonAzure/tree/feature/bielik-v2.6
- **Pull Request**: https://github.com/AzureClub/BielikVMonAzure/pull/new/feature/bielik-v2.6

## 👥 Feedback

Jeśli testujesz ten branch:
1. Deploy VM z v2.6
2. Przetestuj jakość odpowiedzi vs v2.3
3. Sprawdź logi instalacji
4. Zgłoś feedback w PR lub issue

---

**Branch utworzony**: 2025-01-XX  
**Ostatni commit**: bc6782a  
**Status**: 🧪 Eksperymentalny - wymaga testów
