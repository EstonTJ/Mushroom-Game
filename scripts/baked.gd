extends Node2D
## A drawing layer that is painted once into an off-screen image and then shown
## as that image every frame. Use it for scenery that rarely changes: a phone
## browser can't afford to re-process thousands of shapes every frame, but it
## can show one picture. Call refresh() when the scenery does change.

var painter: Callable
var viewport: SubViewport
var canvas: Node2D
var sprite: Sprite2D
## How long the last repaint took, for performance checks.
var last_usec := 0


class Canvas extends Node2D:
	var owner_layer

	func _draw() -> void:
		var start := Time.get_ticks_usec()
		owner_layer.painter.call(self)
		owner_layer.last_usec = Time.get_ticks_usec() - start


func _init(p: Callable, size: Vector2i = Vector2i(720, 1280)) -> void:
	painter = p
	viewport = SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	canvas = Canvas.new()
	canvas.owner_layer = self
	viewport.add_child(canvas)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = viewport.get_texture()
	add_child(sprite)


## Repaint the scenery on the next frame.
func refresh() -> void:
	canvas.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
