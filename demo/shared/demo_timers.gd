class_name PyroluxDemoTimers
extends Node
## Demo only: the little scheduler every PYROLUX demo scene runs on. A slot says "start
## the effect half a second from now, fire it again every 3 s, stop in 6 s", and when the
## slot changes every one of those is dropped in one call - which is what keeps a showcase
## from poking a node it freed two slots ago.
##
##   timers.every(3.0, 0.1, fire_once)       # repeating, first call after 0.1 s
##   timers.later(2.0, func() -> void: ...)  # one shot
##   timers.clear()                          # the slot changed
##
## Demo rule 1 (no dead air) is a statement about the numbers handed to this class: the
## first call of a slot comes within half a second.
##
## Generated from WS/shared/demo_kit/demo_timers.gd by tools/vfxpack/demo_kit_sync.py.

const DEMO_KIT_VERSION: int = 15


class Entry:
	var every: float = -1.0
	var left: float = 0.0
	var fn: Callable


var _entries: Array[Entry] = []
## Set while the start card is up, so a slot does not run its whole cycle unseen.
var paused: bool = false


func every(seconds: float, first: float, fn: Callable) -> void:
	var e: Entry = Entry.new()
	e.every = maxf(seconds, 0.016)
	e.left = first
	e.fn = fn
	_entries.append(e)


func later(seconds: float, fn: Callable) -> void:
	var e: Entry = Entry.new()
	e.left = seconds
	e.fn = fn
	_entries.append(e)


func clear() -> void:
	_entries.clear()


func count() -> int:
	return _entries.size()


func _process(delta: float) -> void:
	if paused or _entries.is_empty():
		return
	var i: int = 0
	while i < _entries.size():
		var e: Entry = _entries[i]
		e.left -= delta
		if e.left > 0.0:
			i += 1
			continue
		if e.every < 0.0:
			_entries.remove_at(i)
		else:
			e.left += e.every
			i += 1
		if e.fn.is_valid():
			e.fn.call()
