# SHADOW FORTRESS — Designdokument & Teknisk Grund

> Detta dokument täcker **steg 1–3** i din arbetsordning (Game Design Document, Teknisk design, Filstruktur) och definierar grunden för **steg 4–6** (Core Systems, Player, Combat) som följer med som körbar GDScript-kod i projektmappen.
>
> **Ärlig avgränsning.** Detta är fundamentet, inte ett färdigt spel. Koden i `shadow_fortress/` är riktig, körbar Godot 4-arkitektur utan placeholders — men ett spel som matchar din Definition of Done (fullt spelbart, exporterat till alla plattformar, buggfritt, butiksklart) byggs över många sessioner. Pixel art, animationsframes och musik kan jag **specificera** men inte producera som färdiga assets här; allt är strukturerat så att en pixel artist droppar in dem direkt.

---

## 1. Vision & pelare

Ett filmiskt 2D-actionspel där **timing och respekt för faran** är allt. Det ska kännas som att spela en film, inte en arkadmaskin. Fyra designpelare styr varje beslut:

1. **Tyngd över tempo.** Varje slag har verklig startup och recovery. Du kan inte spamma. En missad roundhouse straffas.
2. **Ensamhet och hot.** Tomma korridorer, avlägsna ljud, vakter som ännu inte vet att du är där. Spänningen byggs av *frånvaron* av action lika mycket som striden.
3. **Fiender som tänker.** En vakt patrullerar, hör ett ljud, undersöker, ropar på hjälp. Du läser dem som motståndare, inte mål.
4. **Visa, berätta aldrig.** Ingen exposition. Världen, ruinerna och fiendernas beteende bär historien.

---

## 2. Core gameplay loop

```
Utforska  →  Undvik / smyg förbi vakter  →  (upptäckt eller val)  →  Strid
   ↑                                                                   ↓
Ny miljö  ←  Boss  ←  Hitta hemlighet / utrustning  ←  Öppna grind / lös pussel
```

Varje skärm är en liten knut: ett rum, ett par vakter, en grind eller ett hopp. Loopen är medvetet långsam — utforskning och smygande får ta tid så att striderna känns som höjdpunkter.

---

## 3. Stridssystem

Två lägen som spelaren glider mellan:

- **Traversal** — gå / spring / smyg. Används för att utforska och undvika vakter. Spring väsnas, smyg är tyst.
- **Combat** — höjd garde. Du slår, blockar, kontrar. Du vänder dig inte bort från hotet medan du gardar.

### 3.1 Attacker (frame data @ 60 FPS)

Frame-värden är auktoritativa och redigeras i inspektorn via `AttackData`-resurser (`.tres`). Recovery är *straffönstret* — det är där en missad attack gör dig sårbar.

| Attack | Höjd | Startup | Active | Recovery | Skada | Balance-skada | Stamina | Räckvidd |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Light Punch | Mid | 6 | 3 | 10 | 6 | 4 | 8 | 1.1 m |
| Heavy Punch | Mid | 12 | 4 | 20 | 14 | 10 | 18 | 1.2 m |
| Front Kick | Mid | 10 | 4 | 16 | 10 | 14 | 14 | 1.6 m |
| Roundhouse | High | 16 | 5 | 26 | 20 | 22 | 24 | 1.7 m |
| Sweep | Low | 12 | 4 | 22 | 8 | 30 | 16 | 1.3 m |
| Throw | — | 8 | 2 | 18 | 6 | knockdown | 14 | 0.8 m |

Designlogik: snabba slag (Light Punch) är säkra men svaga; tunga avslut (Roundhouse) vinner utbyten men är självmord om de missar. Sweep gör låg skada men knäcker balansen — verktyget för att fälla en gardande fiende. Throw slår igenom block.

### 3.2 Försvar

- **Block** (håll garde) — reducerar till chip-skada, kostar stamina per blockerad träff. Måste matcha höjd: en Sweep måste blockas lågt.
- **Perfect Block** — garde höjt *precis* innan träffen (12-frames fönster, `perfect_block_window`). Ingen skada, anfallaren staggras, ett kontrafönster öppnas.
- **Parry** — tapp mot attacken i exakt rätt ögonblick → reflekterar, stor stagger. (Byggs i combat-passet ovanpå perfect block-logiken.)
- **Counter** — attack inom kontrafönstret efter perfect block kommer ut snabbare/hårdare.

All försvarslogik bor i **ett** ställe (`CombatActor._on_hit_received`) så spelare och fiende lyder samma regler.

### 3.3 Resurser

| Resurs | Funktion | Regen |
|---|---|---|
| **Health** | Du dör på få träffar. Filmiskt, inte arkad. | Endast vid checkpoint / item |
| **Stamina** | Gränsar attacker och block. Tom = gardebrott + svaga slag. | 18/s efter 0.6 s paus |
| **Balance** | Poise. Tunga träffar/sweeps tömmer den → knockdown + sårbart get-up-fönster. | 30/s efter 0.4 s paus |

Balance regenererar snabbast: en stagger är ett ögonblicks fara, inte en dödsdom. Stamina är pacing-ventilen som dödar button-mashing.

---

## 4. Smyg

Fiender har **synkon** (range + vinkel framåt) och **hörselradie**. Smyg sänker fart och tystar steg; spring skickar en `noise_emitted` med stor radie. En fiende som hör ett ljud går till **Investigate**, söker vid senast kända position, och återgår till patrull om inget hittas. Att nå en omedveten fiende bakifrån i smygläge öppnar en tyst takedown (byggs i enemy-passet).

---

## 5. Fiende-AI

En finite state machine per fiende plus två lager som ger liv: **attack-tokens** (gruppkoordination) och **moral** (flykt/hjälprop).

### 5.1 Tillstånd

`PATROL → IDLE_GUARD → INVESTIGATE → SEARCH → ENGAGE → {ATTACK, DEFEND, REPOSITION} → FLEE → STAGGER → KNOCKDOWN → DEAD`

- **Patrol/Idle** — går rutten, stannar, lyssnar.
- **Investigate/Search** — går till ljudet, letar, ger upp.
- **Engage** — håller `preferred_range`, baitar, stänger gapet.
- **Attack** — kräver en token (se nedan), kör frame-driven attack.
- **Defend/Reposition** — blockar eller side-steppar för att bryta din rytm.
- **Flee** — låg moral → springer, kan ropa larm.

### 5.2 Attack-tokens (gruppkänsla)

`EncounterCoordinator` (autoload) delar ut max **2** samtidiga attack-tokens. En fiende måste hålla en token för att slå; resten cirklar och väntar. Det är detta som gör 3-mot-1 till något läsbart och rättvist — "de väntar, sedan slår de tillsammans" — istället för en svärm.

### 5.3 Moral

`_morale()` drivs av health-fraktionen. Under tröskeln (`1 − courage`) försöker fienden ropa larm (`alarm_raised`) och kan bryta till flykt. En fiendes död sänker närliggande allierades moral via samma larm-kanal. Personlighet sätts per fiende: `aggression` (hur gärna den committar) och `courage` (hur länge den står kvar).

---

## 6. Boss-ramverk

Varje boss = `CombatActor`-subklass med ett fas-styrt mönsterbyte:

- **Faser** vid HP-trösklar (t.ex. 100→66→33 %). Varje fas byter attack-set och lägger till en mekanik.
- **Tells** före signaturattacker — en läsbar wind-up som belönar den uppmärksamma.
- **Punish-fönster** efter stora attacker (lång recovery, samma princip som spelaren).
- **Egen musik, egna animationer, unik svaghet.** Svagheten är ofta ett specifikt försvar: en boss som överanvänder en High-attack straffas av perfect block + counter.

Bossarna mappar mot miljöerna (avsnitt 8).

---

## 7. Progression

Spelaren får verktyg i en medveten ordning så att varje ny miljö lär ut något:

| Miljö | Ny förmåga |
|---|---|
| Mountain Pass | Light Punch, Front Kick, Block (grunderna) |
| Forest Village | Sneak-takedown, Sweep |
| Bridge / Castle Wall | Heavy Punch, Perfect Block |
| Dungeon | Roll / dodge, Throw |
| Temple | Parry, Counter |
| Tower / Courtyard | Kombinationer, specialförmåga |
| Throne Room / Escape | Allt — provet |

---

## 8. Världsstruktur

Linjär resa, inga laddningsskärmar mellan rum inom ett avsnitt:

1. **Mountain Pass** — intro, ensamhet, första vakten. Miniboss: Gränsvakten.
2. **Forest Village** — smyg, flera vakter, patruller. Boss: Jägaren.
3. **Bridge → Castle Wall** — vertikalitet, hopp, larmsystem. Boss: Murkaptenen.
4. **Dungeon / Caves** — mörker, ljus/fackla-mekanik, fångar. Boss: Bödeln.
5. **Temple** — pussel, parry-läran. Boss: Tempelvakten (svärd).
6. **Tower / Courtyard** — öppen strid, flera fiender, tokens pressas. Boss: Livgardet (två samtidigt).
7. **Throne Room** — Tyrannen, flerfasboss.
8. **Escape** — fästningen rasar, ren traversal under press.

---

## 9. Teknisk arkitektur

**Mönster:** komponenter + signaler + state machines. Inga moduler håller hårda referenser till varandra — allt går via `EventBus`.

- **Autoloads (Managers):** `EventBus` (signalnav), `Encounter` (attack-tokens). Planerade: `GameManager`, `SaveManager`, `AudioManager`, `SceneManager`, `SettingsManager`, `LocalizationManager`.
- **Komponenter:** `HealthComponent`, `StaminaComponent`, `BalanceComponent` — composable noder på vilken actor som helst.
- **Combat:** `Hitbox`/`Hurtbox` (Area2D-par). Hitbox lever bara under active frames; Hurtbox vidarebefordrar råträff till actorn som äger försvarsbeslutet. `AttackData` är en `Resource` så all balans är data, inte kod.
- **State machines:** generisk `StateMachine` + `State` för spelarens rörelse/combat. Fiendens AI använder en egen, inbyggd enum-FSM för att hålla beslut + perception samlade och lättlästa.
- **Animation:** en `AnimationTree` (BlendTree + StateMachine-nod) per actor. Combat-states sätter conditions; active-frame-fönstren bör i produktion drivas av en `AnimationPlayer` call-method-track så hitboxen är frame-låst till spriten. Koden är förberedd för båda.

---

## 10. Filstruktur

```
shadow_fortress/
├─ project.godot              # autoloads + input map (klar)
├─ autoload/
│  ├─ EventBus.gd             # globalt signalnav (klar)
│  └─ EncounterCoordinator.gd # attack-tokens (klar)
├─ scripts/
│  ├─ components/
│  │  ├─ HealthComponent.gd   (klar)
│  │  ├─ StaminaComponent.gd  (klar)
│  │  └─ BalanceComponent.gd  (klar)
│  ├─ combat/
│  │  ├─ AttackData.gd        # Resource, frame data (klar)
│  │  ├─ Hitbox.gd            (klar)
│  │  └─ Hurtbox.gd           (klar)
│  ├─ core/
│  │  ├─ StateMachine.gd      (klar)
│  │  └─ State.gd             (klar)
│  └─ actors/
│     ├─ CombatActor.gd       # delad bas + försvarsregler (klar)
│     ├─ Player.gd            (klar)
│     └─ Enemy.gd             # perception + FSM + tokens + moral (klar)
├─ scenes/                    # nästa pass: .tscn för player, enemy, level
├─ resources/attacks/         # nästa pass: .tres per attack (frame data)
├─ characters/  enemies/  bosses/  weapons/  items/
├─ levels/  ui/  audio/  animation/  managers/
├─ save/  localization/  shaders/  effects/
```

---

## 11. Scenkontrakt

Skripten ovan förutsätter dessa nodträd (byggs i nästa pass som `.tscn`):

**Player.tscn / Enemy.tscn:**
```
CombatActor (CharacterBody2D)
├─ CollisionShape2D
├─ HealthComponent
├─ StaminaComponent
├─ BalanceComponent
├─ Hurtbox (Area2D)         # actor_path = ".."
│  └─ CollisionShape2D
├─ Pivot (Node2D)           # scale.x = facing → speglar allt
│  ├─ AnimatedSprite2D / Sprite2D
│  └─ Hitbox (Area2D)
│     └─ CollisionShape2D
└─ AnimationTree            # (Player) driver animationsblend
```

Collision layers: spelare och fiender på olika layers; Hitbox/Hurtbox på dedikerade combat-layers så de bara träffar varandra.

---

## 12. Kontroller (input map — redan i project.godot)

| Handling | Tangent | Gamepad |
|---|---|---|
| Rörelse | A / D | vänster spak |
| Spring | Shift | LB |
| Smyg | Ctrl | RB |
| Garde | K | LT |
| Light Punch | J | A / Cross |
| Heavy Punch | U | B / Circle |
| Front Kick | I | X / Square |
| Roundhouse | O | Y / Triangle |
| Sweep | L | RT |

Fullt remappbart i settings-passet. Touch-layout designas separat (avsnitt 14).

---

## 13. Kamera, sparsystem, ljud

- **Kamera:** mjuk följning med lookahead i färdriktning, dödzon i mitten, zoomar in vid boss/dramatiska ögonblick. Skakning via `camera_shake_requested`.
- **Save:** auto-save vid checkpoint (`checkpoint_reached`), manuell save i menyn, cloud-save via plattformens API i export-passet. State serialiseras till JSON i `save/`.
- **Ljud:** atmosfär först — vind, regn, steg på trä/sten/grus, avlägsna fåglar, eld. Inga överdrivna effekter. **Musik** växer dynamiskt: ambient utforskning → spänd "vakt undersöker" → full strid → boss-tema. Lager-baserad (synth + orkester + taiko) som blandas in beroende på spelläge.

---

## 14. Mobil

Inte en port. 60 FPS, låg batteriförbrukning, automatisk kamera. Stora touch-knappar (garde + 4 attacker), swipe för smyg/roll, auto-target på närmaste fiende. Smyg-undvikande designas så det funkar med en tumme. Frame-data är identisk — känslan bevaras.

---

## 15. Optimering & lokalisering

- **Optimering:** object pooling (fiender, effekter, projektiler), sprite atlases, LOD på parallax-lager, lazy/async level-laddning, effektiva collision-shapes.
- **Lokalisering:** all text via `LocalizationManager` + `.po/.csv`-tabeller från start. Minimal text (UI visar bara Liv, Stamina, Boss HP) gör detta billigt.

---

## 16. Produktionsplan (din arbetsordning)

| # | Steg | Status |
|---|---|---|
| 1 | Game Design Document | ✅ detta dokument |
| 2 | Teknisk design | ✅ detta dokument |
| 3 | Filstruktur | ✅ klar |
| 4 | Core Systems | ✅ komponenter, combat, FSM, EventBus |
| 5 | Player | ✅ controller klar (scen återstår) |
| 6 | Combat | ✅ försvarsregler klara; parry/counter/throw nästa |
| 7 | Enemy AI | ✅ perception + FSM + tokens + moral |
| 8 | Animation | ⬜ AnimationTree + sprite sheets (kräver artist) |
| 9 | Kamera | ⬜ |
| 10 | UI | ⬜ Liv / Stamina / Boss HP |
| 11 | Levels | ⬜ tilesets + parallax + första skärmen |
| 12 | Bossar | ⬜ |
| 13 | Ljud | ⬜ |
| 14 | Musik | ⬜ |
| 15 | Sparsystem | ⬜ |
| 16 | Mobilanpassning | ⬜ |
| 17 | Optimering | ⬜ |
| 18–20 | Test / bugg / release | ⬜ |

### Nästa konkreta mål: en spelbar vertical slice

En skärm i Mountain Pass: spelaren möter två vakter med full combat och AI. Det kräver av mig härnäst: `.tscn`-scener för Player och Enemy enligt kontrakten, en handfull `AttackData.tres` med tabellens frame-data, en enkel level-scen med golv + parallax, och en minimal HUD. Då har du något du faktiskt kör i Godot och känner på tyngden i striden — innan vi bygger ut världen.

---

## 17. Vad den här leveransen är — och inte är

**Är:** ett riktigt, modulärt Godot 4-fundament. Stridsmatematik, försvarsregler, tänkande fiende-AI och datadriven balans — allt körbart, inga placeholders, SOLID och signal-baserat precis som du bad om.

**Är inte än:** scenfiler, konst, animation, ljud och de 13 övriga stegen. Det är nästa sessioners arbete. Säg bara vart vi går: vertical slice, parry/counter-systemet, första bossen, eller HUD:en — så fortsätter jag i din ordning.
