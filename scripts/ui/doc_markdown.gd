class_name DocMarkdown
extends RefCounted
# Minimal Markdown -> BBCode converter for the in-game Operation Manual.
# Keeps assets/ui/document.md as the single editable source of truth (owned by
# the Document Designer) and renders it to a RichTextLabel at runtime.
#
# Supports: headers (#, ##, ###), **bold**, *italic*, numbered + bulleted lists,
# the manual's LaTeX ordinals ($1^{\text{st}}$ -> 1st), and pages split on `---`.

const INK := "#2b2622"          # body ink
const INK_HEADER := "#1c1714"   # darker stamped-ink headers
const WARN := "#8a1f12"         # alarm red for WARNING lines

# Header font sizes at scale 1.0; scaled down per page so a long page still
# fits a single sheet without scrolling.
const H1 := 40
const H2 := 30
const H3 := 24

static var _re_number: RegEx = _compile("^([0-9]+)\\.\\s+(.*)$")
static var _re_ord: RegEx = _compile("\\$([0-9]+)\\^\\{\\\\text\\{([A-Za-z]+)\\}\\}\\$")
static var _re_bold: RegEx = _compile("\\*\\*(.+?)\\*\\*")
static var _re_italic: RegEx = _compile("\\*(.+?)\\*")
# Liner notes: the Document Designer marks gameplay hints as "(Liner Note: ...)".
# We pull them off the page body and render them as the previous-operator's
# handwritten margin scribble instead.
static var _re_liner: RegEx = _compile("\\*?\\(\\s*Liner Note:\\s*(.*?)\\)\\*?")


static func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	re.compile(pattern)
	return re


# Returns an Array of { "title", "bbcode", "raw", "note": String }.
static func load_pages(path: String) -> Array:
	var pages: Array = []
	if not FileAccess.file_exists(path):
		return pages
	var text := FileAccess.get_file_as_string(path)
	for chunk in _split_pages(text):
		var stripped: String = String(chunk).strip_edges()
		if stripped.is_empty():
			continue
		pages.append({
			"title": _first_header(stripped),
			"bbcode": to_bbcode(stripped),
			"raw": stripped,
			"note": _collect_notes(stripped),
		})
	return pages


# Pull every "(Liner Note: ...)" out of a page and join them into one scribble.
static func _collect_notes(chunk: String) -> String:
	var notes: PackedStringArray = []
	for m in _re_liner.search_all(chunk):
		var n := m.get_string(1).strip_edges()
		if not n.is_empty():
			notes.append(n)
	return "\n\n".join(notes)


static func _split_pages(text: String) -> Array:
	var pages: Array = []
	var current: PackedStringArray = []
	for line in text.split("\n"):
		if line.strip_edges() == "---":
			pages.append("\n".join(current))
			current = PackedStringArray()
		else:
			current.append(line)
	pages.append("\n".join(current))
	return pages


static func _first_header(chunk: String) -> String:
	for line in chunk.split("\n"):
		var t := _re_liner.sub(line, "", true).strip_edges()
		if t.begins_with("#"):
			return t.lstrip("#").strip_edges()
	return "Operation Manual"


static func to_bbcode(chunk: String, scale: float = 1.0) -> String:
	var out: PackedStringArray = []
	for line in chunk.split("\n"):
		out.append(_line_to_bbcode(line, scale))
	return "\n".join(out)


static func _line_to_bbcode(line: String, scale: float) -> String:
	# Liner notes live in the margin, not the body — pull them out first.
	var raw := _re_liner.sub(line, "", true).rstrip(" \t")
	var t := raw.strip_edges()
	if t.is_empty():
		return ""

	if t.begins_with("### "):
		return "[font_size=%d][b][i]%s[/i][/b][/font_size]" % [_sized(H3, scale), _inline(t.substr(4))]
	if t.begins_with("## "):
		return "[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [_sized(H2, scale), INK_HEADER, _inline(t.substr(3))]
	if t.begins_with("# "):
		return "[center][font_size=%d][b][color=%s]%s[/color][/b][/font_size][/center]" % [_sized(H1, scale), INK_HEADER, _inline(t.substr(2))]

	var numbered := _re_number.search(t)
	if numbered != null:
		return "  [b]%s.[/b] %s" % [numbered.get_string(1), _inline(numbered.get_string(2))]

	if t.begins_with("- "):
		var indent := _leading_spaces(raw)
		var pad := "    ".repeat(1 + indent / 3)
		return "%s• %s" % [pad, _maybe_warn(t, _inline(t.substr(2)))]

	return _maybe_warn(t, _inline(t))


# Paint anything that shouts WARNING in alarm red.
static func _maybe_warn(source: String, body: String) -> String:
	if source.find("WARNING") != -1:
		return "[color=%s]%s[/color]" % [WARN, body]
	return body


static func _inline(s: String) -> String:
	var r := _re_ord.sub(s, "$1$2", true)
	# Scrub any stray LaTeX that wasn't a clean ordinal.
	r = r.replace("\\text{", "").replace("^{", "").replace("{", "").replace("}", "").replace("$", "")
	r = _re_bold.sub(r, "[b]$1[/b]", true)
	r = _re_italic.sub(r, "[i]$1[/i]", true)
	return r


static func _sized(base: int, scale: float) -> int:
	return maxi(1, int(round(base * scale)))


static func _leading_spaces(s: String) -> int:
	var count := 0
	for i in s.length():
		if s[i] == " ":
			count += 1
		else:
			break
	return count
