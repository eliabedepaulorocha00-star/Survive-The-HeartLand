extends Node
## Banco de itens (autoload "ItemDB") e tabelas de loot por tipo de lugar.
##
## Cada item é um Dictionary com as chaves:
##   id, name, cat, w (peso em kg), desc, dur (durabilidade máxima; 0 = não gasta)
## e, conforme o tipo:
##   food / water / heal  -> o que o item restaura ao comer, beber ou usar (escala 0-100)
##   harm                 -> dano à vida ao consumir (água suja)
##   returns              -> id do item que sobra depois de consumir (garrafa/lata vazia)
##   equip, dmg, range, cost, cd, len, head -> armas (dano, alcance em m, custo de stamina, recarga em s)
##   ammo, mag            -> armas de fogo (o tiro em si chega na Fase 6)
##   dismantle, needs     -> o que sai ao desmontar e a ferramenta necessária
##   later                -> o efeito só existe quando a saúde por partes do corpo chegar
## Itens com durabilidade não empilham; os outros empilham por id.

const CAT_NAMES := {
	"melee": "Arma branca",
	"firearm": "Arma de fogo",
	"ammo": "Munição",
	"food": "Comida",
	"drink": "Bebida",
	"medical": "Médico",
	"tool": "Ferramenta",
	"material": "Material",
	"cloth": "Tecido",
}

const CAT_COLORS := {
	"melee": Color(0.62, 0.60, 0.58),
	"firearm": Color(0.25, 0.26, 0.30),
	"ammo": Color(0.80, 0.62, 0.20),
	"food": Color(0.78, 0.30, 0.20),
	"drink": Color(0.28, 0.55, 0.85),
	"medical": Color(0.90, 0.90, 0.92),
	"tool": Color(0.88, 0.55, 0.15),
	"material": Color(0.50, 0.45, 0.38),
	"cloth": Color(0.55, 0.62, 0.50),
}

## Cada entrada: [id do item, peso do sorteio, quantidade mínima, quantidade máxima]
const LOOT := {
	"kitchen": {
		"rolls": [3, 6],
		"items": [
			["canned_beans", 10, 1, 2], ["canned_corn", 8, 1, 2], ["canned_soup", 8, 1, 2],
			["canned_tuna", 6, 1, 2], ["canned_meat", 5, 1, 1], ["canned_peaches", 5, 1, 1],
			["cereal_bar", 7, 1, 3], ["crackers", 6, 1, 1], ["bread", 5, 1, 1],
			["pasta", 6, 1, 1], ["peanut_butter", 5, 1, 1], ["cereal", 5, 1, 1],
			["chocolate", 3, 1, 1], ["jerky", 4, 1, 2], ["water_bottle", 8, 1, 1],
			["soda", 5, 1, 1], ["juice", 4, 1, 1], ["sweet_tea", 4, 1, 1],
			["kitchen_knife", 4, 1, 1], ["frying_pan", 3, 1, 1], ["pot", 3, 1, 1],
			["matches", 3, 1, 1], ["lighter", 2, 1, 1], ["potato", 4, 1, 3],
			["apple", 3, 1, 2], ["egg", 3, 1, 3], ["carrot", 2, 1, 2],
			["tomato", 2, 1, 2], ["corn_cob", 2, 1, 2],
		],
	},
	"bedroom": {
		"rolls": [2, 5],
		"items": [
			["tshirt", 10, 1, 2], ["jeans", 8, 1, 1], ["bedsheet", 7, 1, 1],
			["blanket", 6, 1, 1], ["curtain", 3, 1, 1], ["painkillers", 5, 1, 1],
			["adhesive", 4, 1, 2], ["flashlight", 5, 1, 1], ["battery", 6, 1, 3],
			["radio", 3, 1, 1], ["map", 3, 1, 1], ["golf_club", 2, 1, 1],
			["bat", 3, 1, 1], ["revolver", 1, 1, 1], ["ammo_38", 2, 6, 12],
			["chocolate", 3, 1, 1], ["water_bottle", 3, 1, 1], ["sleeping_bag", 1, 1, 1],
		],
	},
	"bathroom": {
		"rolls": [2, 5],
		"items": [
			["bandage", 10, 1, 3], ["adhesive", 8, 1, 3], ["antiseptic", 7, 1, 1],
			["painkillers", 8, 1, 1], ["antibiotics", 3, 1, 1], ["vitamins", 5, 1, 1],
			["suture_kit", 2, 1, 1], ["first_aid_kit", 3, 1, 1], ["splint", 2, 1, 1],
			["rag", 3, 1, 2], ["water_bottle", 2, 1, 1],
		],
	},
	"garage": {
		"rolls": [3, 6],
		"items": [
			["hammer", 7, 1, 1], ["wrench", 7, 1, 1], ["screwdriver", 8, 1, 1],
			["crowbar", 4, 1, 1], ["saw", 4, 1, 1], ["pipe", 4, 1, 1],
			["nails", 8, 1, 1], ["wire", 6, 1, 1], ["rope", 5, 1, 1],
			["duct_tape", 6, 1, 1], ["gas_can", 4, 1, 1], ["battery", 5, 1, 2],
			["flashlight", 4, 1, 1], ["plank", 3, 1, 1], ["sledgehammer", 1, 1, 1],
			["shovel", 2, 1, 1], ["scrap", 5, 1, 2], ["axe", 2, 1, 1],
			["lighter", 3, 1, 1], ["pitchfork", 1, 1, 1], ["radio", 1, 1, 1],
			["water_bottle", 2, 1, 1],
		],
	},
	"vehicle": {
		"rolls": [2, 4],
		"items": [
			["map", 8, 1, 1], ["flashlight", 5, 1, 1], ["battery", 5, 1, 2],
			["screwdriver", 4, 1, 1], ["wrench", 4, 1, 1], ["crowbar", 3, 1, 1],
			["gas_can", 3, 1, 1], ["rope", 3, 1, 1], ["duct_tape", 4, 1, 1],
			["water_bottle", 5, 1, 1], ["soda", 4, 1, 1], ["cereal_bar", 4, 1, 2],
			["first_aid_kit", 3, 1, 1], ["adhesive", 3, 1, 2], ["radio", 2, 1, 1],
			["compass", 3, 1, 1], ["bourbon", 2, 1, 1], ["pistol", 1, 1, 1],
			["ammo_9mm", 1, 5, 15], ["tshirt", 3, 1, 1], ["blanket", 2, 1, 1],
		],
	},
	"police": {
		"rolls": [3, 6],
		"items": [
			["pistol", 6, 1, 1], ["ammo_9mm", 10, 8, 20], ["revolver", 3, 1, 1], ["sw_victory", 3, 1, 1], ["m3_grease", 1, 1, 1], ["reising", 1, 1, 1],
			["ammo_38", 6, 6, 12], ["shotgun", 3, 1, 1], ["ammo_12ga", 7, 4, 10],
			["flashlight", 6, 1, 1], ["bandage", 4, 1, 2], ["first_aid_kit", 3, 1, 1],
			["crowbar", 3, 1, 1], ["radio", 4, 1, 1], ["battery", 5, 1, 3],
			["chocolate", 3, 1, 1], ["donut", 6, 1, 2],
		],
	},
	"pharmacy": {
		"rolls": [4, 8],
		"items": [
			["bandage", 10, 1, 4], ["adhesive", 9, 1, 3], ["antiseptic", 8, 1, 2],
			["painkillers", 9, 1, 2], ["antibiotics", 6, 1, 1], ["vitamins", 6, 1, 2],
			["suture_kit", 3, 1, 1], ["splint", 3, 1, 1], ["first_aid_kit", 4, 1, 1],
			["water_bottle", 4, 1, 1], ["juice", 3, 1, 1], ["cereal_bar", 3, 1, 2],
		],
	},
	"farm": {
		"rolls": [3, 6],
		"items": [
			["pitchfork", 4, 1, 1], ["shovel", 5, 1, 1], ["axe", 4, 1, 1],
			["rope", 6, 1, 1], ["wire", 6, 1, 1], ["nails", 5, 1, 1],
			["plank", 4, 1, 1], ["gas_can", 5, 1, 1], ["corn_cob", 8, 1, 3],
			["potato", 6, 1, 3], ["carrot", 4, 1, 2], ["apple", 4, 1, 3],
			["tomato", 4, 1, 2], ["egg", 5, 1, 4], ["milk", 3, 1, 1],
			["hunting_rifle", 1, 1, 1], ["enfield", 1, 1, 1], ["m42", 1, 1, 1], ["ammo_3006", 2, 3, 8], ["shotgun", 1, 1, 1],
			["ammo_12ga", 3, 3, 8], ["rifle_22", 2, 1, 1], ["ammo_22", 4, 6, 15],
			["bourbon", 3, 1, 1], ["water_bottle", 4, 1, 1], ["jeans", 3, 1, 1],
			["tshirt", 3, 1, 1], ["sweet_tea", 3, 1, 1], ["machete", 2, 1, 1],
			["hammer", 3, 1, 1],
		],
	},
	"roadside": {
		"rolls": [1, 1],
		"items": [
			["tshirt", 4, 1, 1], ["can_empty", 6, 1, 1], ["bottle_empty", 6, 1, 1],
			["rag", 5, 1, 1], ["scrap", 5, 1, 1], ["soda", 3, 1, 1],
			["cereal_bar", 3, 1, 1], ["adhesive", 2, 1, 1], ["battery", 3, 1, 1],
			["lighter", 2, 1, 1], ["matches", 2, 1, 1], ["canned_beans", 2, 1, 1],
			["apple", 2, 1, 1], ["nails", 3, 1, 1], ["wire", 3, 1, 1],
			["pipe", 2, 1, 1], ["kitchen_knife", 1, 1, 1], ["water_bottle", 3, 1, 1],
			["map", 1, 1, 1], ["painkillers", 1, 1, 1],
		],
	},
	"generic": {
		"rolls": [1, 3],
		"items": [
			["canned_beans", 4, 1, 1], ["water_bottle", 4, 1, 1], ["bandage", 3, 1, 1],
			["cereal_bar", 4, 1, 1], ["battery", 3, 1, 1], ["rag", 4, 1, 2],
			["hammer", 2, 1, 1], ["bat", 1, 1, 1],
		],
	},
}

## Receitas: inputs são consumidos; tools ficam (use "a|b" para "um ou outro").
const RECIPES := [
	{"id": "bandage", "inputs": [["rag", 2]], "tools": [], "outputs": [["bandage", 1]]},
	{"id": "splint", "inputs": [["plank", 1], ["rag", 2]], "tools": [], "outputs": [["splint", 1]]},
	{"id": "nail_plank", "inputs": [["plank", 1], ["nails", 1]], "tools": ["hammer"], "outputs": [["nail_plank", 1]]},
	{"id": "boil_water", "inputs": [["dirty_water", 1]], "tools": ["pot", "lighter|matches"], "outputs": [["water_bottle", 1]]},
	{"id": "cook_potato", "inputs": [["potato", 1]], "tools": ["pot", "lighter|matches"], "outputs": [["cooked_potato", 1]]},
	{"id": "cook_egg", "inputs": [["egg", 1]], "tools": ["pot", "lighter|matches"], "outputs": [["boiled_egg", 1]]},
	{"id": "cook_corn", "inputs": [["corn_cob", 1]], "tools": ["pot", "lighter|matches"], "outputs": [["cooked_corn", 1]]},
	{"id": "cook_pasta", "inputs": [["pasta", 1], ["water_bottle", 1]], "tools": ["pot", "lighter|matches"], "outputs": [["cooked_pasta", 1], ["bottle_empty", 1]]},
]

var items: Dictionary = {}


func _init() -> void:
	_build_melee()
	_build_firearms()
	_build_food()
	_build_cooked()
	_build_drinks()
	_build_medical()
	_build_tools()
	_build_materials()
	_build_combat()


# --- Consulta ---

func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func has_item(id: String) -> bool:
	return items.has(id)


func name_of(id: String) -> String:
	var d := get_item(id)
	return str(d["name"]) if not d.is_empty() else id


func weight_of(id: String) -> float:
	var d := get_item(id)
	return float(d["w"]) if not d.is_empty() else 0.0


func max_durability_of(id: String) -> float:
	var d := get_item(id)
	return float(d["dur"]) if not d.is_empty() else 0.0


func is_stackable(id: String) -> bool:
	return max_durability_of(id) <= 0.0


func is_weapon(id: String) -> bool:
	return bool(get_item(id).get("equip", false))


func is_firearm(id: String) -> bool:
	return get_item(id).has("ammo")


func color_of(id: String) -> Color:
	var d := get_item(id)
	if d.is_empty():
		return Color(0.6, 0.6, 0.6)
	if d.has("color"):
		return d["color"]
	return CAT_COLORS.get(d["cat"], Color(0.6, 0.6, 0.6))


func cat_name(id: String) -> String:
	var d := get_item(id)
	if d.is_empty():
		return ""
	return str(CAT_NAMES.get(d["cat"], ""))


func fmt_weight(w: float) -> String:
	if w < 0.1:
		return "%.2f kg" % w
	return "%.1f kg" % w


## Texto de detalhe do item (descrição + números que importam).
func describe(id: String) -> String:
	var d := get_item(id)
	if d.is_empty():
		return ""
	var lines: Array[String] = []
	if str(d["desc"]) != "":
		lines.append(str(d["desc"]))
	if d.has("food"):
		lines.append("Fome: +%d" % int(d["food"]))
	if d.has("water"):
		lines.append("Sede: %+d" % int(d["water"]))
	if d.has("heal"):
		lines.append("Vida: +%d" % int(d["heal"]))
	if d.has("harm"):
		lines.append("Faz mal: -%d de vida" % int(d["harm"]))
	if d.has("ammo"):
		var shots := "%dx " % int(d["pellets"]) if int(d["pellets"]) > 1 else ""
		lines.append("Dano: %s%d  |  Alcance: %d m  |  Atravessa: %d" % [shots, int(d["dmg"]), int(d["range"]), int(d["pierce"])])
		lines.append("Munição: %s (pente %d)  |  Recarga: %.1f s" % [name_of(str(d["ammo"])), int(d["mag"]), float(d["reload"])])
		lines.append("Barulho: %d m  |  Coice: %.0f" % [int(d["noise"]), float(d["recoil"])])
	elif d.has("dmg"):
		lines.append("Dano: %d  |  Alcance: %.1f m  |  Arco: %d°" % [int(d["dmg"]), float(d.get("range", 2.0)), int(d.get("arc", 90))])
		if d.has("knock"):
			lines.append("Derruba: %d%%  |  Velocidade: %.2f s/golpe" % [int(float(d["knock"]) * 100.0), float(d.get("cd", 0.5))])
	if d.has("dismantle"):
		var parts: Array[String] = []
		for p in d["dismantle"]:
			parts.append("%dx %s" % [int(p[1]), name_of(str(p[0]))])
		var line := "Desmontar: " + ", ".join(PackedStringArray(parts))
		if d.has("needs"):
			line += " (precisa de %s)" % name_of(str(d["needs"]))
		lines.append(line)
	if bool(d.get("later", false)):
		lines.append("Ainda sem efeito.")
	return "\n".join(PackedStringArray(lines))


# --- Receitas ---

func recipe_title(r: Dictionary) -> String:
	var parts: Array[String] = []
	for o in r["outputs"]:
		parts.append("%dx %s" % [int(o[1]), name_of(str(o[0]))])
	return ", ".join(PackedStringArray(parts))


func recipe_needs(r: Dictionary) -> String:
	var parts: Array[String] = []
	for i in r["inputs"]:
		parts.append("%dx %s" % [int(i[1]), name_of(str(i[0]))])
	var line := ", ".join(PackedStringArray(parts))
	var tl: Array[String] = []
	for t in r["tools"]:
		var names: Array[String] = []
		for alt in str(t).split("|"):
			names.append(name_of(alt))
		tl.append(" ou ".join(PackedStringArray(names)))
	if not tl.is_empty():
		line += "  | precisa de: " + ", ".join(PackedStringArray(tl))
	return line


# --- Loot ---

## Sorteia o conteúdo de um recipiente. Devolve entradas {"id", "n", "dur"}.
func roll_loot(table_name: String, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var table: Dictionary = LOOT.get(table_name, LOOT["generic"])
	var pool: Array = table["items"]
	var total := 0.0
	for entry in pool:
		total += float(entry[1])
	var rolls := rng.randi_range(int(table["rolls"][0]), int(table["rolls"][1]))
	var result: Array = []
	for r in rolls:
		var pick := rng.randf() * total
		for entry in pool:
			pick -= float(entry[1])
			if pick <= 0.0:
				_add_loot(result, str(entry[0]), rng.randi_range(int(entry[2]), int(entry[3])), rng)
				break
	return result


func _add_loot(result: Array, id: String, n: int, rng: RandomNumberGenerator) -> void:
	if not has_item(id) or n <= 0:
		return
	if is_stackable(id):
		for e in result:
			if e["id"] == id:
				e["n"] = int(e["n"]) + n
				return
		result.append({"id": id, "n": n, "dur": 0.0})
	else:
		var max_dur := max_durability_of(id)
		for i in n:
			result.append({"id": id, "n": 1, "dur": max_dur * rng.randf_range(0.35, 1.0)})


# --- Definição dos itens ---

func _add(id: String, nm: String, cat: String, w: float, extra: Dictionary = {}) -> void:
	var d := {"id": id, "name": nm, "cat": cat, "w": w, "desc": "", "dur": 0.0}
	d.merge(extra, true)
	items[id] = d


func _melee(id: String, nm: String, w: float, dmg: float, reach: float, cost: float, cd: float, dur: float, length: float, extra: Dictionary = {}, cat: String = "melee") -> void:
	var d := {"dmg": dmg, "range": reach, "cost": cost, "cd": cd, "dur": dur, "len": length, "equip": true}
	d.merge(extra, true)
	_add(id, nm, cat, w, d)


func _gun(id: String, nm: String, w: float, ammo_id: String, mag: int, dmg: float, length: float, desc: String, extra: Dictionary = {}) -> void:
	var d := {
		"equip": true, "ammo": ammo_id, "mag": mag, "dmg": dmg, "dur": 100.0,
		"len": length, "desc": desc, "color": Color(0.22, 0.23, 0.27),
		"cd": 0.4, "reload": 2.0, "pellets": 1, "pierce": 1, "recoil": 4.0, "spread": 1.5, "noise": 90.0, "range": 45.0,
	}
	d.merge(extra, true)
	_add(id, nm, "firearm", w, d)


func _food(id: String, nm: String, w: float, food: float, extra: Dictionary = {}) -> void:
	var d := {"food": food}
	d.merge(extra, true)
	_add(id, nm, "food", w, d)


func _build_melee() -> void:
	var wood := Color(0.55, 0.38, 0.20)
	var steel := Color(0.70, 0.70, 0.72)
	_melee("bat", "Taco de beisebol", 1.2, 34.0, 2.3, 12.0, 0.55, 60.0, 0.85, {"color": wood, "desc": "Pesado e confiável. O melhor amigo de quem mora no interior."})
	_melee("axe", "Machado", 2.2, 58.0, 2.2, 20.0, 0.85, 55.0, 0.8, {"color": wood, "head": true, "desc": "Lento, mas derruba um zumbi em dois golpes."})
	_melee("machete", "Facão", 1.0, 44.0, 2.1, 12.0, 0.5, 70.0, 0.65, {"color": steel, "desc": "Rápido e afiado."})
	_melee("kitchen_knife", "Faca de cozinha", 0.3, 22.0, 1.6, 6.0, 0.35, 45.0, 0.3, {"color": steel, "desc": "Curta, mas gasta pouca stamina."})
	_melee("hunting_knife", "Faca de caça", 0.4, 30.0, 1.7, 7.0, 0.38, 80.0, 0.35, {"color": steel, "desc": "Resistente e silenciosa."})
	_melee("crowbar", "Pé de cabra", 1.5, 38.0, 2.2, 14.0, 0.6, 90.0, 0.75, {"color": Color(0.35, 0.12, 0.10), "desc": "Quase não quebra. Também abre coisas trancadas (em breve)."})
	_melee("frying_pan", "Frigideira", 1.0, 24.0, 2.0, 10.0, 0.5, 50.0, 0.45, {"color": Color(0.18, 0.18, 0.20), "head": true, "desc": "Faz um barulhão. Funciona."})
	_melee("shovel", "Pá", 1.8, 36.0, 2.4, 15.0, 0.7, 60.0, 1.0, {"color": wood, "head": true, "desc": "Alcance bom. Também serve para cavar (em breve)."})
	_melee("pipe", "Cano de ferro", 1.4, 30.0, 2.3, 12.0, 0.55, 100.0, 0.8, {"color": Color(0.45, 0.45, 0.48), "desc": "Duro de quebrar."})
	_melee("pitchfork", "Forcado", 2.0, 40.0, 2.7, 16.0, 0.7, 40.0, 1.2, {"color": wood, "head": true, "desc": "Mantém o zumbi longe. Coisa de fazenda."})
	_melee("nail_plank", "Tábua com pregos", 1.0, 36.0, 2.1, 12.0, 0.5, 20.0, 0.8, {"color": Color(0.45, 0.32, 0.20), "desc": "Improvisada. Quebra rápido."})
	_melee("golf_club", "Taco de golfe", 0.8, 24.0, 2.4, 9.0, 0.45, 40.0, 0.9, {"color": steel, "desc": "Leve e com bom alcance."})
	_melee("sledgehammer", "Marreta", 4.0, 70.0, 2.0, 28.0, 1.1, 70.0, 0.9, {"color": Color(0.30, 0.30, 0.32), "head": true, "desc": "Devastadora, e te deixa exausto."})
	_melee("hammer", "Martelo", 0.9, 28.0, 1.9, 10.0, 0.45, 70.0, 0.35, {"color": wood, "head": true, "desc": "Serve de arma e de ferramenta."}, "tool")
	_melee("wrench", "Chave inglesa", 1.0, 26.0, 2.0, 10.0, 0.45, 80.0, 0.45, {"color": Color(0.60, 0.60, 0.64), "desc": "Serve de arma e de ferramenta."}, "tool")


func _build_firearms() -> void:
	_gun("revolver", "Revólver .38", 1.0, "ammo_38", 6, 45.0, 0.22, "Seis tiros e muita fé.", {"cd": 0.5, "reload": 2.8, "recoil": 5.5, "spread": 1.4, "noise": 100.0})
	_gun("pistol", "Pistola 9mm", 0.9, "ammo_9mm", 15, 35.0, 0.22, "Carregador grande, dano médio.", {"cd": 0.28, "reload": 1.6, "recoil": 3.2, "spread": 2.0, "noise": 90.0})
	_gun("shotgun", "Espingarda calibre 12", 3.2, "ammo_12ga", 5, 20.0, 0.9, "8 chumbos por tiro, atinge vários zumbis. Barulhenta.", {"cd": 0.95, "reload": 3.4, "pellets": 8, "pierce": 1, "recoil": 9.0, "spread": 6.0, "noise": 140.0, "range": 24.0})
	_gun("hunting_rifle", "Rifle de caça .30-06", 3.6, "ammo_3006", 5, 110.0, 0.95, "Alcance e dano; atravessa até 2 zumbis. Se ouve a 200 m.", {"cd": 1.1, "reload": 3.0, "pierce": 2, "recoil": 7.0, "spread": 0.6, "noise": 200.0, "range": 90.0})
	_gun("rifle_22", "Rifle .22", 2.5, "ammo_22", 10, 28.0, 0.8, "Fraco, mas faz pouco barulho e tem muita munição.", {"cd": 0.5, "reload": 2.2, "recoil": 2.2, "spread": 0.8, "noise": 45.0, "range": 60.0})

	_gun("sw_victory", "Revólver S&W Victory", 1.1, "ammo_38", 6, 48.0, 0.24, "Revólver de serviço, firme e confiável.", {"cd": 0.5, "reload": 2.6, "recoil": 5.0, "spread": 1.2, "noise": 100.0})
	_gun("enfield", "Rifle M1917 Enfield", 4.1, "ammo_3006", 6, 105.0, 1.1, "Ferrolho robusto de guerra. Atravessa até 2 zumbis.", {"cd": 1.0, "reload": 3.2, "pierce": 2, "recoil": 7.0, "spread": 0.7, "noise": 200.0, "range": 85.0})
	_gun("m3_grease", "Submetralhadora M3", 3.6, "ammo_9mm", 30, 28.0, 0.57, "Cadência alta e muito barulho.", {"cd": 0.13, "reload": 2.4, "recoil": 2.6, "spread": 3.2, "noise": 110.0, "range": 35.0})
	_gun("reising", "Submetralhadora Reising M50", 3.1, "ammo_9mm", 20, 30.0, 0.8, "Leve e precisa para uma submetralhadora.", {"cd": 0.15, "reload": 2.2, "recoil": 2.4, "spread": 2.6, "noise": 105.0, "range": 38.0})
	_gun("m42", "Submetralhadora M42", 3.3, "ammo_9mm", 25, 29.0, 0.8, "Coronha de madeira e carregador reto.", {"cd": 0.14, "reload": 2.3, "recoil": 2.5, "spread": 2.8, "noise": 108.0, "range": 36.0})

	_add("ammo_38", "Munição .38", "ammo", 0.02, {"desc": "Para revólveres."})
	_add("ammo_9mm", "Munição 9mm", "ammo", 0.015, {"desc": "Para pistolas."})
	_add("ammo_12ga", "Cartuchos calibre 12", "ammo", 0.04, {"desc": "Para espingardas."})
	_add("ammo_3006", "Munição .30-06", "ammo", 0.03, {"desc": "Para rifles de caça."})
	_add("ammo_22", "Munição .22", "ammo", 0.01, {"desc": "Para rifles pequenos."})


func _build_food() -> void:
	_food("canned_beans", "Feijão enlatado", 0.45, 25.0, {"returns": "can_empty", "desc": "Dura uma eternidade."})
	_food("canned_corn", "Milho enlatado", 0.40, 22.0, {"returns": "can_empty"})
	_food("canned_soup", "Sopa enlatada", 0.40, 20.0, {"water": 6.0, "returns": "can_empty"})
	_food("canned_tuna", "Atum em lata", 0.20, 18.0, {"returns": "can_empty"})
	_food("canned_meat", "Carne enlatada", 0.35, 28.0, {"returns": "can_empty"})
	_food("canned_peaches", "Pêssego em calda", 0.40, 16.0, {"water": 8.0, "returns": "can_empty"})
	_food("cereal_bar", "Barra de cereal", 0.08, 10.0)
	_food("crackers", "Bolachas", 0.20, 15.0)
	_food("bread", "Pão de forma", 0.50, 24.0)
	_food("pasta", "Macarrão", 0.50, 12.0, {"desc": "Cru não rende. Melhor cozinhar (crafting, parte 2)."})
	_food("peanut_butter", "Pasta de amendoim", 0.40, 22.0)
	_food("cereal", "Cereal matinal", 0.40, 18.0)
	_food("chocolate", "Chocolate", 0.10, 8.0)
	_food("donut", "Rosquinha", 0.10, 9.0, {"desc": "Clássico da delegacia."})
	_food("jerky", "Carne seca", 0.10, 14.0, {"desc": "Leve e rende bastante."})
	_food("apple", "Maçã", 0.15, 8.0, {"water": 3.0})
	_food("carrot", "Cenoura", 0.10, 6.0, {"water": 2.0})
	_food("potato", "Batata", 0.20, 7.0, {"desc": "Cozida rende mais (crafting, parte 2)."})
	_food("corn_cob", "Espiga de milho", 0.25, 10.0)
	_food("tomato", "Tomate", 0.15, 5.0, {"water": 4.0})
	_food("egg", "Ovo", 0.06, 5.0, {"desc": "Cru. Melhor cozinhar (crafting, parte 2)."})


## Arco do golpe (graus) e chance de derrubar o zumbi, por arma branca.
func _build_combat() -> void:
	var arcs := {"bat": 120, "axe": 110, "machete": 125, "kitchen_knife": 60, "hunting_knife": 65, "crowbar": 100, "frying_pan": 110, "shovel": 100, "pipe": 100, "pitchfork": 50, "nail_plank": 100, "golf_club": 110, "sledgehammer": 140, "hammer": 80, "wrench": 80}
	var knocks := {"bat": 0.35, "axe": 0.2, "machete": 0.1, "kitchen_knife": 0.0, "hunting_knife": 0.0, "crowbar": 0.3, "frying_pan": 0.35, "shovel": 0.3, "pipe": 0.3, "pitchfork": 0.15, "nail_plank": 0.3, "golf_club": 0.2, "sledgehammer": 0.7, "hammer": 0.2, "wrench": 0.2}
	for id in arcs:
		items[id]["arc"] = arcs[id]
		items[id]["knock"] = knocks[id]


func _build_cooked() -> void:
	_food("cooked_potato", "Batata cozida", 0.20, 22.0)
	_food("boiled_egg", "Ovo cozido", 0.06, 14.0)
	_food("cooked_corn", "Milho cozido", 0.25, 20.0)
	_food("cooked_pasta", "Macarrão cozido", 0.50, 38.0)


func _build_drinks() -> void:
	_add("water_bottle", "Garrafa de água", "drink", 0.5, {"water": 40.0, "returns": "bottle_empty", "desc": "Água limpa."})
	_add("soda", "Refrigerante", "drink", 0.35, {"water": 15.0, "food": 5.0, "returns": "can_empty"})
	_add("juice", "Suco de caixinha", "drink", 0.25, {"water": 20.0, "food": 4.0})
	_add("sweet_tea", "Chá gelado", "drink", 0.5, {"water": 30.0, "food": 3.0, "returns": "bottle_empty", "desc": "Bem doce, como manda o Sul."})
	_add("milk", "Leite", "drink", 0.5, {"water": 15.0, "food": 8.0, "returns": "bottle_empty"})
	_add("bourbon", "Bourbon", "drink", 0.8, {"water": -10.0, "returns": "bottle_empty", "desc": "Esquenta, mas desidrata. Pode virar desinfetante (parte 2)."})
	_add("dirty_water", "Água suja", "drink", 0.5, {"water": 30.0, "harm": 6.0, "returns": "bottle_empty", "desc": "Mata a sede, mas faz mal. Ferva antes (crafting, parte 2)."})


func _build_medical() -> void:
	_add("bandage", "Bandagem", "medical", 0.05, {"stop_bleed": "any", "desc": "Estanca um sangramento (o pior primeiro)."})
	_add("adhesive", "Curativo", "medical", 0.02, {"stop_bleed": "scratch", "desc": "Só dá conta de arranhões."})
	_add("vitamins", "Vitaminas", "medical", 0.05, {"heal": 3.0, "food": 2.0})
	_add("first_aid_kit", "Kit de primeiros socorros", "medical", 0.8, {"heal": 35.0, "stop_bleed": "any", "disinfect": true, "desc": "Cura, estanca um sangramento e desinfeta."})
	_add("antiseptic", "Antisséptico", "medical", 0.15, {"disinfect": true, "desc": "Desinfeta os ferimentos e evita infecção."})
	_add("painkillers", "Analgésico", "medical", 0.05, {"painkill": true, "desc": "Alivia a dor por um tempo."})
	_add("antibiotics", "Antibiótico", "medical", 0.05, {"antibiotic": true, "desc": "Reduz a infecção. Não cura mordida de zumbi."})
	_add("splint", "Tala", "medical", 0.4, {"splint": true, "desc": "Imobiliza uma fratura; depois de um tempo ela cura."})
	_add("suture_kit", "Kit de sutura", "medical", 0.15, {"suture": true, "desc": "Fecha uma laceração que sangra."})


func _build_tools() -> void:
	_add("flashlight", "Lanterna", "tool", 0.3, {"dismantle": [["battery", 1]], "needs": "screwdriver", "desc": "Ilumina a noite (em breve)."})
	_add("battery", "Pilha", "tool", 0.03, {"desc": "Energia para lanternas e rádios."})
	_add("lighter", "Isqueiro", "tool", 0.05, {"desc": "Acende fogueiras (crafting, parte 2)."})
	_add("matches", "Fósforos", "tool", 0.02, {"desc": "Acendem fogueiras (crafting, parte 2)."})
	_add("rope", "Corda", "tool", 0.5, {"desc": "Útil em armadilhas e construção."})
	_add("duct_tape", "Fita adesiva", "tool", 0.2, {"desc": "Conserta quase tudo."})
	_add("wire", "Arame", "tool", 0.2, {"desc": "Para cercas e armadilhas."})
	_add("nails", "Caixa de pregos", "tool", 0.3, {"desc": "Para barricadas."})
	_add("plank", "Tábua", "tool", 2.0, {"desc": "Para barricar janelas."})
	_add("saw", "Serra", "tool", 0.8, {"dur": 80.0, "desc": "Serra tábuas e galhos."})
	_add("screwdriver", "Chave de fenda", "tool", 0.2, {"desc": "Necessária para desmontar eletrônicos."})
	_add("map", "Mapa da região", "tool", 0.05, {"desc": "Mostra o condado (em breve)."})
	_add("radio", "Rádio portátil", "tool", 0.6, {"dismantle": [["battery", 1], ["circuit", 1]], "needs": "screwdriver", "desc": "Chia estática."})
	_add("pot", "Panela", "tool", 0.8, {"desc": "Para cozinhar e ferver água (crafting, parte 2)."})
	_add("gas_can", "Galão de gasolina", "tool", 3.0, {"desc": "Combustível para veículos e geradores."})
	_add("compass", "Bússola", "tool", 0.1, {"desc": "Aponta o norte."})
	_add("fishing_rod", "Vara de pescar", "tool", 0.8, {"desc": "Comida de graça perto de rios (em breve)."})
	_add("sleeping_bag", "Saco de dormir", "tool", 2.0, {"desc": "Para descansar fora de casa (em breve)."})


func _build_materials() -> void:
	_add("rag", "Trapo", "material", 0.05, {"desc": "Vira bandagem (crafting, parte 2)."})
	_add("circuit", "Placa eletrônica", "material", 0.1)
	_add("scrap", "Sucata de metal", "material", 0.5)
	_add("bottle_empty", "Garrafa vazia", "material", 0.1, {"desc": "Pode ser enchida com água (parte 2)."})
	_add("can_empty", "Lata vazia", "material", 0.05)

	_add("bedsheet", "Lençol", "cloth", 0.6, {"dismantle": [["rag", 4]], "desc": "Rasgue para fazer trapos."})
	_add("blanket", "Cobertor", "cloth", 1.0, {"dismantle": [["rag", 6]], "desc": "Rasgue para fazer trapos."})
	_add("tshirt", "Camiseta velha", "cloth", 0.2, {"dismantle": [["rag", 2]], "desc": "Rasgue para fazer trapos."})
	_add("curtain", "Cortina", "cloth", 0.5, {"dismantle": [["rag", 3]], "desc": "Rasgue para fazer trapos."})
	_add("jeans", "Calça jeans", "cloth", 0.5, {"dismantle": [["rag", 3]], "desc": "Rasgue para fazer trapos."})
