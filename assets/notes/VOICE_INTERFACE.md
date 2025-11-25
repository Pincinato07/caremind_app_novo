# Interface de Voz (Voice-First) - CareMind

## 📋 Visão Geral

A interface de voz foi implementada para tornar o CareMind verdadeiramente **Voice-First**, permitindo que idosos e usuários com dificuldades motoras ou visuais interajam completamente com o aplicativo através de comandos de voz, sem necessidade de tocar na tela.

## 🎯 Funcionalidades Implementadas

### 1. **Speech-to-Text (STT)**
- Reconhecimento de voz em português brasileiro (pt-BR)
- Captura de comandos de voz do usuário
- Feedback visual durante o reconhecimento

### 2. **Text-to-Speech (TTS)**
- Leitura de respostas em voz alta
- Velocidade ajustada para idosos (0.5x)
- Pronúncia em português brasileiro

### 3. **Processamento de Comandos**
O sistema reconhece e processa os seguintes comandos:

#### Confirmação de Medicamentos
- "Já tomei o remédio"
- "Tomei o medicamento"
- "Confirma remédio"
- "Marquei como tomado"
- "Remédio tomado"

#### Confirmação de Rotinas
- "Já fiz a rotina"
- "Fiz a rotina"
- "Confirma rotina"
- "Rotina feita"
- "Rotina concluída"

#### Listagem
- "Quais remédios"
- "Lista medicamentos"
- "Meus remédios"
- "Quais rotinas"
- "Lista rotinas"

#### Ajuda
- "Ajuda"
- "O que posso fazer"
- "Comandos"
- "O que você faz"

## 🏗️ Arquitetura

### Serviços Criados

#### `VoiceService` (`lib/services/voice_service.dart`)
Serviço principal que gerencia:
- Inicialização de STT e TTS
- Solicitação de permissões de microfone
- Processamento de comandos de voz
- Integração com serviços de medicamentos e rotinas

**Principais métodos:**
- `initialize()`: Inicializa o serviço e solicita permissões
- `startListening()`: Inicia o reconhecimento de voz
- `stopListening()`: Para o reconhecimento
- `speak()`: Fala um texto usando TTS
- `processCommand()`: Processa um comando e executa a ação correspondente

#### `VoiceInterfaceWidget` (`lib/widgets/voice_interface_widget.dart`)
Widget de interface que fornece:
- Botão flutuante de microfone
- Feedback visual durante o reconhecimento
- Animações e vibrações para feedback multissensorial
- Exibição de mensagens de resposta

**Modos de uso:**
- **Floating Button**: Botão flutuante no canto da tela (padrão)
- **Inline Button**: Botão integrado na interface

## 📱 Integração nas Telas

A interface de voz foi integrada nas seguintes telas:

1. **Dashboard do Idoso** (`lib/screens/idoso/dashboard_screen.dart`)
   - Botão flutuante sempre visível
   - Acesso rápido a comandos de voz

2. **Dashboard Individual** (`lib/screens/individual/dashboard_screen.dart`)
   - Botão flutuante para interação por voz
   - Suporte completo a comandos

## 🔧 Configuração

### Dependências Adicionadas

```yaml
dependencies:
  speech_to_text: ^7.0.0  # Speech-to-Text
  flutter_tts: ^4.0.2     # Text-to-Speech (já existia)
  permission_handler: ^11.3.1  # Gerenciamento de permissões (já existia)
```

### Permissões Necessárias

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>O CareMind precisa acessar o microfone para reconhecer seus comandos de voz</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>O CareMind precisa usar o reconhecimento de voz para processar seus comandos</string>
```

## 🎨 Experiência do Usuário

### Fluxo de Uso

1. **Ativação**: Usuário toca no botão de microfone flutuante
2. **Feedback**: Botão anima e vibra levemente
3. **Reconhecimento**: Sistema captura o comando de voz
4. **Processamento**: Comando é processado e ação é executada
5. **Resposta**: Sistema fala a resposta em voz alta
6. **Feedback Visual**: Mensagem aparece na tela

### Feedback Multissensorial

- **Visual**: Animação do botão, mudança de cor, mensagens na tela
- **Tátil**: Vibrações em diferentes momentos (início, confirmação, sucesso)
- **Auditivo**: Respostas faladas em voz alta

## 🔍 Exemplos de Uso

### Exemplo 1: Confirmar Medicamento
```
Usuário: "Já tomei o remédio"
Sistema: "Entendido! Marquei o remédio [Nome] como tomado. Bom trabalho!"
```

### Exemplo 2: Listar Medicamentos
```
Usuário: "Quais remédios"
Sistema: "Você tem 3 remédio(s) cadastrado(s). 2 pendente(s): [Nomes]. 1 já tomado(s) hoje."
```

### Exemplo 3: Ajuda
```
Usuário: "Ajuda"
Sistema: "Você pode me pedir para: confirmar um remédio, confirmar uma rotina, listar seus remédios ou listar suas rotinas. O que deseja fazer?"
```

## 🚀 Próximos Passos (Melhorias Futuras)

1. **Comandos Avançados**
   - "Qual o próximo remédio?"
   - "Me lembre de tomar [nome do remédio]"
   - "Quantos remédios faltam?"

2. **Reconhecimento de Nomes**
   - Confirmar medicamento específico por nome
   - "Já tomei o [nome do remédio]"

3. **Integração com Alexa/Google Home**
   - Sincronização de comandos entre app e assistentes de voz

4. **Histórico de Comandos**
   - Lista de comandos recentes
   - Sugestões baseadas em uso

5. **Personalização**
   - Ajuste de velocidade de fala
   - Escolha de voz (masculina/feminina)
   - Atalhos personalizados

## 🐛 Troubleshooting

### Problema: Microfone não funciona
**Solução**: Verificar permissões nas configurações do dispositivo

### Problema: Comandos não são reconhecidos
**Solução**: 
- Falar claramente e próximo ao microfone
- Verificar se o ambiente está silencioso
- Tentar novamente com comando mais simples

### Problema: Respostas não são faladas
**Solução**: Verificar se o volume do dispositivo está ligado

## 📝 Notas Técnicas

- O serviço de voz é um singleton para garantir uma única instância
- As permissões são solicitadas automaticamente na primeira inicialização
- O reconhecimento de voz funciona offline (dependendo do dispositivo)
- O TTS requer conexão com internet na primeira inicialização (para download de vozes)

## ✅ Checklist de Implementação

- [x] Adicionar pacote `speech_to_text`
- [x] Criar `VoiceService` com STT e TTS
- [x] Implementar processamento de comandos
- [x] Criar `VoiceInterfaceWidget`
- [x] Integrar nas telas principais
- [x] Adicionar feedback multissensorial
- [x] Tratamento de erros e permissões
- [x] Documentação

## 🎉 Conclusão

A interface de voz está completamente implementada e funcional, transformando o CareMind em um aplicativo verdadeiramente **Voice-First**. Idosos e usuários com dificuldades motoras ou visuais agora podem interagir completamente com o aplicativo usando apenas a voz, sem necessidade de tocar na tela.

