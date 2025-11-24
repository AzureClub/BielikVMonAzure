# Polityka Bezpieczeństwa

## 🔒 Zgłaszanie Podatności

Jeśli odkryjesz lukę bezpieczeństwa w tym projekcie, prosimy o odpowiedzialne zgłoszenie:

### Preferowana Metoda
Utwórz **prywatne security advisory** na GitHubie:
1. Przejdź do zakładki **Security** w repozytorium
2. Kliknij **Advisories** → **New draft security advisory**
3. Wypełnij formularz z szczegółami podatności

### Alternatywna Metoda
Jeśli nie możesz użyć GitHub Security Advisory, utwórz **issue** z tagiem `security`, ale **NIE umieszczaj szczegółów exploitu publicznie**. Zamiast tego:
1. Utwórz issue z tytułem "Security Concern - Request for Private Communication"
2. Poczekaj na kontakt od maintainerów

## ⚠️ Czego NIE robić
- ❌ NIE publikuj exploitów publicznie przed uzyskaniem odpowiedzi
- ❌ NIE testuj podatności na produkcyjnych zasobach Azure innych osób
- ❌ NIE wykorzystuj znalezionych podatności w sposób szkodliwy

## 🛡️ Zakres Bezpieczeństwa

### W Zakresie
Ten projekt dotyczy infrastruktury Azure i może zawierać podatności związane z:
- **Konfiguracja Azure Bicep** - błędne ustawienia NSG, publiczne endpointy
- **Skrypty deployment** - potencjalne command injection, path traversal
- **Konfiguracja VM** - niezabezpieczone usługi, słabe hasła domyślne
- **Ollama API** - nieautoryzowany dostęp, wycieki danych
- **Przykłady kodu** - podatności w Python/PowerShell examples

### Poza Zakresem
- Podatności w systemach Azure (zgłoś do Microsoft Security Response Center)
- Podatności w Ollama (zgłoś do projektu Ollama)
- Podatności w modelu Bielik (zgłoś do SpeakLeash)
- Social engineering
- Fizyczny dostęp do infrastruktury

## 🔧 Praktyki Bezpieczeństwa

### Dla Użytkowników
1. **Hasła VM**: Używaj silnych haseł (12+ znaków, złożoność)
2. **SSH Keys**: Preferuj klucze SSH zamiast haseł
3. **NSG Rules**: Ogranicz dostęp do portów (22, 11434) tylko do zaufanych IP
4. **Ollama API**: Ustaw `enablePublicOllamaAccess: false` jeśli nie potrzebujesz publicznego dostępu
5. **Klucze prywatne**: NIGDY nie commituj kluczy SSH do repozytorium
6. **Parametry lokalne**: Używaj `*.parameters.local.json` dla swoich haseł (ignorowane przez .gitignore)

### Dla Developerów
1. **Code Review**: Wszystkie zmiany przechodzą przez review
2. **Secrets Scanning**: Używamy grep do skanowania przed commitami
3. **Dependencies**: Regularnie aktualizuj Bicep, Azure CLI, PowerShell
4. **Principle of Least Privilege**: NSG domyślnie blokuje Ollama API

## 📋 Znane Ograniczenia

### Bezpieczeństwo Modelu AI
- Model Bielik nie ma wbudowanej autentykacji
- Ollama API domyślnie nie wymaga autoryzacji
- **Mitigation**: Używaj NSG do kontroli dostępu do portu 11434

### Deployment Credentials
- Hasła VM mogą być przekazywane jako parametry
- **Mitigation**: Używamy PowerShell SecureString, bash prompt z `-s` flag
- **Best Practice**: Używaj SSH keys zamiast haseł

### Public IP Addresses
- VM otrzymuje statyczny publiczny IP z DNS
- **Mitigation**: NSG kontroluje dostęp, SSH tylko z trusted IPs

## 🕒 Czas Odpowiedzi

Staramy się odpowiadać na zgłoszenia bezpieczeństwa w następujących ramach czasowych:
- **Pierwsze potwierdzenie**: 48 godzin
- **Analiza i ocena**: 7 dni
- **Plan naprawy**: 14 dni (dla krytycznych), 30 dni (dla innych)
- **Publikacja patcha**: Zależy od złożoności, komunikujemy timeline

## 🏆 Hall of Fame

Osoby, które odpowiedzialnie zgłosiły podatności:
- *Lista będzie aktualizowana w miarę zgłoszeń*

## 📚 Dodatkowe Zasoby

- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Microsoft Security Response Center](https://msrc.microsoft.com/)
- [GitHub Security Advisories](https://docs.github.com/en/code-security/security-advisories)

---

**Dziękujemy za pomoc w utrzymaniu bezpieczeństwa tego projektu!** 🙏
