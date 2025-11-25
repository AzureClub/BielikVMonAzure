# Przykładowe zapytania do Bielik API

## Podstawowe zapytanie

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

## Z kontekstem systemowym

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M",
  "stream": false,
  "messages": [
    {
      "role": "system",
      "content": "Jesteś pomocnym asystentem AI, który odpowiada krótko i zwięźle."
    },
    {
      "role": "user",
      "content": "Jakie są najważniejsze dzieła Adama Mickiewicza?"
    }
  ]
}'
```

## Streaming response

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M",
  "stream": true,
  "messages": [
    {
      "role": "user",
      "content": "Opowiedz krótko o historii Polski."
    }
  ]
}'
```

## Konwersacja z historią

```bash
curl http://localhost:11434/api/chat -d '{
  "model": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M",
  "stream": false,
  "messages": [
    {
      "role": "user",
      "content": "Kim był Adam Mickiewicz?"
    },
    {
      "role": "assistant",
      "content": "Adam Mickiewicz był polskim poetą romantycznym, autorem między innymi Pana Tadeusza i Dziadów."
    },
    {
      "role": "user",
      "content": "Kiedy się urodził?"
    }
  ]
}'
```

## Python przykład

```python
import requests

url = "http://localhost:11434/api/chat"
payload = {
    "model": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M",
    "stream": False,
    "messages": [
        {
            "role": "user",
            "content": "Co to jest sztuczna inteligencja?"
        }
    ]
}

response = requests.post(url, json=payload)
print(response.json()['message']['content'])
```

## PowerShell przykład

```powershell
$uri = "http://localhost:11434/api/chat"
$body = @{
    model = "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M"
    stream = $false
    messages = @(
        @{
            role = "user"
            content = "Jakie są zastosowania AI w medycynie?"
        }
    )
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json"
$response.message.content
```

## Lista dostępnych modeli

```bash
curl http://localhost:11434/api/tags
```

## Informacje o modelu

```bash
curl http://localhost:11434/api/show -d '{
  "name": "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M"
}'
```
