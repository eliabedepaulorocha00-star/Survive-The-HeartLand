# Master Document: Projeto Zumbi 3D Mobile (Mundo Aberto)

Este documento contém a especificação técnica completa e a sequência contínua de 35 prompts avançados para criar um jogo de sobrevivência zumbi 3D em mundo aberto para mobile (Android/iOS). 

---

## 🎨 Visão Geral & Direção de Arte
* **Estilo Gráfico:** *Hand-painted Stylized Realism* / Low-Poly Estilizado com texturas pintadas à mão (estilo *Project Zomboid* evoluído para 3D livre semi-realista).
* **Câmera:** Híbrida (Terceira Pessoa Over-the-Shoulder e Primeira Pessoa FPS).
* **Ambientação:** Subúrbio e interior rural dos Estados Unidos (Kentucky/Indiana).
* **Plataforma:** Mobile (Android/iOS) via Unity (URP) ou Unreal Engine 5 (Mobile Pipeline).

---

## FASE 1: Prompts de Imagem / Arte Conceitual (Midjourney / Flux / Leonardo.ai)

### Prompt 01: Protagonista Sobrevivente
> `3D character concept art sheet, front, side, and back views (T-pose), a gritty male survivor in his 30s in a US zombie apocalypse, wearing a worn flannel shirt over a stained t-shirt, faded jeans, dusty hiking boots, and a tactical hiking backpack. Art style inspired by Project Zomboid's gritty atmosphere translated into modern stylized 3D graphics (similar to State of Decay 2 meets Long Dark), subtle hand-painted textures, low-poly mobile game ready topology, neutral studio gray background, soft ambient occlusion, 4k resolution, clean character modeling reference --ar 16:9`

### Prompt 02: Horda de Zumbis Americanos
> `3D character lineup concept art of 4 different zombies in a rural American apocalypse, stylized semi-realistic 3D graphics with hand-painted textures, slightly enhanced Project Zomboid aesthetic in full 3D. Left to right: a decayed police officer in torn uniform, a bloody nurse in scrubs, a redneck in overalls, and a rotting suburban citizen. Pale bluish-gray skin, glowing sunken eyes, tattered clothes with dirt and dried blood, mobile game optimized mesh style, plain light gray background, studio lighting --ar 16:9`

### Prompt 03: Arquitetura Residencial Suburbana
> `3D environment asset sheet of an abandoned American suburban wooden two-story house in Kentucky, overgrown weeds, boarded-up windows with wooden planks, peeling white paint, rusted mailbox, porch with broken rocking chair. Stylized 3D game art with rich hand-painted textures and realistic lighting, mobile game aesthetic, isometric-free perspective at eye level, isolated on a clean neutral background for 3D modeling reference --ar 16:9`

### Prompt 04: Posto de Gasolina e Diner Retro
> `3D game environment concept of a classic 1990s rural American gas station and diner ("Spiffo's" style retro aesthetic), rusted fuel pumps, flickering broken neon sign, shattered glass storefront, abandoned rusted pickup truck outside. Stylized semi-realistic 3D graphics, crisp hand-painted textures, warm sunset apocalypse lighting, mobile game asset reference, Unreal Engine 5 mobile render style --ar 16:9`

### Prompt 05: Assets de Itens e Armas
> `3D game prop sheet showing survival items arranged neatly on a dark wooden table: a rusty fire axe, a nailed baseball bat, a 9mm pistol, canned beans, a bottle of bleach, a first aid kit, a military walkie-talkie, and a red gasoline jerrycan. Stylized 3D game art with high-contrast hand-painted textures, clean silhouettes readable on mobile screens, studio lighting, 4k --ar 16:9`

### Prompt 06: Veículos Customizáveis
> `3D vehicle concept art of a beat-up 1980s American pickup truck modified for zombie apocalypse, welded metal bullbar on the front, wire mesh over windows, spare tires and fuel cans strapped to the roof rack, rust and mud splatters. Stylized semi-realistic 3D mobile game aesthetic, clean topology look, three-quarter view on a neutral background --ar 16:9`

### Prompt 07: Key Art do Menu Principal
> `Main menu background artwork for a mobile 3D zombie survival game set in rural USA. Atmospheric scene looking out from inside a dimly lit, barricaded cabin window onto a foggy pine forest and a distant abandoned highway with stalled cars and silhouettes of wandering zombies at dusk. Moody volumetric fog, warm lantern light inside, cold blue twilight outside, stylized semi-realistic 3D game graphics, ultra-detailed, cinematic composition with empty space on the left for UI buttons --ar 16:9`

---

## FASE 2: Arquitetura Base, Controles e Câmera (Engenharia de Código)

### Prompt 08: GameManager e Máquina de Estados
> `Atue como um Arquiteto Sênior de Jogos Mobile. Crie a estrutura base de pastas e o código em C# (Unity URP) para um jogo de sobrevivência zumbi 3D de mundo aberto. Implemente um GameManager usando o padrão Singleton e State Machine para gerenciar os estados: MainMenu, LobbySetup, LoadingWorld, InGame_Gameplay, InGame_Paused e PlayerDead. Garanta que o gerenciamento de memória descarte assets não utilizados entre transições de cena.`

### Prompt 09: Câmera Híbrida (3ª Pessoa / 1ª Pessoa)
> `Desenvolva um controlador de câmera avançado em C# para mobile que permita alternar suavemente (via interpolação Lerp de posição e FOV) entre Terceira Pessoa (Over-the-Shoulder) e Primeira Pessoa (FPS) com o toque de um botão na HUD. Inclua sistema de colisão de câmera (SphereCast) para evitar que a câmera atravesse paredes em ambientes internos fechados, além de tremor de câmera (Camera Shake) procedural para disparos, explosões e sustos (jumpscares).`

### Prompt 10: Input System Touch Contextual
> `Crie um sistema completo de input touch para mobile: joystick virtual esquerdo dinâmico (para movimentação, com zona externa para corrida/sprint), área de arrasto na metade direita da tela para rotação da câmera com aceleração ajustável, e botões contextuais dinâmicos que mudam de ícone dependendo do que o jogador mira (ex: abrir porta, pegar item, atacar corpo-a-corpo, mirar/atirar, agachar/stealth).`

### Prompt 11: Movimentação, Stamina e Postura
> `Implemente o controlador de personagem (PlayerMovement) com estados de postura: Em Pé, Agachado (reduz raio de detecção sonora e visual dos zumbis) e Correndo. Crie um sistema de Stamina e Exaustão inspirado em Project Zomboid: correr, pular cercas ou golpear com armas pesadas consome stamina; se a stamina zerar, o personagem sofre penalidade na velocidade de movimento e na velocidade de ataque até recuperar o fôlego.`

---

## FASE 3: Mundo Aberto, Clima e Iluminação

### Prompt 12: Streaming de Mapa por Chunks
> `Crie um sistema de carregamento dinâmico de mundo aberto por Chunks (WorldChunkManager) otimizado para mobile. Divida o mapa de uma cidade fictícia do interior dos EUA (estilo Kentucky/Indiana) em blocos de 100x100 metros. O sistema deve carregar assincronamente apenas o chunk atual do jogador e os 8 chunks adjacentes, desativando meshes distantes e utilizando impostors (billboards 2D) para árvores e prédios no horizonte, mantendo o uso de RAM abaixo de 1.5GB.`

### Prompt 13: Ciclo Dia/Noite e Clima Dinâmico
> `Desenvolva um sistema de ciclo Dia/Noite de 24 horas (com escala de tempo configurável, ex: 1 hora real = 1 dia no jogo) e clima dinâmico (WeatherSystem): Ensolarado, Nublado, Chuva Forte, Tempestade com Raios e Neblina Densa. A chuva deve abafar o som dos passos do jogador (ajudando no stealth), molhar as roupas (causando frio) e a neblina deve reduzir a distância de visão tanto do jogador quanto dos zumbis.`

### Prompt 14: Occlusion e Visibilidade de Interiores
> `Implemente um sistema inteligente de detecção de ambientes internos (IndoorDetector). Quando o jogador entrar em uma casa americana, o sistema deve ajustar a exposição da câmera (adaptação ocular ao escuro), abafar os sons externos (vento, chuva) e ativar o Occlusion Culling agressivo para não renderizar zumbis e objetos que estão fora da linha de visão das janelas/portas, economizando GPU no celular.`

### Prompt 15: Corte de Infraestrutura Mundial
> `Crie um sistema de degradação da infraestrutura mundial inspirado em Project Zomboid. Nos primeiros dias de jogo, as torneiras das casas têm água limpa e as luzes/geladeiras funcionam. Após um número aleatório de dias (configurável no servidor, ex: entre 14 e 30 dias), a rede elétrica e o abastecimento de água colapsam globalmente, forçando os jogadores a usarem geradores a gasolina, coletarem água da chuva em barris e ferverem água de rios.`

---

## FASE 4: Interfaces, Menus e Servidores

### Prompt 16: Menu Principal Atmosférico
> `Crie o código e a estrutura de UI para o Menu Principal no estilo estilizado/gritty pedido. O fundo deve ser uma cena 3D em tempo real (não apenas uma imagem estática) mostrando uma cabana barricada ao entardecer com partículas de poeira, fumaça e zumbis passando ao longe na neblina. Na esquerda, posicione botões minimalistas com tipografia desgastada (estilo stencil/máquina de escrever) e efeitos sonoros de clique mecânico: Jogar (Singleplayer), Multiplayer (Servidores), Customizar Sobrevivente, Configurações e Sair.`

### Prompt 17: Menu de Configurações e Otimização
> `Desenvolva um Menu de Configurações completo dividido em 4 abas (Gráficos, Controles, Áudio, Jogo) focado em máxima otimização para celulares fracos e potentes. Na aba Gráficos, inclua: Presets (Batata/Ultra Low, Baixo, Médio, Alto, Ultra), Escala de Resolução (50% a 100%), Limite de FPS (30, 45, 60, 90, 120 FPS), Distância de Renderização, Qualidade das Sombras, Anti-Aliasing (FXAA, SMAA), Toggles para SSAO, Bloom e Reflexos. Inclua contador de FPS e uso de RAM na HUD.`

### Prompt 18: Setup de Servidores (Single e Multiplayer)
> `Crie a interface e a lógica de backend (ServerConfigData) para a criação de partidas Singleplayer e Multiplayer (Host Local ou Servidor Dedicado). Permita que o criador configure regras detalhadas estilo Sandbox antes de iniciar o mundo: Modo de Jogo (Single, Co-op até 8 jogadores ou PvP/PvE até 32 jogadores), População de Zumbis (Baixa, Normal, Alta, Horda), Comportamento dos Zumbis (Lento, Corredor à Noite, Corredor Sempre), Raridade de Loot e Velocidade de Fome/Sede.`

---

## FASE 5: Sobrevivência, Saúde e Itens

### Prompt 19: Banco de Dados de 60+ Itens
> `Crie uma arquitetura escalável de itens (ItemDatabase) usando ScriptableObjects/JSON contendo mais de 60 itens essenciais divididos em categorias, com peso (kg), durabilidade, ícone e modelo 3D: Armas Brancas (pé de cabra, machado de bombeiro, taco com pregos, facão), Armas de Fogo (9mm, .38, Calibre 12, .308, M16), Comida/Bebida (enlatados, carne seca, água, suco, vegetais que estragam), Médicos (bandagens, álcool, analgésicos, antibióticos, tala) e Ferramentas (martelo, serra, lanterna, galão de gasolina, mochila).`

### Prompt 20: Inventário por Peso e Loot Procedural
> `Implemente um sistema de inventário baseado em Peso (Encumbrance) e Capacidade de Mochila otimizado para toque no celular (toque para ver opções: Usar, Equipar, Largar, Desmontar). Crie o gerador de loot procedural (LootSpawner): ao abrir armários de cozinha, aparecem comidas; em garagens, ferramentas e gasolina; em delegacias, armas e munição; em farmácias, remédios. O loot só é gerado no momento em que o jogador abre o contêiner pela primeira vez.`

### Prompt 21: Saúde Anatômica e Moodles
> `Desenvolva um sistema de saúde detalhado inspirado em Project Zomboid. O corpo do jogador é dividido em zonas (Cabeça, Tronco, Braços, Pernas). Crie estados de ferimento: Arranhão, Laceração, Mordida (risco de zumbificação), Fratura (impede de correr até colocar uma tala) e Sangramento (perda contínua de HP se não enfaixado). Adicione ícones de status na HUD (Moodles) para Fome, Sede, Cansaço, Pânico, Dor, Frio/Calor e Infecção.`

### Prompt 22: Sistema de Crafting e Culinária
> `Crie um sistema de Crafting (CraftingSystem) acessível por uma aba rápida no inventário. O jogador pode combinar itens próximos (no chão ou na mochila) sem precisar de bancada para receitas básicas (ex: rasgar roupas para fazer bandagens, colocar pregos no taco de beisebol, ferver água suja na fogueira para torná-la potável, cozinhar carne crua para evitar intoxicação alimentar). Para receitas avançadas, exija ferramentas específicas (ex: martelo + serra + tábuas).`

---

## FASE 6: IA dos Zumbis e Sistema de Combate

### Prompt 23: IA Sensorial dos Zumbis
> `Implemente uma IA de zumbis altamente otimizada usando NavMesh e Object Pooling. Cada zumbi possui uma Máquina de Estados (Idle, Wander, InvestigateSound, Chase, Attack, Crawling). Visão: Cone de visão afetado pela iluminação e neblina. Audição: Zumbis reagem a raios sonoros emitidos por passos correndo, janelas quebrando, alarmes de carros e tiros de armas de fogo (tiros atraem zumbis a 200 metros). Olfato: Sangramento aberto aumenta o raio de detecção.`

### Prompt 24: Sistema de Hordas Dinâmicas
> `Crie um HordeManager que controla o comportamento coletivo. Quando vários zumbis caminham na mesma direção ou ouvem um som alto (como um helicóptero passando ou um tiro de escopeta), eles se agrupam formando uma horda migratória. Para manter 60 FPS no mobile, zumbis a mais de 40 metros devem usar animações simplificadas (GPU Instancing) e atualizar sua lógica de IA apenas 2 vezes por segundo.`

### Prompt 25: Combate Tático e Balística
> `Programe o sistema de combate tático. Armas corpo-a-corpo possuem arco de ataque, velocidade, consumo de stamina e chance de derrubar o zumbi no chão (permitindo um golpe finalizador pisoteando a cabeça). Armas de fogo possuem recuo (recoil), dispersão baseada no nível de pânico/movimento do jogador, recarga realista de pentes e atravessamento de projéteis (ex: escopeta acerta múltiplos zumbis próximos).`

---

## FASE 7: Construção, Veículos e Habilidades

### Prompt 26: Barricadas e Base Building
> `Implemente um sistema de construção livre e de fortificação (BuildingSystem). O jogador pode usar um martelo, pregos e tábuas para barricar janelas e portas de qualquer casa americana existente (bloqueando a visão e a entrada de zumbis). Além disso, permita construir paredes de madeira, portões, cercas, coletores de chuva e fogueiras usando uma pré-visualização holográfica verde/vermelha no terreno.`

### Prompt 27: Sistema de Veículos e Mecânica
> `Desenvolva um controlador de veículos arcade-realista para mobile (botões de acelerar, frear/ré e setas esquerda/direita). Cada veículo encontrado nos EUA (sedãs, picapes, viaturas, ambulâncias) possui estado individual de peças: Bateria, Motor, Pneus, Tanque de Gasolina e Chave na ignição (ou ligação direta / hotwire). Atropelar zumbis danifica o capô e o motor do carro.`

### Prompt 28: Progressão RPG (Skills Práticas)
> `Crie um sistema de progressão passiva onde o jogador melhora suas habilidades praticando-as: Carpintaria (constrói estruturas mais resistentes), Mira & Recarga (reduz tremor e recarrega rápido), Furtividade (menos barulho ao andar), Primeiros Socorros (cura mais rápido) e Mecânica (conserta carros e faz hotwire). Adicione livros de habilidades encontrados nas casas que multiplicam o ganho de XP.`

---

## FASE 8: Multiplayer, Eventos e Finalização

### Prompt 29: Sincronização Multiplayer Netcode
> `Implemente a camada de rede para o modo Multiplayer usando Netcode/Mirror otimizado para conexões móveis (4G/5G/Wi-Fi). Sincronize a posição dos jogadores com interpolação suave, estado das portas/janelas, inventário de contêineres (com trava para evitar duplicação de itens) e sincronização de posição das hordas de zumbis via autoridade do servidor.`

### Prompt 30: VOIP de Proximidade e Walkie-Talkies
> `Crie um sistema de comunicação imersivo para o multiplayer: chat de texto rápido com frases prontas para mobile e chat de voz por proximidade (VOIP) onde a voz diminui com a distância (e atrai zumbis próximos se o jogador falar alto!). Adicione a funcionalidade de Rádios Walkie-Talkie: dois jogadores com rádios na mesma frequência podem conversar a quilômetros de distância.`

### Prompt 31: Persistência do Mundo e Saves
> `Desenvolva um sistema robusto de salvamento em JSON binário criptografado (SaveLoadManager). Ele deve salvar o estado exato do jogador (posição, saúde, inventário, habilidades) e as alterações permanentes do mundo (quais portas estão abertas/quebradas, barricadas, paredes construídas, posição dos carros e loot dos armários).`

### Prompt 32: Áudio Espacial e Trilha Adaptativa
> `Implemente um gerenciador de áudio (AudioManager) com atenuação 3D espacial. Crie uma trilha sonora adaptativa que muda dinamicamente: música ambiente melancólica e minimalista (violão/piano) durante a exploração calma, e percussão tensa quando o jogador é avistado por uma horda. Adicione sons distintos de passos dependendo da superfície (madeira, grama, asfalto, vidro quebrado).`

### Prompt 33: Meta-Eventos Aleatórios
> `Crie um diretor de eventos aleatórios (MetaEventDirector) que ocorre periodicamente fora da tela do jogador para manter o mundo vivo: tiros distantes de outros sobreviventes, gritos, alarmes de casas disparando ao arrombar uma janela trancada, e o Evento do Helicóptero (um helicóptero sobrevoa a região por alguns minutos, atraindo centenas de zumbis para a localização do jogador).`

### Prompt 34: Otimização Extrema (Object Pooling / LODs)
> `Realize uma passagem completa de otimização no código para garantir estabilidade em dispositivos Android/iOS intermediários: implemente Object Pooling para balas, cápsulas, efeitos de sangue, sons e zumbis (evitando picos de Garbage Collector). Configure grupos de LOD (Level of Detail) agressivos para todas as construções americanas e vegetação.`

### Prompt 35: Pipeline de Build e Anti-Cheat Básico
> `Crie um script de validação de pré-build e proteções básicas contra trapaças no multiplayer (validação no servidor de velocidade máxima de movimento, dano de armas e quantidade de itens no inventário). Gere também as configurações de compressão de texturas (ASTC para Android/iOS), configuração de IL2CPP e um sistema de logs de erro (Crash Reporter) para pós-lançamento.`