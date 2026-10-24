# Hakon

🇧🇷 Português | 🇺🇸 [English](#english)

**Versão 4.0 — Universal Battlegrounds Hub**

---

## Sobre

Hakon é um projeto em Luau com interface personalizada e sistemas configuráveis de mira, visualização de jogadores, movimentação e diagnóstico, desenvolvido com foco em experiências do gênero Battlegrounds, Fighting Games e Arena Games.

## Funcionalidades

###  Mira e seleção de alvos

- Aim Assist com sensibilidade configurável.
- Camera Lock com seleção e troca de alvos.
- Seleção de parte do personagem: `Head`, `Torso` ou `Random`.
- Círculo de FOV com tamanho e cor configuráveis.
- Priorização de alvos por distância ou direção.
- Whitelist e Blacklist.
- Verificações de equipe, estado do personagem e visibilidade.

###  ESP avançado

- Exibição de nomes, distância e vida.
- Barra de vida.
- Caixas e contornos visuais.
- Skeleton ESP.
- Tracers até os jogadores.
- Indicadores de jogadores fora da tela.
- Visualização de hitboxes.
- Verificação de distância de renderização.
- Cores por equipe, RGB, arco-íris e paleta multicolorida.
- Ajustes de transparência, intensidade e espessura dos contornos.

###  Movimento

- Configurações de `WalkSpeed` e `JumpPower`.
- Modificador de gravidade.
- Flight Mode com velocidade configurável.
- Opções relacionadas a knockback.

###  Interface e personalização

- Cores personalizáveis para tema, destaque e elementos visuais.
- Controle de escala da interface.
- Modo compacto.
- Opção para reduzir animações.
- Notificações personalizadas.
- Atalhos de teclado configuráveis.

###  Diagnóstico

- Monitor de FPS.
- Debug Overlay com informações do alvo, FOV e estado do ESP.
- Atualização dos elementos visuais em tempo real.

## Controles padrão

| Tecla | Função |
|---|---|
| `RightShift` | Abrir ou fechar o menu |
| `E` | Alternar ESP |
| `L` | Alternar Camera Lock |
| `F` | Alternar Flight Mode |
| `Tab` | Trocar de alvo |

## Configuração

As opções principais estão organizadas na tabela `Config`, incluindo parâmetros de mira, ESP, cores, movimento, interface, atalhos e diagnóstico.

## Compatibilidade

O código utiliza APIs específicas de ambientes de execução externos, como `Drawing`, `CoreGui` e funções de hooking.

## Créditos

**Desenvolvido por 777.**

Discord: `777.imt`

---

<a id="english"></a>

# Hakon

**Version 4.0 — Universal Battlegrounds Hub**

## About

Hakon is a Luau project featuring a custom interface and configurable systems for aiming, player visualization, movement and diagnostics, designed around Battlegrounds, Fighting Games and Arena Games.

## Features

###  Aim and Target Selection

- Aim Assist with adjustable sensitivity.
- Camera Lock with target selection and switching.
- Target part selection: `Head`, `Torso` or `Random`.
- Configurable FOV circle size and color.
- Target prioritization by distance or direction.
- Whitelist and Blacklist.
- Team, character-state and visibility checks.

###  Advanced ESP

- Player names, distance and health display.
- Health bars.
- Visual boxes and outlines.
- Skeleton ESP.
- Tracers.
- Off-screen player indicators.
- Hitbox visualization.
- Render distance limit.
- Team-based colors, RGB, rainbow and multicolor palette modes.
- Adjustable transparency, intensity and outline thickness.

###  Movement

- `WalkSpeed` and `JumpPower` settings.
- Gravity modifier.
- Flight Mode with adjustable speed.
- Knockback-related options.

###  Interface and Customization

- Customizable theme, accent and visual colors.
- Interface scale control.
- Compact mode.
- Reduced-motion option.
- Custom notifications.
- Configurable keyboard shortcuts.

###  Diagnostics

- FPS monitor.
- Debug Overlay displaying target, FOV and ESP status.
- Real-time visual updates.

## Default Controls

| Key | Action |
|---|---|
| `RightShift` | Toggle the menu |
| `E` | Toggle ESP |
| `L` | Toggle Camera Lock |
| `F` | Toggle Flight Mode |
| `Tab` | Switch target |

## Configuration

Main options are organized in the `Config` table, covering aiming, ESP, colors, movement, interface, keybinds and diagnostics.

## Compatibility

The source uses APIs associated with external execution environments, including `Drawing`, `CoreGui` and hooking functions.

## Credits

**Developed by 777.**

Discord: `777.imt`
