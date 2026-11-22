# Survive the Heartland

Jogo de sobrevivência zumbi 3D em mundo aberto para celular (Android), ambientado no interior dos EUA (Kentucky/Indiana). Inspirado na atmosfera de Project Zomboid, em 3D estilizado com texturas pintadas à mão.

- **Engine:** Godot 4.3 (renderizador Compatibility, pensado pra rodar em celular fraco)
- **Linguagem:** GDScript
- **Plataforma:** Android (APK gerado pelo GitHub Actions)

## Como testar no celular

1. Abra a aba **Actions** do repositório e espere o workflow **Build APK (Android)** ficar verde.
2. Baixe o APK na aba **Releases** (marcado como pré-lançamento) ou nos **Artifacts** da execução.
3. Instale no Android (pode ser preciso permitir "instalar apps desconhecidos").

## Estrutura

```
project.godot            configuração do projeto
export_presets.cfg       exportação Android
scenes/                  cenas (menu principal, jogo)
scripts/autoload/        GameManager (máquina de estados)
scripts/ui/              menu, HUD e controles touch
scripts/player/          jogador e câmera
scripts/world/           mundo e zumbis
docs/PROMPT_MASTER.md    plano original com os 35 prompts
docs/ROADMAP.md          o que já foi feito e o que falta
art/reference/           imagens de referência de direção de arte
```

## Estado atual

Veja o [ROADMAP](docs/ROADMAP.md). A ideia é evoluir uma fase de cada vez, sempre com algo jogável no APK.

## Observação sobre a arte

As imagens em `art/reference/` são só referência de estilo. O mascote "Spiffo" que aparece em algumas delas pertence a Project Zomboid; antes de publicar o jogo, troque por uma marca própria (por exemplo, o "Last Stop Diner").
