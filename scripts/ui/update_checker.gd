extends Node
## Avisa no menu principal quando existe uma build mais nova no GitHub Releases.

const BuildInfo = preload("res://scripts/ui/build_info.gd")

var _http: HTTPRequest
var _apk_url: String = ""
var _page_url: String = ""


func _ready() -> void:
	if OS.has_feature("editor") or BuildInfo.BUILD <= 0:
		return
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	_http.request("https://api.github.com/repos/%s/releases?per_page=1" % BuildInfo.REPO, ["User-Agent: SurviveTheHeartland", "Accept: application/vnd.github+json"])


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_ARRAY or data.is_empty():
		return
	var rel: Dictionary = data[0]
	var tag := str(rel.get("tag_name", ""))
	if not tag.begins_with("build-"):
		return
	var latest := int(tag.substr(6))
	if latest <= BuildInfo.BUILD:
		return
	_page_url = str(rel.get("html_url", ""))
	for a in rel.get("assets", []):
		if str(a.get("name", "")).ends_with(".apk"):
			_apk_url = str(a.get("browser_download_url", ""))
	_show_dialog(latest)


func _show_dialog(latest: int) -> void:
	var parent := get_parent()
	var layer := ColorRect.new()
	layer.color = Color(0, 0, 0, 0.6)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Atualização disponível"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var msg := Label.new()
	msg.text = "Tem uma versão nova do jogo (build %d). Você está na build %d.\nBaixe o APK e instale por cima; seu progresso salvo continua." % [latest, BuildInfo.BUILD]
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 18)
	box.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var later := Button.new()
	later.text = "Depois"
	later.custom_minimum_size = Vector2(180, 64)
	later.pressed.connect(layer.queue_free)
	row.add_child(later)
	var dl := Button.new()
	dl.text = "Baixar agora"
	dl.custom_minimum_size = Vector2(220, 64)
	dl.pressed.connect(func():
		OS.shell_open(_apk_url if _apk_url != "" else _page_url)
		layer.queue_free())
	row.add_child(dl)
