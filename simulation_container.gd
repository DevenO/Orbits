extends PanelContainer
func _draw():
	draw_circle(Vector2(get_rect().size.x/2,get_rect().size.y/2),min(get_rect().size.x/2,get_parent().get_parent().eRadius/get_parent().get_parent().mscale),Color(0,255,0,1))
	draw_polyline(get_parent().get_parent().plot_points,Color(255,255,255,1),1,false)
