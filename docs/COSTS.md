# Koszty Azure - Szacowanie i optymalizacja

Przewodnik po kosztach uruchamiania Bielik na Azure VM.

## 💰 Szacowane koszty miesięczne

Wszystkie ceny w USD dla regionu West Europe (stan na 2024).

### VM - CPU Only

| Rozmiar VM | vCPU | RAM | Cena/h | Cena/miesiąc (730h) | Zalecenia |
|------------|------|-----|--------|---------------------|-----------|
| Standard_D4s_v3 | 4 | 16 GB | $0.192 | ~$140 | Minimum, wolne |
| **Standard_D8s_v3** | 8 | 32 GB | $0.384 | ~$280 | ⭐ Zalecane |
| Standard_D16s_v3 | 16 | 64 GB | $0.768 | ~$560 | Dla dużych obciążeń |

### VM - z GPU

| Rozmiar VM | vCPU | RAM | GPU | Cena/h | Cena/miesiąc | Zalecenia |
|------------|------|-----|-----|--------|--------------|-----------||
| Standard_NC4as_T4_v3 | 4 | 28 GB | Tesla T4 16GB | ~$0.526 | ~$384 | Budżetowy GPU |
| **Standard_NC6s_v3** | 6 | 112 GB | Tesla V100 16GB | ~$3.06 | ~$2,234 | Produkcyjny (starszy) |
| Standard_NC8as_T4_v3 | 8 | 56 GB | Tesla T4 16GB | ~$0.752 | ~$549 | Średni GPU |
| **Standard_NC24ads_A100_v4** | 24 | 220 GB | **NVIDIA A100 80GB** | ~$3.673 | ~$2,681 | ⭐ **Najlepszy dla LLM** |
| Standard_NC48ads_A100_v4 | 48 | 440 GB | NVIDIA A100 80GB | ~$7.346 | ~$5,363 | Duże modele |
| Standard_NC96ads_A100_v4 | 96 | 880 GB | NVIDIA A100 80GB | ~$14.692 | ~$10,725 | Enterprise |

### Dodatkowe koszty

| Zasób | Typ | Rozmiar | Cena/miesiąc |
|-------|-----|---------|--------------|
| OS Disk | Premium SSD | 128 GB | ~$20 |
| Public IP | Static | - | ~$3 |
| Bandwidth | Outbound | Pierwsze 100GB free | $0.087/GB po 100GB |

### Przykładowe scenariusze

#### 💼 Development (8h/dzień, 20 dni/m)
```
VM: Standard_D8s_v3
Godziny: 160h/miesiąc
Koszt: $0.384 × 160 = $61.44
+ Storage: $20
+ IP: $3
─────────────
TOTAL: ~$85/miesiąc
```

#### 🏭 Production 24/7 (CPU)
```
VM: Standard_D8s_v3
Godziny: 730h/miesiąc
Koszt: $0.384 × 730 = $280.32
+ Storage: $20
+ IP: $3
+ Bandwidth: ~$10
─────────────
TOTAL: ~$313/miesiąc
```

#### 🚀 Production 24/7 (GPU V100)
```
VM: Standard_NC6s_v3
Godziny: 730h/miesiąc
Koszt: $3.06 × 730 = $2,233.80
+ Storage: $20
+ IP: $3
+ Bandwidth: ~$10
─────────────
TOTAL: ~$2,267/miesiąc
```

#### 🔥 Production 24/7 (GPU A100)
```
VM: Standard_NC24ads_A100_v4
Godziny: 730h/miesiąc
Koszt: $3.673 × 730 = $2,681.29
+ Storage: $20
+ IP: $3
+ Bandwidth: ~$10
─────────────
TOTAL: ~$2,714/miesiąc

💡 Wydajność: ~3-5x szybsze niż V100!
```

## 💡 Oszczędzanie kosztów

### 1. Deallocate VM gdy nie jest używany

```powershell
# Wyłącz VM (przestajesz płacić za compute)
az vm deallocate -g bielik-rg -n bielik-vm

# Włącz ponownie
az vm start -g bielik-rg -n bielik-vm
```

**Oszczędności**: Do 100% kosztów compute podczas wyłączenia!

### 2. Auto-shutdown

Ustaw automatyczne wyłączanie VM:

```powershell
# Ustaw auto-shutdown na 18:00 (UTC)
az vm auto-shutdown `
    -g bielik-rg `
    -n bielik-vm `
    --time 1800
```

Lub w Portal:
- VM → Operations → Auto-shutdown
- Ustaw godzinę i timezone

### 3. Reserved Instances (1 lub 3 lata)

Dla 24/7 production:
- 1 rok: ~30% taniej
- 3 lata: ~50% taniej

```powershell
# Sprawdź dostępne Reserved Instances
az reservations reservation-order list
```

Portal: Cost Management + Billing → Reservations

### 4. Spot Instances

Dla nieprzerwanych obciążeń:
- Nawet do 90% taniej
- Azure może odebrać VM gdy potrzebuje pojemności

```bicep
// W Bicep dodaj:
priority: 'Spot'
evictionPolicy: 'Deallocate'
billingProfile: {
  maxPrice: -1  // Pay up to on-demand price
}
```

⚠️ **Uwaga**: Nie zalecane dla produkcji

### 5. Mniejsza kwantyzacja modelu

| Model | Rozmiar | RAM needed | VM Zalecany |
|-------|---------|------------|-------------|
| Q2_K | ~4 GB | 8 GB | Standard_D4s_v3 ($140/m) |
| Q4_K_M | ~6.5 GB | 16 GB | Standard_D8s_v3 ($280/m) |
| Q5_K_M | ~8 GB | 20 GB | Standard_D8s_v3 ($280/m) |
| Q8_0 | ~12 GB | 24 GB | Standard_D16s_v3 ($560/m) |

**Oszczędności**: Do 50% przez użycie mniejszego VM

### 6. Storage optimization

```powershell
# Zmień na Standard HDD (wolniejsze, tańsze)
az disk update `
    -g bielik-rg `
    -n bielik-vm-osdisk `
    --sku Standard_LRS
```

**Oszczędności**: ~$10/miesiąc

### 7. Używaj Azure Cost Management

```powershell
# Sprawdź aktualne koszty
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31
```

Portal: Cost Management + Billing
- Ustaw budżety i alerty
- Analizuj trendy kosztów

## 📊 Kalkulatory kosztów

### Azure Pricing Calculator
https://azure.microsoft.com/pricing/calculator/

### Przykładowa konfiguracja do wklejenia:
```
Region: West Europe
VM: Standard_D8s_v3
OS: Linux
Hours: 730/month
Managed Disks: 128GB Premium SSD
```

## 🎯 Scenariusze użycia i koszty

### Hobby / Nauka
```
VM: Standard_D4s_v3
Użycie: 50h/miesiąc (deallocate reszta czasu)
Koszt: ~$30/miesiąc
```

### Startup / MVP
```
VM: Standard_D8s_v3
Użycie: 200h/miesiąc (pracujesz 8h/dzień)
Koszt: ~$100/miesiąc
```

### Small Business 24/7
```
VM: Standard_D8s_v3
Użycie: 730h/miesiąc (zawsze włączone)
Koszt: ~$310/miesiąc
```

### Enterprise Production
```
VM: Standard_NC6s_v3 (GPU)
Użycie: 730h/miesiąc
Reserved Instance: 1 rok
Koszt: ~$1,500/miesiąc (z RI discount)
```

## ⚠️ Ukryte koszty

### Bandwidth
- **Inbound**: Zawsze darmowy
- **Outbound**: Pierwsze 100GB/m darmowe, potem $0.087/GB
- Wewnątrz regionu: Darmowy (VNet to VNet)

### Backup
Jeśli włączysz Azure Backup:
- ~$10-30/miesiąc zależnie od rozmiaru dysku

### Load Balancer / Application Gateway
Jeśli dodasz:
- Basic Load Balancer: ~$18/miesiąc
- Standard Load Balancer: ~$25/miesiąc + data processing

## 📉 Monitoring kosztów

### Ustaw alerty budżetu

```powershell
# Przez Azure Portal
# Cost Management + Billing → Budgets → Add

# Przykład: Alert at $200/month
```

### Tagi dla Cost Tracking

Używaj tagów z deployment:
```json
{
  "tags": {
    "Environment": "Production",
    "CostCenter": "AI-Research",
    "Project": "Bielik",
    "Owner": "team@company.com"
  }
}
```

Potem filtruj koszty po tagach w Cost Management.

## 🔄 Przykładowy miesięczny rachunek

### Development Team (5 devs, każdy 8h/day)
```
5× Standard_D8s_v3 @ 160h/m each
= 5 × $61.44 = $307.20

Storage (5× $20) = $100
Public IPs (5× $3) = $15
─────────────────────────
TOTAL: ~$422/month
```

### Production Service (24/7 z HA)
```
2× Standard_D8s_v3 @ 730h/m (HA)
= 2 × $280.32 = $560.64

1× Load Balancer = $25
Storage = $40
Bandwidth = $20
─────────────────────────
TOTAL: ~$645/month
```

## 💰 ROI Analysis

### vs OpenAI API
```
Bielik własny:
$280/m (VM) + $20 (storage) = $300/m unlimited queries

OpenAI GPT-3.5:
$0.002 per 1K tokens
150K queries/month × 1K tokens avg = $300
```

**Break-even**: ~150K zapytań/miesiąc

### vs Managed AI Services
```
Azure OpenAI Service:
$0.002 per 1K tokens + hosting

Own Bielik VM:
Fixed $300/m unlimited
```

**Zalety własnego**:
- Pełna kontrola
- Prywatność danych
- Customization
- Brak limitów rate

## 🎓 Free Tier / Credits

### Azure Free Account
- $200 credit na 30 dni
- Wystarczy na ~3 tygodnie testów (Standard_D8s_v3)

### Student Account
- $100/rok przez GitHub Student Developer Pack
- Lub Azure for Students: $100 credit

### Startup Programs
- Microsoft for Startups: Do $150K w Azure credits

## 📝 Podsumowanie

| Use Case | Zalecany VM | Koszt/m | Najlepsze dla |
|----------|-------------|---------|---------------|
| Nauka/Testy | D4s_v3 + deallocate | $30-50 | Eksperymenty |
| Development | D8s_v3 + auto-shutdown | $85-150 | Zespoły deweloperskie |
| Production CPU | D8s_v3 24/7 + RI | $200-280 | Małe/średnie obciążenia |
| Production GPU | NC6s_v3 + RI | $1,500+ | Wysokie obciążenia |

---

**Tip**: Zawsze zacznij od najmniejszego VM i skaluj w górę przy potrzebie!

**Reminder**: Wyłączaj VM gdy nie używasz! 🔌💰
