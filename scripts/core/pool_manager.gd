extends Node
## Reuses frequently spawned nodes (popups, puffs, polaroids, decoy birds).
## Released nodes are parked, hidden, under this autoload until reused.

var created_count := 0
var _pools: Dictionary = {}


func acquire(scene: PackedScene, parent: Node) -> Node:
	var key := scene.resource_path
	var pool: Array = _pools.get(key, [])
	var node: Node = null
	while node == null and not pool.is_empty():
		var candidate: Variant = pool.pop_back()
		if is_instance_valid(candidate):
			node = candidate
	if node == null:
		node = scene.instantiate()
		node.set_meta("pool_key", key)
		created_count += 1
		parent.add_child(node)
	else:
		node.reparent(parent, false)
		node.process_mode = Node.PROCESS_MODE_INHERIT
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	return node


func release(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var key: String = node.get_meta("pool_key", "")
	if key == "":
		node.queue_free()
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.get_parent() != self:
		node.reparent(self, false)
	if not _pools.has(key):
		_pools[key] = []
	(_pools[key] as Array).append(node)


func pooled_count(scene: PackedScene) -> int:
	return (_pools.get(scene.resource_path, []) as Array).size()
