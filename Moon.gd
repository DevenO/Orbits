extends Node2D
func _draw():
	draw_circle(Vector2(0,0),get_parent().get_parent().get_parent().mRadius/get_parent().get_parent().get_parent().mscale,Color(0,0,255,1))
