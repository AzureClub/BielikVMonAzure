# Contributing to Bielik Azure VM

Dziękujemy za zainteresowanie projektem! 🎉

## 🤝 Jak pomóc

### Zgłaszanie problemów (Issues)

1. Sprawdź czy problem już nie został zgłoszony
2. Użyj szablonu issue
3. Dołącz:
   - Opis problemu
   - Kroki do reprodukcji
   - Oczekiwane zachowanie
   - Aktualne zachowanie
   - Logi (jeśli możliwe)
   - Środowisko (Azure region, VM size, etc.)

### Pull Requests

1. **Fork** repozytorium
2. Stwórz **branch** dla swojej zmiany:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commituj** zmiany z opisowymi wiadomościami:
   ```bash
   git commit -m "Add: Support for custom Ollama port"
   ```
4. **Push** do swojego forka:
   ```bash
   git push origin feature/amazing-feature
   ```
5. Otwórz **Pull Request**

### Konwencje

#### Commit Messages
```
Type: Short description

Longer description if needed

Types:
- Add: Nowa funkcjonalność
- Fix: Poprawka błędu
- Update: Aktualizacja istniejącej funkcji
- Docs: Zmiany w dokumentacji
- Refactor: Refaktoryzacja kodu
- Test: Dodanie/zmiana testów
```

#### Code Style

**Bicep:**
- 2 spacje indent
- Lowercase dla nazw parametrów
- PascalCase dla nazw resources
- Komentarze w języku angielskim

**PowerShell:**
- PascalCase dla funkcji
- camelCase dla zmiennych
- Approved Verbs (Get-, Set-, New-, etc.)
- Comment-based help dla funkcji

**Bash:**
- snake_case dla funkcji
- UPPER_CASE dla stałych
- 2 spacje indent

### Obszary do pomocy

- 🐛 Fixing bugs
- 📝 Improving documentation
- ✨ Adding new features
- 🧪 Writing tests
- 🌍 Translations
- 💡 Suggesting improvements

### Pomysły na improvements

- [ ] Support dla innych modeli (Llama, Mistral)
- [ ] Monitoring i alerting (Azure Monitor)
- [ ] Auto-scaling configuration
- [ ] High availability setup
- [ ] Backup automation
- [ ] Container deployment option
- [ ] Terraform version
- [ ] GitHub Actions dla CI/CD

## 📜 Licencja

Przez contributing, zgadzasz się że Twoje zmiany będą licencjonowane pod MIT License.

## 🙏 Credits

Contributors będą dodani do README.md

## 📞 Kontakt

W razie pytań, otwórz Issue lub Discussion!
