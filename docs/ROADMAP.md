# Roadmap

Plano baseado em `PROMPT_MASTER.md`, adaptado de Unity (C#) para Godot 4 (GDScript). Cada fase termina com algo que dá pra jogar no APK.

## Fase 2 – Base (prompts 8 a 11)
- [x] GameManager com máquina de estados (MainMenu, LobbySetup, LoadingWorld, InGame, Paused, PlayerDead)
- [x] Câmera híbrida 3ª/1ª pessoa com colisão (SpringArm3D) e tremor
- [x] Controles touch: joystick dinâmico, arrastar pra olhar, botões contextuais
- [x] Movimento com postura (em pé, agachado, correndo) e stamina

## Fase 3 – Mundo (prompts 12 a 15)
- [ ] Carregamento do mapa por chunks
- [x] Ciclo dia/noite (24h, duração configurável) e clima: ensolarado, nublado, chuva forte, tempestade com raios e neblina densa. Chuva abafa os passos, molha o jogador e neblina/noite reduzem a visão dos zumbis
- [ ] Interior/exterior
- [ ] Corte de água e energia

## Fase 4 – Menus e servidores (prompts 16 a 18)
- [x] Menu principal (versão inicial)
- [x] Menu de configurações (Gráficos, Controles, Áudio, Jogo) com presets Batata a Ultra, escala de resolução, limite de FPS, distância, sombras, MSAA, bloom e contador de FPS/RAM
  - SSAO e reflexos na água ficam indisponíveis/"em breve" (o renderizador Compatibility não tem SSAO)
- [ ] Criação de partida (single/co-op) com regras sandbox

## Fase 5 – Sobrevivência (prompts 19 a 22)
- [ ] Banco de itens
- [ ] Inventário por peso e loot procedural
- [ ] Saúde por partes do corpo e moodles
- [ ] Crafting

## Fase 6 – Zumbis e combate (prompts 23 a 25)
- [x] Zumbi simples (andar e perseguir) para testar
- [ ] IA com visão, audição e olfato
- [ ] Hordas
- [ ] Combate corpo a corpo e armas de fogo

## Fase 7 – Base, veículos e skills (prompts 26 a 28)
- [ ] Barricadas e construção
- [ ] Veículos
- [ ] Habilidades por prática

## Fase 8 – Multiplayer e acabamento (prompts 29 a 35)
- [ ] Rede, voz, save/load, áudio, eventos, otimização, anti-cheat
