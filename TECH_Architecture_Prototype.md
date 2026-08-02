# ТЕХНИЧЕСКАЯ АРХИТЕКТУРА — прототип «голого первого дня»

> **Цель этого файла:** дать правильную структуру Godot-проекта с самого начала,
> чтобы не переписывать её потом. Охватывает ТОЛЬКО вертикальный срез (§10 GDD):
> один голый день, чистая память, проверка, стресс. БЕЗ навыков, БЕЗ новостей,
> БЕЗ экономики — они лягут сверху на эту структуру позже.
>
> **Главный принцип:** данные и числа — в ресурсах (.tres), логика — в коде.
> Баланс крутится в инспекторе Godot, не в GDScript. Это то, что делает
> итерацию быстрой, а прототип — пригодным для калибровки.
>
> **Допущение:** пассажиры сидят на фиксированных слотах-сиденьях (два ряда по
> одному месту, §2.1 GDD). Если окажется иначе — меняется только PassengerSlot,
> не вся архитектура.
>
> **Версия Godot:** 4.x (актуальная стабильная). GDScript.

---

## 0. С чего начать (первые 3 шага, буквально)

1. Создай проект Godot 4.x, рендер **Forward+** (или Mobile, если целишь слабое
   железо — для 2D flat-графики Mobile хватит и быстрее).
2. Настрой в Project Settings → Display → Window: базовое разрешение под целевой
   экран (напр. 1280×720 или 1920×1080), Stretch Mode = `canvas_items`,
   Aspect = `expand`. Для flat-иллюстрации это даёт чёткое масштабирование.
   Фильтрацию текстур НЕ отключай (в отличие от пиксель-арта): для flat-графики
   Default Texture Filter = `Linear` (сглаживание) — векторные формы должны быть
   гладкими, а не с рваными краями. Оставь дефолт Linear.
3. Создай структуру папок (см. §1) и первый ресурс PassengerData (см. §3),
   прежде чем писать логику. Данные вперёд кода.

---

## 1. СТРУКТУРА ПАПОК

```
res://
├── data/                      # ресурсы-числа (.tres) — крутишь в инспекторе
│   ├── balance.tres           # StressBalance: все числа стресса
│   ├── day_config.tres        # DayConfig: длина смены, остановки, наплыв
│   └── passengers/            # PassengerData шаблоны (архетипы)
│       ├── honest_payer.tres
│       ├── honest_forgot.tres  # оплатил, но не покажет билет (потерял/смял)
│       ├── fare_dodger.tres    # заяц, врёт «оплатил»
│       └── ...
├── resources/                 # определения классов-ресурсов (.gd с class_name)
│   ├── passenger_data.gd
│   ├── stress_balance.gd
│   └── day_config.gd
├── scenes/
│   ├── main.tscn              # корень прототипа
│   ├── tram/
│   │   ├── tram_car.tscn      # вагон: слоты, место кондуктора
│   │   └── passenger_slot.tscn# одно сиденье (может быть пусто/занято)
│   ├── passenger/
│   │   └── passenger.tscn     # визуал пассажира + камера-лицо
│   └── ui/
│       ├── stress_bar.tscn    # шкала стресса (длина + заполнение)
│       ├── dialogue_box.tscn  # диалог + выбор действий
│       └── stop_display.tscn  # табло остановок
├── scripts/
│   ├── autoload/
│   │   ├── game_state.gd      # Autoload: состояние дня (деньги, выговоры)
│   │   └── stress_system.gd   # Autoload: ЕДИНСТВЕННЫЙ владелец стресса
│   ├── tram_car.gd
│   ├── passenger_slot.gd
│   ├── passenger.gd
│   ├── day_manager.gd         # оркестратор дня: остановки, наплыв, конец
│   └── conductor.gd           # игрок: движение, подход, взаимодействие
└── assets/                    # спрайты, звук — потом, для прототипа заглушки
```

**Почему так:** `data/` отделена от `resources/` — в первой лежат конкретные
значения (.tres), во второй определения их структуры (.gd class_name). Правишь
баланс — трогаешь только data/. Меняешь структуру данных — только resources/.
Логика в scripts/ читает данные, но их не хранит.

---

## 2. КЛЮЧЕВОЕ АРХИТЕКТУРНОЕ РЕШЕНИЕ: стресс — единый владелец

Стресс — центральная валюta (§3, §3-bis GDD), на неё завязано всё. Худшее, что
можно сделать — раскидать изменения стресса по десяти скриптам (как hitstop в
твоей прошлой игре ломался от параллельных вызовов). Поэтому:

**`StressSystem` — Autoload, единственный, кто пишет стресс.** Все остальные
только просят его изменить через методы и слушают сигналы. Никто не трогает
переменную стресса напрямую.

```gdscript
# scripts/autoload/stress_system.gd
extends Node

signal fill_changed(current: float, ceiling: float)   # заполнение изменилось
signal ceiling_changed(ceiling: float)                # длина шкалы изменилась
signal fainted()                                       # заполнение достигло потолка

@export var balance: StressBalance   # ресурс с числами, назначить в инспекторе

var _fill: float = 0.0        # текущий стресс (заполнение), 0..ceiling
var _ceiling: float = 100.0   # длина шкалы (потолок), 50..110

func _ready() -> void:
    if balance == null:
        balance = load("res://data/balance.tres")

# --- ЗАПОЛНЕНИЕ (тактическое, в моменте) ---
func add_fill(amount: float) -> void:
    _fill = clamp(_fill + amount, 0.0, _ceiling)
    fill_changed.emit(_fill, _ceiling)
    if _fill >= _ceiling:
        _faint()

func _process(delta: float) -> void:
    # пассивная динамика: стоя +, сидя − (значения из balance)
    # кто стоит/сидит — спросим у conductor через группу или ссылку
    pass  # заполнить, когда conductor готов

# --- ДЛИНА (стратегическое, редко) ---
func change_ceiling(amount: float) -> void:
    _ceiling = clamp(_ceiling + amount, balance.ceiling_min, balance.ceiling_max)
    if _fill > _ceiling:
        _fill = _ceiling
    ceiling_changed.emit(_ceiling)
    fill_changed.emit(_fill, _ceiling)

# --- ПРОИЗВОДНОЕ: процент заполнения (для деградации восприятия) ---
func fill_ratio() -> float:
    return _fill / _ceiling if _ceiling > 0.0 else 1.0

func _faint() -> void:
    change_ceiling(-balance.faint_ceiling_loss)  # −10%
    fainted.emit()
```

**Почему Autoload:** стресс переживает смену сцен (день→лавка→день), к нему
обращаются UI, пассажиры, менеджер дня. Один владелец = невозможны рассинхроны.
`fill_ratio()` — то самое «процент от текущей длины» (§3.2 GDD), из него потом
считается деградация зоркого глаза/меток. В прототипе навыков нет, но метод
уже готов — подключишь позже.

---

## 3. ПАССАЖИР: данные отдельно от поведения

Пассажир — это **данные** (кто он, платил ли, врёт ли) + **визуал** (спрайт,
лицо на камере) + **состояние в текущем дне** (проверен, помечен). Разделяем:

```gdscript
# resources/passenger_data.gd — ШАБЛОН архетипа (.tres в data/passengers/)
class_name PassengerData extends Resource

enum Kind { HONEST_PAYER, HONEST_FORGOT, FARE_DODGER }
# HONEST_PAYER  — оплатил, покажет билет спокойно
# HONEST_FORGOT — оплатил, но билета нет (потерял/смял) → откажется показать
# FARE_DODGER   — не платил, врёт «оплатил», билета нет

@export var kind: Kind = Kind.HONEST_PAYER
@export var paid: bool = true                # платил ли на самом деле
@export var will_show_ticket: bool = true    # покажет ли по требованию
@export var dialogue_lines: Array[String] = []   # реплики
@export var face_texture: Texture2D          # лицо для камеры (заглушка ок)
@export var stress_on_refuse: float = 12.0   # если откажется (можно из balance)
```

```gdscript
# scripts/passenger.gd — ЭКЗЕМПЛЯР в вагоне (runtime-состояние)
class_name Passenger extends Node2D  # или Node3D, зависит от ракурса

var data: PassengerData
var is_checked: bool = false    # игрок уже взаимодействовал
var mark: int = 0               # 0 нет / 1 красная / 2 зелёная (метки — позже)
var slot_index: int = -1        # где сидит
var stops_remaining: int = -1   # через сколько остановок выйдет (-1 = не задано)

func setup(passenger_data: PassengerData) -> void:
    data = passenger_data
    # инициализация визуала из data

# ВАЖНО: сам пассажир НЕ меняет стресс и НЕ знает про игру целиком.
# Он только хранит своё состояние и отдаёт данные. Решения принимает
# conductor/day_manager, изменения стресса делает StressSystem.
```

**Почему шаблон + экземпляр:** `PassengerData` (.tres) — это переиспользуемые
архетипы, которых у тебя будет 3 на прототип и десятки потом. `Passenger`
(нода) — конкретный человек в вагоне с изменяемым состоянием дня. Один архетип
«заяц» → много разных зайцев в разных днях. Не хардкодь типы в код — делай .tres.

**Ключ к ядру памяти:** обрати внимание, что `is_checked` и `paid` — РАЗНЫЕ поля.
`paid` — правда о мире (платил ли). `is_checked` — знает ли игрок. Память игрока
моделируется тем, что игра НЕ показывает `paid` — игрок должен помнить сам, с кем
взаимодействовал. Не рисуй индикатор «оплачено» над головой — это убьёт ядро.

---

## 4. СЛОТЫ И ВАГОН

```gdscript
# scripts/passenger_slot.gd
class_name PassengerSlot extends Node2D  # или Node3D

@export var index: int = 0
var occupant: Passenger = null

func is_empty() -> bool:
    return occupant == null

func seat(p: Passenger) -> void:
    occupant = p
    p.slot_index = index
    add_child(p)
    # спозиционировать на сиденье

func vacate() -> void:
    if occupant:
        occupant.queue_free()
        occupant = null
```

```gdscript
# scripts/tram_car.gd — держит массив слотов, знает планировку
class_name TramCar extends Node2D

@onready var slots: Array[PassengerSlot] = []  # собрать из детей в _ready

func _ready() -> void:
    for child in get_children():
        if child is PassengerSlot:
            slots.append(child)

func free_slots() -> Array[PassengerSlot]:
    return slots.filter(func(s): return s.is_empty())

func seat_passenger(p: Passenger) -> bool:
    var free := free_slots()
    if free.is_empty():
        return false  # вагон полон
    free.pick_random().seat(p)
    return true
```

**Почему слоты — ноды в сцене, а не массив в коде:** ты расставляешь сиденья
визуально в редакторе (два ряда), а код их собирает автоматически. Меняешь
планировку вагона — двигаешь ноды, код не трогаешь. Это Godot-way: сцена — это
данные о расположении.

---

## 5. МЕНЕДЖЕР ДНЯ: оркестратор

```gdscript
# scripts/day_manager.gd — управляет ходом смены
class_name DayManager extends Node

@export var config: DayConfig       # ресурс: остановки, наплыв, длина
@export var tram: TramCar
@export var passenger_pool: Array[PassengerData]  # архетипы для этого дня

signal stop_reached(stop_index: int, stop_name: String)
signal day_ended()

var current_stop: int = 0

func _ready() -> void:
    _start_day()

func _start_day() -> void:
    # цикл остановок по таймеру/расписанию из config
    pass

func _on_stop() -> void:
    # 1. высадить тех, у кого stops_remaining дошёл до 0
    # 2. посадить новых из pool (число зависит от времени дня: пик/спад)
    # 3. эмитить stop_reached для табло
    current_stop += 1
    if current_stop >= config.total_stops:
        day_ended.emit()

func _spawn_wave(count: int) -> void:
    for i in count:
        var archetype: PassengerData = _pick_archetype()
        var p := preload("res://scenes/passenger/passenger.tscn").instantiate() as Passenger
        p.setup(archetype)
        if not tram.seat_passenger(p):
            break  # вагон полон, остальные "не влезли"

func _pick_archetype() -> PassengerData:
    # взвешенный выбор: в прототипе просто random из pool.
    # доля зайцев — из config (в обучающем дне низкая, §2.10 GDD)
    return passenger_pool.pick_random()
```

```gdscript
# resources/day_config.gd
class_name DayConfig extends Resource

@export var total_stops: int = 8
@export var seconds_per_stop: float = 45.0   # темп смены
@export var wave_min: int = 2                 # наплыв в спокойное время
@export var wave_max: int = 8                 # наплыв в пик
@export var peak_stops: Array[int] = [2, 3]   # на каких остановках пик
@export var dodger_ratio: float = 0.15        # доля зайцев (обучающий день — низкая)
@export var stop_names: Array[String] = []    # "Завод", "Больница"...
```

---

## 6. КОНДУКТОР (игрок) И ВЗАИМОДЕЙСТВИЕ

```gdscript
# scripts/conductor.gd
class_name Conductor extends CharacterBody2D  # или 3D

enum State { AT_SEAT, WALKING, INTERACTING }
var state: State = State.AT_SEAT
var target_passenger: Passenger = null

func _physics_process(delta: float) -> void:
    match state:
        State.AT_SEAT:
            StressSystem.add_fill(-balance().sit_recover * delta)  # сидя −
        State.WALKING:
            StressSystem.add_fill(balance().stand_fatigue * delta) # стоя +
            # движение к цели
        State.INTERACTING:
            StressSystem.add_fill(balance().stand_fatigue * delta) # тоже стоишь

func interact_with(p: Passenger) -> void:
    # открыть меню действий (§2.6): диалог / метка / отмена
    # в прототипе: диалог + проверка
    state = State.INTERACTING
    target_passenger = p

func resolve_check(action: String) -> void:
    var p := target_passenger
    match action:
        "collect":            # обилетить платящего
            StressSystem.add_fill(-balance().calm_ticket)
            p.is_checked = true
        "demand_ticket":
            _handle_demand(p)
        "call_police":
            _handle_police(p)

func _handle_demand(p: Passenger) -> void:
    if p.is_checked:
        # повторный запрос — гарантированное раздражение (§2.4)
        StressSystem.add_fill(balance().repeat_ask_stress)
    elif p.data.will_show_ticket:
        pass  # показал, 0 стресса
    else:
        # отказался — правда или заяц, игрок не знает
        StressSystem.add_fill(p.data.stress_on_refuse)
        # дальше игрок выбирает: настоять / сдаться

func balance() -> StressBalance:
    return StressSystem.balance
```

```gdscript
# resources/stress_balance.gd — ВСЕ числа стресса в одном ресурсе
class_name StressBalance extends Resource

# заполнение (в секунду или за событие)
@export var stand_fatigue: float = 1.0      # +/сек стоя
@export var sit_recover: float = 3.0        # −/сек сидя
@export var calm_ticket: float = 2.0        # − за спокойное обилечивание
@export var repeat_ask_stress: float = 8.0  # + за повторный запрос
@export var refuse_stress: float = 12.0     # + за отказ показать
@export var insist_success: float = -5.0    # − настоял и оказался прав
@export var police_stress: float = 25.0     # + за вызов копов
@export var catch_dodger: float = -10.0     # − поймал зайца

# длина (потолок)
@export var ceiling_min: float = 50.0
@export var ceiling_max: float = 110.0
@export var faint_ceiling_loss: float = 10.0  # −10% за обморок
```

**Здесь и живут все числа из §3.6 GDD.** Крутишь баланс — открываешь
balance.tres в инспекторе, меняешь, запускаешь. Ни строчки кода. Это главная
причина всей этой структуры.

---

## 7. ЧТО СТРОИТЬ В КАКОМ ПОРЯДКЕ (внутри прототипа)

Не пиши всё сразу. Порядок такой, чтобы каждый шаг был проверяем:

1. **Статичный вагон + слоты.** Расставь сиденья, посади вручную 3 пассажиров.
   Проверка: видно вагон, пассажиры на местах. Ещё без логики.
2. **Движение кондуктора + подход.** Ходишь, подходишь к пассажиру, жмёшь E.
   Проверка: можешь дойти до любого слота.
3. **Диалог + камера-лицо.** При подходе открывается окошко, реплики, кнопки.
   Проверка: можешь «обилетить» и вернуться.
4. **StressSystem + шкала.** Стоя копится, сидя падает, обилечивание снимает.
   Проверка: шкала живёт, ощущается ли давление «нужно садиться».
   **← ЗДЕСЬ ПЕРВЫЙ ЧЕСТНЫЙ ТЕСТ ОЩУЩЕНИЯ.**
5. **Проверка билетов + 3 архетипа.** honest/forgot/dodger, память (paid скрыт).
   Проверка: **весело ли ловить зайцев по памяти?** Главный вопрос §10 GDD.
6. **DayManager: остановки, наплыв, конец дня.** Пассажиры входят/выходят,
   табло, пик. Проверка: полный день от 5:00 до конца играется за ~10 мин.
7. **Конфликт: отказ → настоять/сдаться → копы, выговоры.** Полная ветка.
   Проверка: решения имеют вес, штраф/выговор/премия работают.

**Стоп-точка:** после шага 5 у тебя есть ответ на главный вопрос проекта.
Если «не весело» — не строй 6-7, чини ядро или пересматривай. Не полируй
то, что не увлекает в основе.

---

## 8. ЧЕГО НЕ ДЕЛАТЬ В ПРОТОТИПЕ (сознательно отложить)

- **Навыки** (зоркий глаз, пометки, хладнокровие, проницательность) — их нет в
  первом дне по дизайну. Не кодь. `fill_ratio()` уже готов принять их позже.
- **Новости, экономика, магазин, кастомизация** — сверху на ядро, не сейчас.
- **Арт и звук** — заглушки (цветные прямоугольники, лица-плейсхолдеры).
  Прототип проверяет ОЩУЩЕНИЕ механики, не картинку. Красивый скучный прототип
  обманывает тебя; уродливый увлекательный — говорит правду.
- **Сохранения, меню, настройки** — не нужны, чтобы ответить на главный вопрос.
- **Мини-игра равновесия** — вырезана из дизайна, не возвращай.

---

## 9. ГРАБЛИ GODOT, О КОТОРЫХ СТОИТ ЗНАТЬ ЗАРАНЕЕ

- **Не храни состояние в UI-нодах.** Шкала стресса — это отображение
  StressSystem, а не хранилище. UI слушает сигналы, рисует, но не владеет числом.
- **Сигналы, не polling.** Пассажир помечен, стресс изменился, остановка — всё
  через `signal`. Не проверяй состояние каждый кадр в `_process`, где можно
  подписаться на событие.
- **`preload` vs `load`:** `preload` для сцен, которые точно понадобятся
  (пассажир), `load` для того, что зависит от условий. Не грузи в цикле то, что
  можно предзагрузить один раз.
- **Класс-ресурсы (.gd с class_name extends Resource) должны существовать до
  создания .tres от них.** Сначала напиши passenger_data.gd, потом Godot даст
  создать passenger_data.tres в редакторе.
- **`Array[Type]` типизируй явно** — Godot 4 это умеет и ловит ошибки раньше.
- **Autoload регистрируется** в Project Settings → Autoload, иначе `StressSystem`
  не будет глобально доступен.

---

## 10. МОСТ К GDD

Этот файл покрывает КАК строить. Что именно строить и с какими числами — в
GDD_Conductor_Vertical_Slice.md:
- Числа стресса → §3.6 (кладутся в balance.tres, §6 здесь)
- Логика проверки/памяти → §2.4 (архетипы в §3 здесь)
- Два рычага стресса → §3-bis (заполнение/длина в StressSystem, §2 здесь)
- Что в срез входит → §10 (порядок сборки в §7 здесь)
- Что откладывается → §10 отложенные слои (§8 здесь)

Когда числа в GDD и в balance.tres разойдутся (а они разойдутся при калибровке) —
**balance.tres становится правдой**, GDD обнови задним числом или пометь как
«стартовые». Код, который играется, важнее документа.
```

---

Файл готов. Клади его в тот же project knowledge рядом с GDD и `_START_HERE.md` — три файла вместе дают новому инстансу полный контекст: зачем (GDD), как себя вести (START_HERE), и как строить (этот).

Ключевое, на что обращаю внимание, потому что это сэкономит тебе недели:

**Раздел 7 — порядок сборки — важнее всей остальной архитектуры.** Не строй по слоям «сначала весь код пассажиров, потом весь UI». Строй по шагам, где каждый *играется*. И там есть жирная стоп-точка после шага 5: как только заработает проверка билетов по памяти, у тебя будет ответ на главный вопрос проекта. Не проскакивай мимо него к полировке — остановись и честно сыграй.

**Одна вещь, которую я зашил в архитектуру нарочно** (раздел 3): поля `paid` и `is_checked` — разные. `paid` игра тебе не показывает. Соблазн будет огромный — нарисовать галочку «оплачено» над теми, кого проверил, чтобы «удобнее». Не делай этого. Ровно это — костыль, который убивает ядро памяти. Память игрока моделируется тем, что игра *молчит* о том, кто платил. Пометки (позже) — твой единственный санкционированный способ это записать, и то ценой подхода. Если в прототипе появится индикатор оплаты — ты проверяешь не ту игру.
