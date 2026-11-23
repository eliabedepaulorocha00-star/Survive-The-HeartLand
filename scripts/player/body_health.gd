extends RefCounted
## Saúde por partes do corpo: ferimentos (arranhão, laceração, mordida), fraturas,
## infecção e dor. O jogador chama update() a cada frame e aplica o dano devolvido.

const ZONES := ["head", "torso", "arms", "legs"]
const ZONE_NAMES := {"head": "cabeça", "torso": "tronco", "arms": "braços", "legs": "pernas"}
const KIND_NAMES := {"scratch": "Arranhão", "laceration": "Laceração", "bite": "Mordida"}

const BITE_CHANCE := 0.10
const LACERATION_CHANCE := 0.30
const FRACTURE_CHANCE := 0.05  # só em braços e pernas
const BLEED_RATE := {"scratch": 0.12, "laceration": 0.45, "bite": 0.5}  # vida por segundo
const BLEED_STOPS_ALONE := {"scratch": 25.0}  # segundos até parar sozinho

var wounds: Array = []  # {zone, kind, bleeding, dirty, age}
var fractures := {"arms": 0, "legs": 0}  # 0 = ok, 1 = quebrado, 2 = imobilizado com tala (curando)
var splint_timer := {"arms": 0.0, "legs": 0.0}
var infection: float = 0.0  # 0..1
var bite_timer: float = -1.0  # < 0 = sem mordida; chega a 0 = zumbificação
var painkiller_time: float = 0.0


## Sorteia um ferimento causado por um golpe de zumbi. Devolve o texto para o aviso.
func hit(rng: RandomNumberGenerator) -> String:
	var zone: String = ZONES[rng.randi() % ZONES.size()]
	var roll := rng.randf()
	var kind := "scratch"
	if roll < BITE_CHANCE:
		kind = "bite"
	elif roll < BITE_CHANCE + LACERATION_CHANCE:
		kind = "laceration"
	wounds.append({"zone": zone, "kind": kind, "bleeding": true, "dirty": true, "age": 0.0})
	var msg := "%s na %s" % [KIND_NAMES[kind], ZONE_NAMES[zone]]
	if kind == "bite":
		msg = "Mordida na %s! Você foi infectado." % ZONE_NAMES[zone]
	if (zone == "arms" or zone == "legs") and fractures[zone] == 0 and rng.randf() < FRACTURE_CHANCE:
		fractures[zone] = 1
		msg += " E quebrou os %s!" % ZONE_NAMES[zone]
	return msg


## Avança o tempo. `day_s` = segundos reais de um dia de jogo.
## Devolve {"damage": vida perdida, "zombified": bool}.
func update(delta: float, day_s: float) -> Dictionary:
	var damage := 0.0
	var dirty := 0
	var keep: Array = []
	for w in wounds:
		w["age"] = float(w["age"]) + delta
		var kind: String = w["kind"]
		if bool(w["bleeding"]):
			damage += float(BLEED_RATE[kind]) * delta
			if BLEED_STOPS_ALONE.has(kind) and float(w["age"]) > float(BLEED_STOPS_ALONE[kind]):
				w["bleeding"] = false
		if bool(w["dirty"]):
			dirty += 1
		# feridas comuns cicatrizam sozinhas depois de um tempo (mordida nunca)
		var heal_after := day_s * (0.3 if kind == "scratch" else 0.6)
		if kind != "bite" and not bool(w["bleeding"]) and float(w["age"]) > heal_after:
			continue
		keep.append(w)
	wounds = keep

	if dirty > 0:
		infection = minf(1.0, infection + float(dirty) * delta / day_s)
	elif infection > 0.0:
		infection = maxf(0.0, infection - delta / (day_s * 2.0))
	if infection > 0.5:
		damage += 0.2 * delta

	for z in ["arms", "legs"]:
		if int(fractures[z]) == 2:
			splint_timer[z] = float(splint_timer[z]) - delta
			if float(splint_timer[z]) <= 0.0:
				fractures[z] = 0
	if painkiller_time > 0.0:
		painkiller_time -= delta

	var zombified := false
	if bite_timer > 0.0:
		bite_timer -= delta
		if bite_timer <= 0.0:
			zombified = true
	elif bite_timer < 0.0 and has_bite():
		bite_timer = day_s * 0.5  # meio dia de jogo até virar
	return {"damage": damage, "zombified": zombified}


func has_bite() -> bool:
	for w in wounds:
		if w["kind"] == "bite":
			return true
	return false


func bleeding_count() -> int:
	var n := 0
	for w in wounds:
		if bool(w["bleeding"]):
			n += 1
	return n


## 0..1; ferimentos e fraturas doem. Analgésico segura a dor.
func pain() -> float:
	var p := 0.0
	for w in wounds:
		p += 0.12 if w["kind"] == "scratch" else 0.25
	p += 0.3 * float(int(fractures["arms"] == 1) + int(fractures["legs"] == 1))
	if painkiller_time > 0.0:
		p *= 0.2
	return clampf(p, 0.0, 1.0)


func can_sprint() -> bool:
	return int(fractures["legs"]) == 0


func speed_factor() -> float:
	var f := 1.0
	if int(fractures["legs"]) != 0:
		f *= 0.6
	return f * (1.0 - 0.15 * pain())


func attack_factor() -> float:
	return 0.5 if int(fractures["arms"]) != 0 else 1.0


# --- Tratamentos: cada um devolve true se serviu para alguma coisa ---

## `kind_max`: "scratch" = só arranhões (curativo); "any" = qualquer ferida (bandagem).
func stop_bleeding(kind_max: String) -> bool:
	var best := -1
	for i in wounds.size():
		var w: Dictionary = wounds[i]
		if not bool(w["bleeding"]):
			continue
		if kind_max == "scratch" and w["kind"] != "scratch":
			continue
		if best == -1 or float(BLEED_RATE[w["kind"]]) > float(BLEED_RATE[wounds[best]["kind"]]):
			best = i
	if best == -1:
		return false
	wounds[best]["bleeding"] = false
	return true


func suture() -> bool:
	for w in wounds:
		if w["kind"] == "laceration" and bool(w["bleeding"]):
			w["bleeding"] = false
			return true
	return false


func disinfect() -> bool:
	var did := false
	for w in wounds:
		if bool(w["dirty"]):
			w["dirty"] = false
			did = true
	return did


func antibiotic() -> bool:
	if infection <= 0.0:
		return false
	infection = maxf(0.0, infection - 0.5)
	return true


func painkill(seconds: float) -> bool:
	if pain() <= 0.0:
		return false
	painkiller_time = seconds
	return true


func splint(day_s: float) -> bool:
	for z in ["legs", "arms"]:
		if int(fractures[z]) == 1:
			fractures[z] = 2
			splint_timer[z] = day_s * 0.3
			return true
	return false
