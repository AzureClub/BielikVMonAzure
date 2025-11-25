"""
Przykłady użycia Bielik API w Python
"""

import requests
from typing import List, Dict, Optional


class BielikClient:
    """Klient do komunikacji z Bielik poprzez Ollama API"""
    
    def __init__(self, base_url: str = "http://localhost:11434"):
        self.base_url = base_url
        self.model = "SpeakLeash/bielik-11b-v2.2-instruct:Q4_K_M"
    
    def chat(
        self,
        message: str,
        system_prompt: Optional[str] = None,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        stream: bool = False
    ) -> Dict:
        """
        Wysyła zapytanie do modelu Bielik
        
        Args:
            message: Wiadomość użytkownika
            system_prompt: Opcjonalny prompt systemowy
            conversation_history: Historia konwersacji
            stream: Czy streamować odpowiedź
        
        Returns:
            Odpowiedź z API
        """
        messages = []
        
        # Dodaj system prompt jeśli podano
        if system_prompt:
            messages.append({
                "role": "system",
                "content": system_prompt
            })
        
        # Dodaj historię konwersacji jeśli podano
        if conversation_history:
            messages.extend(conversation_history)
        
        # Dodaj aktualną wiadomość
        messages.append({
            "role": "user",
            "content": message
        })
        
        payload = {
            "model": self.model,
            "stream": stream,
            "messages": messages
        }
        
        response = requests.post(
            f"{self.base_url}/api/chat",
            json=payload,
            timeout=300
        )
        response.raise_for_status()
        
        return response.json()
    
    def list_models(self) -> Dict:
        """Zwraca listę dostępnych modeli"""
        response = requests.get(f"{self.base_url}/api/tags")
        response.raise_for_status()
        return response.json()


def example_basic_chat():
    """Podstawowe zapytanie"""
    print("=== Przykład 1: Podstawowe zapytanie ===\n")
    
    client = BielikClient()
    response = client.chat("Kim jest Adam Mickiewicz?")
    
    print(f"Odpowiedź: {response['message']['content']}\n")


def example_with_system_prompt():
    """Zapytanie z system promptem"""
    print("=== Przykład 2: Z system promptem ===\n")
    
    client = BielikClient()
    response = client.chat(
        message="Jakie są najważniejsze dzieła Adama Mickiewicza?",
        system_prompt="Jesteś ekspertem od literatury polskiej. Odpowiadaj zwięźle i konkretnie."
    )
    
    print(f"Odpowiedź: {response['message']['content']}\n")


def example_conversation():
    """Konwersacja z historią"""
    print("=== Przykład 3: Konwersacja z historią ===\n")
    
    client = BielikClient()
    
    # Pierwsza wiadomość
    response1 = client.chat("Kim był Adam Mickiewicz?")
    print(f"User: Kim był Adam Mickiewicz?")
    print(f"Bielik: {response1['message']['content']}\n")
    
    # Druga wiadomość z historią
    history = [
        {"role": "user", "content": "Kim był Adam Mickiewicz?"},
        {"role": "assistant", "content": response1['message']['content']}
    ]
    
    response2 = client.chat(
        message="Kiedy się urodził?",
        conversation_history=history
    )
    print(f"User: Kiedy się urodził?")
    print(f"Bielik: {response2['message']['content']}\n")


def example_list_models():
    """Lista dostępnych modeli"""
    print("=== Przykład 4: Lista modeli ===\n")
    
    client = BielikClient()
    models = client.list_models()
    
    print("Dostępne modele:")
    for model in models.get('models', []):
        print(f"  - {model['name']}")
    print()


def example_streaming():
    """Streaming response"""
    print("=== Przykład 5: Streaming ===\n")
    
    client = BielikClient()
    
    print("User: Opowiedz krótko o historii Polski.")
    print("Bielik: ", end="", flush=True)
    
    # Dla streamingu potrzebujemy niestandardowego handlera
    messages = [
        {"role": "user", "content": "Opowiedz krótko o historii Polski."}
    ]
    
    payload = {
        "model": client.model,
        "stream": True,
        "messages": messages
    }
    
    response = requests.post(
        f"{client.base_url}/api/chat",
        json=payload,
        stream=True,
        timeout=300
    )
    
    for line in response.iter_lines():
        if line:
            import json
            data = json.loads(line)
            if 'message' in data and 'content' in data['message']:
                print(data['message']['content'], end="", flush=True)
    
    print("\n")


class ConversationManager:
    """Manager do zarządzania konwersacją z historią"""
    
    def __init__(self, base_url: str = "http://localhost:11434", system_prompt: Optional[str] = None):
        self.client = BielikClient(base_url)
        self.history: List[Dict[str, str]] = []
        
        if system_prompt:
            self.history.append({
                "role": "system",
                "content": system_prompt
            })
    
    def send_message(self, message: str) -> str:
        """Wysyła wiadomość i aktualizuje historię"""
        response = self.client.chat(
            message=message,
            conversation_history=self.history
        )
        
        # Aktualizuj historię
        self.history.append({
            "role": "user",
            "content": message
        })
        self.history.append({
            "role": "assistant",
            "content": response['message']['content']
        })
        
        return response['message']['content']
    
    def clear_history(self):
        """Czyści historię konwersacji"""
        # Zachowaj tylko system prompt jeśli istnieje
        system_prompts = [msg for msg in self.history if msg['role'] == 'system']
        self.history = system_prompts


def example_conversation_manager():
    """Przykład użycia ConversationManager"""
    print("=== Przykład 6: Conversation Manager ===\n")
    
    manager = ConversationManager(
        system_prompt="Jesteś pomocnym asystentem AI specjalizującym się w literaturze polskiej."
    )
    
    questions = [
        "Kim był Adam Mickiewicz?",
        "Jakie napisał najważniejsze dzieła?",
        "W którym roku powstał Pan Tadeusz?"
    ]
    
    for question in questions:
        print(f"User: {question}")
        answer = manager.send_message(question)
        print(f"Bielik: {answer}\n")


if __name__ == "__main__":
    print("=" * 60)
    print("Przykłady użycia Bielik API w Python")
    print("=" * 60)
    print()
    
    try:
        # Uruchom wszystkie przykłady
        example_basic_chat()
        example_with_system_prompt()
        example_conversation()
        example_list_models()
        example_streaming()
        example_conversation_manager()
        
        print("=" * 60)
        print("Wszystkie przykłady zakończone!")
        print("=" * 60)
        
    except requests.exceptions.ConnectionError:
        print("❌ Błąd: Nie można połączyć się z Ollama API.")
        print("Upewnij się, że Ollama działa na http://localhost:11434")
    except Exception as e:
        print(f"❌ Błąd: {e}")
