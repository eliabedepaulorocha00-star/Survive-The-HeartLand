# Roadmap

Plano baseado em `PROMPT_MASTER.md`, adaptado de Unity (C#) para Godot 4 (GDScript). Cada fase termina com algo que dá pra jogar no APK.

## Fase 2 – Base (prompts 8 a 11)
- [x] GameManager com máquina de estados (MainMenu, LobbySetup, LoadingWorld, InGame, Paused, PlayerDead)
- [x] Câmera híbrida 3ª/1ª pessoa com colisão (SpringArm3D) e tremor
- [x] Controles touch: joystick dinâmico, arrastar pra olhar, botões contextuais
- [x] Movimento com postura (em pé, agachado, correndo) e stamina

## Fase 3 – Mundo (prompts 12 a 15)
- [x] Mapa 700x700 m por chunks de 100 m (só 3x3 carregados, montagem em etapas, estado de loot/zumbis guardado): cidade Millbrook com Rua Principal, posto, diner, farmácia, delegacia, ferragem, mercado, igreja, casas, caixa-d'água, fazendas com celeiro/silo, carros abandonados e matas
- [x] Ciclo dia/noite (24h, duração configurável) e clima: ensolarado, nublado, chuva forte, tempestade com raios e neblina densa. Chuva abafa os passos, molha o jogador e neblina/noite reduzem a visão dos zumbis
- [ ] Interior/exterior
- [ ] Corte de água e energia

## Fase 4 – Menus e servidores (prompts 16 a 18)
- [x] Menu principal (versão inicial)
- [x] Menu de configurações (Gráficos, Controles, Áudio, Jogo) com presets Batata a Ultra, escala de resolução, limite de FPS, distância, sombras, MSAA, bloom e contador de FPS/RAM
  - SSAO e reflexos na água ficam indisponíveis/"em breve" (o renderizador Compatibility não tem SSAO)
- [ ] Criação de partida (single/co-op) com regras sandbox

## Fase 5 – Sobrevivência (prompts 19 a 22)
- [x] Banco de itens (90 itens: armas brancas e de fogo, munição, comida, bebida, médicos, ferramentas, materiais, tecidos)
- [x] Inventário por peso (sobrecarga deixa lento), loot procedural por tipo de lugar, fome e sede
  - Falta: comida estragando com o tempo, tiro das armas de fogo (Fase 6)
- [x] Saúde por partes do corpo (arranhão, laceração, mordida, fratura, infecção, dor) e moodles
- [x] Crafting (bandagem, tala, cozinhar, ferver água); sem fogueira/estações ainda

## Fase 6 – Zumbis e combate (prompts 23 a 25)
- [x] Zumbi simples (andar e perseguir) para testar
- [x] IA com visão (cone + linha de visada), audição (barulho dos tiros/golpes/corrida) e olfato (sangramento)
- [x] Hordas dinâmicas atraídas por barulho alto (limite de 40 zumbis)
- [x] Combate corpo a corpo com arco, derrubada e pisão em zumbi caído
- [x] Armas de fogo: recarga, coice, dispersão, penetração, auto-mira leve, pânico
- [x] Animações: andar, correr, agachar, ataque, tiro, tropeço, engatinhar (zumbi sem pernas)
- [ ] Falta: ajustar equilíbrio no celular, sons, mais tipos de zumbi

## Fase 7 – Base, veículos e skills (prompts 26 a 28)
- [ ] Barricadas e construção
- [ ] Veículos
- [ ] Habilidades por prática

## Fase 8 – Multiplayer e acabamento (prompts 29 a 35)
- [ ] Rede, voz, save/load, áudio, eventos, otimização, anti-cheat

## Extra – Personagem
- [x] Boneco articulado com roupas do dia a dia (jogador e zumbis)
- [x] Customização: gênero, pele, cabelo, roupas; 9 profissões; 15 traços com sistema de pontos
- [ ] Habilidades por prática (Fase 7) usarão a profissão escolhida
- [x] Modelos low-poly de ~95 itens (armas, latas, garrafas, remédios, ferramentas) no chão e na mão — `scripts/world/item_models.gd`
- [ ] Trocar por modelos .glb (ex.: Kenney Survival Kit, CC0) quando houver arquivos em assets/items/
- [x] Armas com modelos .glb reais (assets/items): Colt M1917, S&W Victory, Winchester 1897, M1903A4, M1941 Johnson, M1917 Enfield, M3 Grease Gun, Reising M50, M42 (as 5 últimas novas no jogo)
