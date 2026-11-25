extends Node
## Sobrevivente do jogador (autoload "CharacterData"): aparência, profissão e traços,
## no estilo Project Zomboid. Salvo em user://character.cfg.
##
## Pontos: começa com BUDGET. Profissão e traços positivos gastam pontos;
## traços negativos devolvem pontos. Não dá para ficar com saldo negativo.

const SAVE_PATH := "user://character.cfg"
const BUDGET := 8

const SKIN_TONES := [
	Color(0.96, 0.80, 0.69), Color(0.87, 0.68, 0.53), Color(0.74, 0.53, 0.38),
	Color(0.55, 0.37, 0.26), Color(0.36, 0.24, 0.17),
]
const HAIR_COLORS := [
	Color(0.08, 0.07, 0.07), Color(0.25, 0.16, 0.10), Color(0.42, 0.28, 0.15),
	Color(0.80, 0.65, 0.33), Color(0.62, 0.27, 0.12), Color(0.55, 0.55, 0.55),
]
const CLOTH_COLORS := [
	Color(0.85, 0.85, 0.82), Color(0.10, 0.10, 0.11), Color(0.62, 0.12, 0.10),
	Color(0.15, 0.30, 0.55), Color(0.20, 0.42, 0.25), Color(0.80, 0.65, 0.20),
	Color(0.45, 0.45, 0.47), Color(0.35, 0.25, 0.15), Color(0.85, 0.45, 0.15),
	Color(0.55, 0.30, 0.55), Color(0.25, 0.32, 0.45), Color(0.60, 0.55, 0.40),
]
const HAIR_STYLES := ["Careca", "Curto", "Raspado", "Longo", "Rabo de cavalo", "Boné"]
const TOP_STYLES := ["Camiseta", "Camisa xadrez", "Moletom"]
const BOTTOM_STYLES := ["Calça jeans", "Bermuda"]

## cost: pontos gastos. mods: ver mult() / add(). items: [id, quantidade] no início.
const PROFESSIONS := [
	{"id": "unemployed", "name": "Desempregado", "cost": 0, "desc": "Sem especialidade. Só a roupa do corpo e a sorte.", "items": [], "mods": {}},
	{"id": "farmer", "name": "Fazendeiro", "cost": 2, "desc": "Acostumado a trabalho duro e a comer pouco. Começa com pá e legumes.", "items": [["shovel", 1], ["potato", 2], ["apple", 2]], "mods": {"hunger_rate": 0.85}},
	{"id": "police", "name": "Policial", "cost": 4, "desc": "Treinado para o pior. Começa com pistola, munição e lanterna.", "items": [["pistol", 1], ["ammo_9mm", 15], ["flashlight", 1], ["battery", 2]], "mods": {"melee": 1.1}},
	{"id": "nurse", "name": "Enfermeiro(a)", "cost": 3, "desc": "Sabe cuidar de ferimentos. Cura mais rápido e começa com material médico.", "items": [["first_aid_kit", 1], ["bandage", 2], ["painkillers", 1], ["antiseptic", 1]], "mods": {"regen": 1.4}},
	{"id": "mechanic", "name": "Mecânico", "cost": 2, "desc": "Mãos firmes e caixa de ferramentas na cabeça. Começa com chave inglesa e ferramentas.", "items": [["wrench", 1], ["screwdriver", 1], ["duct_tape", 1], ["flashlight", 1], ["battery", 1]], "mods": {}},
	{"id": "lumberjack", "name": "Lenhador", "cost": 3, "desc": "Forte e acostumado ao machado. Carrega mais e bate mais forte.", "items": [["axe", 1], ["rope", 1]], "mods": {"carry": 4.0, "melee": 1.1}},
	{"id": "cook", "name": "Cozinheiro", "cost": 1, "desc": "Nunca passa fome por perto de uma panela. Começa com panela, faca e isqueiro.", "items": [["pot", 1], ["kitchen_knife", 1], ["lighter", 1], ["pasta", 1], ["canned_soup", 1]], "mods": {}},
	{"id": "firefighter", "name": "Bombeiro", "cost": 4, "desc": "Em ótima forma. Mais fôlego e começa com machado.", "items": [["axe", 1], ["first_aid_kit", 1]], "mods": {"stamina_regen": 1.2, "sprint_cost": 0.85}},
	{"id": "hunter", "name": "Caçador", "cost": 4, "desc": "Conhece mato e silêncio. Começa com rifle, faca de caça e carne seca.", "items": [["hunting_rifle", 1], ["ammo_3006", 8], ["hunting_knife", 1], ["jerky", 3]], "mods": {"noise": 0.85}},
]

## cost > 0 gasta pontos (vantagem); cost < 0 devolve pontos (desvantagem).
const TRAITS := [
	{"id": "athletic", "name": "Atlético", "cost": 4, "desc": "Fôlego recupera mais rápido e correr cansa menos.", "mods": {"stamina_regen": 1.3, "sprint_cost": 0.8}, "excl": ["out_of_shape"]},
	{"id": "strong", "name": "Forte", "cost": 3, "desc": "Carrega mais peso e bate mais forte.", "mods": {"carry": 6.0, "melee": 1.2}, "excl": ["weak"]},
	{"id": "fast_healer", "name": "Cura rápida", "cost": 3, "desc": "A vida volta mais depressa.", "mods": {"regen": 2.0}, "excl": ["slow_healer"]},
	{"id": "light_eater", "name": "Come pouco", "cost": 2, "desc": "A fome chega mais devagar.", "mods": {"hunger_rate": 0.75}, "excl": ["heavy_eater"]},
	{"id": "thick_skinned", "name": "Pele grossa", "cost": 3, "desc": "Menos chance de laceração e mordida.", "mods": {"wound": 0.6}, "excl": ["thin_skinned"]},
	{"id": "stealthy", "name": "Furtivo", "cost": 2, "desc": "Faz menos barulho; zumbis te ouvem de mais perto.", "mods": {"noise": 0.7}, "excl": ["clumsy"]},
	{"id": "runner", "name": "Pé-de-vento", "cost": 3, "desc": "Anda e corre mais rápido.", "mods": {"speed": 1.08}, "excl": []},
	{"id": "out_of_shape", "name": "Fora de forma", "cost": -3, "desc": "Fôlego recupera devagar e correr cansa mais.", "mods": {"stamina_regen": 0.7, "sprint_cost": 1.3}, "excl": ["athletic"]},
	{"id": "weak", "name": "Fraco", "cost": -3, "desc": "Carrega menos e bate mais fraco.", "mods": {"carry": -5.0, "melee": 0.8}, "excl": ["strong"]},
	{"id": "slow_healer", "name": "Cura lenta", "cost": -3, "desc": "A vida volta mais devagar.", "mods": {"regen": 0.5}, "excl": ["fast_healer"]},
	{"id": "heavy_eater", "name": "Come muito", "cost": -2, "desc": "A fome chega mais rápido.", "mods": {"hunger_rate": 1.3}, "excl": ["light_eater"]},
	{"id": "thin_skinned", "name": "Pele fina", "cost": -3, "desc": "Mais chance de laceração e mordida.", "mods": {"wound": 1.4}, "excl": ["thick_skinned"]},
	{"id": "hemophiliac", "name": "Hemofílico", "cost": -4, "desc": "Sangra bem mais rápido.", "mods": {"bleed": 1.8}, "excl": []},
	{"id": "clumsy", "name": "Desastrado", "cost": -2, "desc": "Faz mais barulho ao andar.", "mods": {"noise": 1.3}, "excl": ["stealthy"]},
	{"id": "thirsty", "name": "Sempre com sede", "cost": -2, "desc": "A sede chega mais rápido.", "mods": {"thirst_rate": 1.3}, "excl": []},
]

var char_name: String = "Sobrevivente"
var female: bool = false
var use_model: bool = true  # true = sobrevivente 3D (só masculino); false = boneco personalizável
var skin: int = 1
var hair_style: int = 1
var hair_color: int = 1
var top_style: int = 0
var top_color: int = 2
var bottom_style: int = 0
var bottom_color: int = 3
var shoe_color: int = 1
var profession: String = "unemployed"
var traits: Array = []


func _ready() -> void:
	load_character()


# --- Consulta ---

func profession_data(id: String = "") -> Dictionary:
	var want := profession if id == "" else id
	for p in PROFESSIONS:
		if p["id"] == want:
			return p
	return PROFESSIONS[0]


func trait_data(id: String) -> Dictionary:
	for t in TRAITS:
		if t["id"] == id:
			return t
	return {}


func points_left() -> int:
	var left := BUDGET - int(profession_data()["cost"])
	for t in traits:
		left -= int(trait_data(str(t))["cost"])
	return left


## Liga/desliga um traço. Devolve "" se deu certo ou o motivo da recusa.
func toggle_trait(id: String) -> String:
	var t := trait_data(id)
	if t.is_empty():
		return ""
	if traits.has(id):
		if points_left() + int(t["cost"]) < 0:
			return "Sem pontos para remover esse traço negativo."
		traits.erase(id)
		return ""
	for other in t["excl"]:
		if traits.has(other):
			return "Incompatível com %s." % str(trait_data(str(other))["name"])
	if points_left() - int(t["cost"]) < 0:
		return "Pontos insuficientes."
	traits.append(id)
	return ""


func set_profession(id: String) -> String:
	var old := profession
	profession = id
	if points_left() < 0:
		profession = old
		return "Pontos insuficientes para essa profissão."
	return ""


## Modificadores multiplicativos (chaves como "melee", "noise", "regen"). 1.0 = normal.
func mult(key: String) -> float:
	var v := float(profession_data()["mods"].get(key, 1.0))
	for t in traits:
		v *= float(trait_data(str(t))["mods"].get(key, 1.0))
	return v


## Modificadores aditivos (chave "carry", em kg).
func add(key: String) -> float:
	var v := float(profession_data()["mods"].get(key, 0.0))
	for t in traits:
		v += float(trait_data(str(t))["mods"].get(key, 0.0))
	return v


func start_items() -> Array:
	return profession_data()["items"]


func appearance() -> Dictionary:
	return {
		"female": female,
		"use_model": use_model and not female,
		"skin_color": SKIN_TONES[clampi(skin, 0, SKIN_TONES.size() - 1)],
		"hair_style": hair_style,
		"hair_color": HAIR_COLORS[clampi(hair_color, 0, HAIR_COLORS.size() - 1)],
		"top_style": top_style,
		"top_color": CLOTH_COLORS[clampi(top_color, 0, CLOTH_COLORS.size() - 1)],
		"bottom_style": bottom_style,
		"bottom_color": CLOTH_COLORS[clampi(bottom_color, 0, CLOTH_COLORS.size() - 1)],
		"shoe_color": CLOTH_COLORS[clampi(shoe_color, 0, CLOTH_COLORS.size() - 1)],
	}


func randomize_look() -> void:
	female = randf() < 0.5
	skin = randi() % SKIN_TONES.size()
	hair_style = randi() % HAIR_STYLES.size()
	hair_color = randi() % HAIR_COLORS.size()
	top_style = randi() % TOP_STYLES.size()
	top_color = randi() % CLOTH_COLORS.size()
	bottom_style = randi() % BOTTOM_STYLES.size()
	bottom_color = randi() % CLOTH_COLORS.size()
	shoe_color = randi() % CLOTH_COLORS.size()


# --- Salvar e carregar ---

func save_character() -> void:
	var cfg := ConfigFile.new()
	for k in ["char_name", "female", "skin", "hair_style", "hair_color", "top_style", "top_color", "bottom_style", "bottom_color", "shoe_color", "profession", "traits", "use_model"]:
		cfg.set_value("character", k, get(k))
	cfg.save(SAVE_PATH)


func load_character() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in ["char_name", "female", "skin", "hair_style", "hair_color", "top_style", "top_color", "bottom_style", "bottom_color", "shoe_color", "profession", "traits", "use_model"]:
		if cfg.has_section_key("character", k):
			set(k, cfg.get_value("character", k))
	# Garante que um arquivo antigo/alterado não deixe o saldo negativo
	if points_left() < 0:
		profession = "unemployed"
		traits = []
