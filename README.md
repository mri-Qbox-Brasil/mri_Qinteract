# mri_Qinteract: Manual

**AAA-Grade Interaction Experience for FiveM.**

Interação por aproximação no mundo. Ao chegar perto de um veículo, porta, NPC
ou ponto marcado, aparece um prompt preso ao objeto com a tecla e as opções,
no tema da suíte MRI. Substitui o ox_target: os resources que usam ox_target,
qb-target, qtarget ou sleepless_interact passam a funcionar por aproximação sem mudar nada neles.

---

## Sumário

1. [Dependências](#dependências)
2. [Instalação](#instalação)
3. [Permissões (ACE)](#permissões-ace)
4. [Como funciona](#como-funciona)
5. [Painel admin (`/admininteract`)](#painel-admin-admininteract)
6. [Teclas](#teclas)
7. [Compatibilidade com outros targets](#compatibilidade-com-outros-targets)
8. [Formato das opções](#formato-das-opções)
9. [Exports próprios](#exports-próprios)
10. [Opções padrão nos veículos](#opções-padrão-nos-veículos)
11. [Tema e cores](#tema-e-cores)
12. [Localização](#localização)
13. [Estrutura de arquivos](#estrutura-de-arquivos)
14. [Desenvolvimento](#desenvolvimento)

---

## Dependências

| Recurso | Obrigatório | Observação |
|---|---|---|
| `ox_lib` | Sim | Keybinds, callbacks, locale, `/uiconfig` |
| `qbx_core` ou `qb-core` | Não | Filtro de grupos (`groups`, `job`, `gang`, `citizenid`) |
| `ox_inventory` | Não | Filtro de itens (`items`); sem ele, usa o inventário do qb-core |
| `mri_Qadmin` | Não | Registra o painel como aba "Interação" do painel admin MRI |

---

## Instalação

1. Copie a pasta `mri_Qinteract` para `resources/`.
2. No `server.cfg`, `ensure mri_Qinteract` depois do `ox_lib` e do framework,
   **no lugar** do `ensure ox_target`, e antes dos resources que registram
   interações.
3. Remova ou desabilite o `ox_target`, o `qb-target`, o `qtarget` e o
   `sleepless_interact`. O `fxmanifest.lua` declara `provide` deles, então
   não podem rodar juntos.
4. Se usar o `ox_compat` com o módulo de qb-target ligado, desligue esse
   módulo: o mri_Qinteract já responde pelo qb-target.

---

## Permissões (ACE)

O painel e o salvamento dos settings pedem a ACE `mri_Qinteract.admin` (ou a
`command`, que cobre console e superadmin):

```
add_ace group.admin mri_Qinteract.admin allow
```

---

## Como funciona

- **Alvos.** A cada 200ms o client procura o que está por perto: pontos e
  zonas registrados, e veículos, peds, objetos e jogadores que tenham opções
  (pela entidade, pelo modelo ou globais). Opções com `bones` viram um alvo no
  osso; com `offset`, um alvo no offset; o resto fica no centro do modelo.
- **Marcador distante.** Alvos dentro da distância do marcador com alguma
  opção liberada (grupo, item e `canInteract`) mostram um marcador. Alvo mais
  longe que isso aparece só quando já está no alcance de alguma opção.
- **Foco.** Entre os alvos com opção no alcance (`distance` da opção ou, sem
  ela, o alcance padrão do painel), o
  prompt abre no que estiver mais perto do centro da tela. Com "exigir olhar
  pro alvo", ele só conta dentro da **área de mira do marcador**: um círculo
  em volta do marcador na tela, em fração da altura da tela (10% no padrão).
  A área é medida na tela, então tem o mesmo tamanho com o alvo perto ou longe.
- **Zonas.** Esfera, caixa e polígono contam a distância até a borda (dentro
  da zona é zero); o prompt fica no centro.
- **Linha de visão.** Com "exigir linha de visão", um raio da câmera até o
  alvo esconde o que estiver atrás de parede ou objeto.
- **Dentro de veículo** nada aparece, a não ser opções com
  `allowInVehicle = true`.
- **Com tela aberta** (inventário, celular, menu, qualquer NUI com foco) ou
  no menu de pausa, prompt e marcadores somem com o fade e voltam ao fechar.
- **Confirmar.** A tecla de interagir escolhe a opção ativa (a roda do mouse
  e as setas trocam). Opções com `holdTime` pedem segurar a tecla. Depois de
  confirmar, a tecla espera 750ms antes de aceitar outra (um loader aparece
  na tecla).

---

## Painel admin (`/admininteract`)

Abre com `/admininteract` ou pela aba "Interação" do mri_Qadmin. Tem prévia
ao vivo do prompt. Ao salvar, vale na hora para todos os jogadores, sem
restart. Fica salvo em `data/config.json`; sem o arquivo (ou inválido), valem
os padrões de `shared/settings.lua`.

| Seção | Opções |
|---|---|
| Visual do prompt | tema (vidro, bloco, contorno, circular), cor própria ou a da suíte, ícones, tamanho |
| Comportamento | modo compacto e tempo pra fechar, tecla de interagir, tecla de mostrar/esconder (alternar ou segurar), som ao confirmar |
| Alcance e mira | distância do marcador, alcance padrão das opções, marcadores de longe ao mesmo tempo, exigir olhar pro alvo, área de mira do marcador, exigir linha de visão |
| Marcadores | marcador distante e ponto central: ligado, forma (alvo, ponto, anel, diamante, losango vazado, quadrado, olho, mão, seta, mira em cruz), cor própria ou a de destaque, opacidade, tamanho; pulso no marcador distante; reagir ao alvo no ponto central |

Padrões da base:

| Opção | Padrão |
|---|---|
| Tema | bloco |
| Cor de destaque | `#FFFFFF` |
| Modo compacto | desligado |
| Distância do marcador | 5 m |
| Alcance padrão | 3 m |
| Marcadores de longe | 2 |
| Exigir olhar pro alvo | ligado, área de 10% |
| Exigir linha de visão | desligado |
| Marcador distante | alvo, branco, 80% de opacidade, com pulso |
| Ponto central | desligado |

A letra das teclas no painel é o padrão do keybind: vale depois de reiniciar
o resource e só para quem nunca trocou a tecla nas configurações do jogo.

---

## Teclas

Keybinds do FiveM (o jogador troca em Configurações > Teclas > FiveM):

| Nome | Padrão | O que faz |
|---|---|---|
| `mri_interact` | `E` | Confirma a opção ativa (segura nas que têm `holdTime`) |
| `mri_interact_toggle` | `LMENU` (Alt) | Com "tecla pra mostrar/esconder" ligada, só mostra interação com ela, alternando ou enquanto segura |

---

## Compatibilidade com outros targets

Os exports abaixo respondem com o nome do resource original
(`exports.ox_target:addModel(...)`, `exports['qb-target']:AddBoxZone(...)`).

**ox_target:** `disableTargeting`, `isActive`, `addGlobalOption`,
`removeGlobalOption`, `getTargetOptions`, `addGlobalObject`, `addGlobalPed`,
`addGlobalPlayer`, `addGlobalVehicle` e os `removeGlobal*`, `addModel`,
`removeModel`, `addEntity`, `removeEntity`, `addLocalEntity`,
`removeLocalEntity`, `addSphereZone`, `addBoxZone`, `addPolyZone`,
`removeZone` (aceita id ou nome; id inexistente é ignorado), `zoneExists`.

**qb-target:** `AddCircleZone`, `AddBoxZone`, `AddPolyZone`, `AddComboZone`,
`AddEntityZone`, `RemoveZone`, `AddGlobalType`, `RemoveGlobalType`,
`AllowTargeting`, `IsTargetActive`, `IsTargetSuccess`, `SpawnPed`,
`RemoveSpawnPed`, `AddTargetBone`, `RemoveTargetBone`, `AddTargetEntity`,
`RemoveTargetEntity`, `AddTargetModel`, `RemoveTargetModel`, `AddGlobalPed`,
`AddGlobalVehicle`, `AddGlobalObject`, `AddGlobalPlayer` e os `RemoveGlobal*`.

**qtarget:** os mesmos do qb-target (menos `SpawnPed` e `RemoveSpawnPed`), com os globais como `Ped`, `Vehicle`,
`Object`, `Player` e `RemovePed`, `RemoveVehicle`, `RemoveObject`,
`RemovePlayer`.

**sleepless_interact:** `disableInteract`, `addCoords` (aceita uma posição ou
uma lista, e devolve o id ou a lista de ids), `removeCoords`, os
`addGlobal*`/`removeGlobal*` (Ped, Vehicle, Object, Player), `addModel`,
`removeModel`, `addEntity`, `removeEntity`, `addLocalEntity` e
`removeLocalEntity`. Nesse formato, `offset` é em metros a partir da
entidade e `offsetAbsolute` é em metros nos eixos do mundo; a compat converte. `hideWhenEmpty` na opção
não tem efeito: o marcador só aparece com opção liberada.

Em todos, remover sem nomes tira só as opções do resource que chamou, e com
nomes tira as desse resource com aquele nome (ou label).

Diferenças de propósito:

- `addGlobalOption` entra em todo alvo que já tem opção própria. No ox_target
  aparece em tudo que se mira; por aproximação, todo objeto por perto viraria
  alvo.
- `isActive`, `IsTargetActive` e `IsTargetSuccess` dizem se tem prompt aberto.
- `SpawnPed` cria o ped local na hora. `RemoveSpawnPed` aceita o handle, uma
  lista ou nada (tira todos do resource), e os peds somem junto com o
  resource que criou.
- Não existem aqui os getters e updaters de dados do qb-target (`GetZoneData`,
  `UpdateZoneData` e afins) nem os menus aninhados do ox_target
  (`openMenu`/`menuName`).

No formato qb, `action(entity)`, `event` com `type` (`client`, `server`,
`command`, `qbcommand`), `canInteract(entity, distance, option)`, `job`,
`gang`, `citizenid` e `item` são convertidos para o formato abaixo. O evento
recebe a própria opção com `entity`, como no qb-target.

---

## Formato das opções

O mesmo do ox_target, com alguns campos do prompt:

| Campo | Tipo | Descrição |
|---|---|---|
| `label` | string | Texto da opção (aceita HTML simples) |
| `name` | string | Identificador para remover; padrão é o `label` |
| `icon` | string | Ícone do Font Awesome (`fa-solid fa-car` ou só `car`) |
| `iconColor` | string | Cor do ícone |
| `distance` | number | Alcance da opção; padrão é o alcance padrão do painel |
| `groups` | string, lista ou `{ [grupo] = nota }` | Grupos que podem usar |
| `items` | string, lista ou `{ [item] = quantidade }` | Itens necessários |
| `anyItem` | boolean | Basta um dos itens |
| `canInteract` | `fun(entity, distance, coords, name, bone): boolean` | Filtro próprio |
| `bones` | string ou lista | Ossos da entidade onde a opção aparece |
| `offset` | vector3 | Ponto na caixa do modelo, em proporção de 0 a 1 por eixo (`0.5, 0.5, 0.5` é o centro; `0.5, 0.0, 0.5` é o meio da frente) |
| `offsetAbsolute` | vector3 | Metros a partir da origem da entidade, girando com ela |
| `allowInVehicle` | boolean | Aparece também com o jogador dentro de um veículo |
| `holdTime` | number | Milissegundos segurando a tecla para confirmar |
| `anim` | `{ dict, clip, flag }` | Animação enquanto segura |
| `hideButton` | boolean | Esconde a tecla com esta opção ativa |
| `cooldown` | number | Milissegundos que a tecla espera depois de confirmar esta opção (padrão 750) |
| `onActive` / `onInactive` | `fun(data)` | Quando a opção fica destacada no prompt e quando deixa de ficar |
| `whileActive` | `fun(data)` | A cada frame enquanto a opção está destacada |
| `color` | `{ r, g, b, a }` | Cor de destaque desta opção |

Ao confirmar, vale o primeiro destes: `onSelect(data)`, `export` (no resource
que registrou), `event` (client), `serverEvent` (entidade vai como netId) ou
`command`. `data` tem os campos da opção mais `entity`, `coords`, `distance`,
`zone` e `bone`.

---

## Exports próprios

Para quem prefere usar o mri_Qinteract direto (`exports.mri_Qinteract:...`):

| Export | Descrição |
|---|---|
| `addCoords(coords, options)` | Ponto fixo; devolve o id |
| `removeCoords(id, names?)` | Tira as opções com esses nomes (ou todas) |
| `addGlobalVehicle/Ped/Object/Player(options)` | Em todo veículo, ped, objeto ou jogador |
| `removeGlobalVehicle/Ped/Object/Player(names?)` | |
| `addModel(models, options)`, `removeModel(models, names?)` | Por modelo (nome ou hash) |
| `addEntity(netIds, options)`, `removeEntity(netIds, names?)` | Entidade de rede |
| `addLocalEntity(entities, options)`, `removeLocalEntity(entities, names?)` | Entidade local |
| `disable(state)`, `isDisabled()` | Liga ou desliga todas as interações |

As opções de um resource saem sozinhas quando ele para.

---

## Opções padrão nos veículos

Todo veículo destrancado ganha abrir/fechar das quatro portas, capô e
porta-malas, cada uma no osso dela (alcance de 1,5 m). Portas arrancadas ou
inexistentes não aparecem.

---

## Tema e cores

- Os temas do prompt têm fundo próprio (não seguem o fundo nem o glass da
  suíte). Da suíte vêm a fonte e o `--radius` (`/uiconfig`).
- A cor de destaque é a do painel ou, com "usar a cor da suíte", a
  `mri:color`, acompanhando quando muda. `color` na opção troca o destaque
  dela.
- O painel em si segue a suíte inteira: `mri:color`, `mri:backgroundColor` e
  o `/uiconfig` do ox_lib, ao vivo.

---

## Localização

Textos em `locales/pt-br.json` e `locales/en.json`, pelo `ox_lib`
(`setr ox:locale pt-br`).

---

## Estrutura de arquivos

```
client/
  main.lua         Entrada: carrega os módulos
  state.lua        Settings em uso e o que sai deles (cores, sprites)
  registry.lua     Interações registradas, por tipo de alvo
  scan.lua         Varredura do que está por perto e linha de visão
  options.lua      Filtro e execução das opções
  groups.lua       Grupos (qbx_core/qb-core) e itens (ox_inventory)
  render.lua       Foco, prompt, marcadores e ponto central (por frame)
  markers.lua      Animação dos marcadores
  dui.lua          Página do prompt numa DUI
  input.lua        Keybinds
  vehicle.lua      Opções padrão dos veículos
  api.lua          Exports próprios
  panel.lua        Settings ao vivo, tema e painel /admininteract
  compat/          ox_target, qb-target, qtarget e sleepless_interact
server/main.lua    Salva e serve os settings, plugin do mri_Qadmin, convars
shared/settings.lua Padrões e validação dos settings
web/               Prompt (DUI) e painel em React com o @mriqbox/ui-kit
data/config.json   Settings salvos pelo painel (estado do servidor)
```

---

## Desenvolvimento

Dentro de `web/`:

- `pnpm dev`: `/` mostra o prompt com opções de exemplo (`E` interage, a roda
  troca, `?compact` liga o modo compacto, `?v=block|glass|outline|round`
  troca o tema); `/admin.html` mostra o painel.
- `pnpm build`: gera `web/build`, que é o que o resource carrega.
- `pnpm markers`: gera `markers/<forma>_<px>.png` a partir de
  `web/src/markers/shapes.ts`, brancas (o Lua pinta), em vários tamanhos de
  8 a 128 px. Textura de runtime não tem mipmap: o Lua desenha sempre o
  tamanho mais próximo do que aparece na tela, senão a forma serrilha.

O CEF do FiveM é Chrome 103: nada de `color-mix` nem `translate`/`scale` como
propriedades soltas no CSS.
