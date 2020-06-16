extends MarginContainer
#variables  used in global calculations
const mu = 3.9860050883e14 #GM constant for earth
const eRadius = 6378140 #earth radius, in m
const mumoon = 4.902794e12 #GM constant for the moon
const mRadius = 1737400 #moon radius, in m

#moon's orbital path parameters. Assuming fixed, pre-determined path for now
var moon_perigee = 376805182.0 #assumed to start at perigee, and at 0 degree position
var moon_apogee = 376805182.0 #assuming circular orbit for simplicity, for now. This sets period to approximately the right value
var moon_omega = 2*PI/(655.71986459790094*60*60) #This is the angular velocity, which is fixed for a circular orbit. The period is pulled from the simulator manually, then converted to seconds
var moon_x = 0.0 #x coordinate in meters for moon position from earth's center
var moon_y = 0.0 #y coordinate in meters for moon position from earth's center

#current satellite parameters
var altitude = 0.0 #meters, current height above surface level
var radius = 0.0 #meters, from center of body
var velocity = 0.0 #meters/second
var zenith = 0.0 #radians
var apogee = 0.0 #meters, from center of body
var perigee = 0.0 #meters, from center of body
var v_apogee = 0.0 #meters/second
var v_perigee = 0.0 #meters/second
var current_angle = 0.0 #radians
var apogee_angle = 0.0 #radians
var true_anomaly = 0.0 #radians
var semi_major = 0.0 #meters
var eccentricity = 0.0
var period = 0.0 #seconds

#mode 1=basic, 2=perigee, 3=apogee, 4=no velocity. Used to update values spinboxes
var mode = 1 #set to  basic mode as default, just like the spinbox editable defaults

#plotting parameters
var mscale = 0.0 #meters / pixel to fit on screen
var path_points = PoolVector2Array() #the points of the path ellipse (m)
var plot_points = PoolVector2Array() #the points of the path ellipse (pixels)

#simulation parameters
var active = false #set to true when the start button is pressed
var steps_per_frame = 500 #number of iterations to do per PHYSICS frame, which is always 60/sec
var dt = 0.1 #interval between iterations. Not between frames - that is this value times steps_per_frame
var stopwatch_time = 0.0 #can be reset by user, elapsed simulation (not actual) time, seconds
var return_to_parameters = false #set to true when return to parameters button is pressed. This ensures the current iteration finishes before returning.
var time = 0.0 #cannot be reset, elapsed simulation (not actual) time, seconds
var moon_on = true #include moon in sim or no?

#new "Current" values for satellite
var g_acc = 0.0 #acceleration due to gravity, magnitude (earth)
var g_theta = 0.0 #direction of acceleration due to gravity (earth)
var g_moon_acc = 0.0 #acceleration due to gravity, magnitude (moon)
var g_moon_theta = 0.0 #direction of acceleration due to gravity (moon)

var max_alt = 0.0 #maximum altitude acheived
var min_alt = 0.0 #minimum altitude acheived

var x_pos = 0.0 #x and y parameters of the satellite. Cannot be arrays in Godot due to 32-bit limitation, which I think affects the simulation
var x_pos_f = 0.0
var x_vel = 0.0
var x_vel_f = 0.0
var x_acc = 0.0
var x_acc_f = 0.0
var y_pos = 0.0
var y_pos_f = 0.0
var y_vel = 0.0
var y_vel_f = 0.0
var y_acc = 0.0
var y_acc_f = 0.0
var future_radius = 0.0 #other important "future" values for the simulation. "Current" values will pull from original variables
var g_future_acc = 0.0
var g_future_theta = 0.0
var moon_x_f = 0.0
var moon_y_f = 0.0
var g_future_moon_acc = 0.0
var g_future_moon_theta = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	#initial values for SpinBoxes, block signals
	for i in $H/start_menu/values/spinboxes.get_children():
		i.set_block_signals(true)
	$H/start_menu/values/spinboxes/altitude.value = 375000000.0
	$H/start_menu/values/spinboxes/velocity.value = 200.0
	$H/start_menu/values/spinboxes/zenith.value = 90
	$H/start_menu/values/spinboxes/start_angle.value = 0
	for i in $H/start_menu/values/spinboxes.get_children():
		i.set_block_signals(false)
	
	#run initial update
	_value_update(0)

#Toggle button actions
func _on_basic_option_toggled(button_pressed):
	if (button_pressed):
		$H/start_menu/values/spinboxes/altitude.editable = true
		$H/start_menu/values/spinboxes/velocity.editable = true
		$H/start_menu/values/spinboxes/zenith.editable = true
		$H/start_menu/values/spinboxes/start_angle.editable = true
		$H/start_menu/values/spinboxes/perigee.editable = false
		$H/start_menu/values/spinboxes/apogee.editable = false
		$H/start_menu/values/spinboxes/apogee_angle.editable = false
		mode = 1

func _on_perigee_option_toggled(button_pressed):
	if (button_pressed):
		$H/start_menu/values/spinboxes/altitude.editable = false
		$H/start_menu/values/spinboxes/velocity.editable = true
		$H/start_menu/values/spinboxes/zenith.editable = false
		$H/start_menu/values/spinboxes/start_angle.editable = true
		$H/start_menu/values/spinboxes/perigee.editable = true
		$H/start_menu/values/spinboxes/apogee.editable = false
		$H/start_menu/values/spinboxes/apogee_angle.editable = false
		mode = 2

func _on_apogee_option_toggled(button_pressed):
	if (button_pressed):
		$H/start_menu/values/spinboxes/altitude.editable = false
		$H/start_menu/values/spinboxes/velocity.editable = true
		$H/start_menu/values/spinboxes/zenith.editable = false
		$H/start_menu/values/spinboxes/start_angle.editable = true
		$H/start_menu/values/spinboxes/perigee.editable = false
		$H/start_menu/values/spinboxes/apogee.editable = true
		$H/start_menu/values/spinboxes/apogee_angle.editable = false
		mode = 3

func _on_no_v_option_toggled(button_pressed):
	if (button_pressed):
		$H/start_menu/values/spinboxes/altitude.editable = false
		$H/start_menu/values/spinboxes/velocity.editable = false
		$H/start_menu/values/spinboxes/zenith.editable = false
		$H/start_menu/values/spinboxes/start_angle.editable = false
		$H/start_menu/values/spinboxes/perigee.editable = true
		$H/start_menu/values/spinboxes/apogee.editable = true
		$H/start_menu/values/spinboxes/apogee_angle.editable = true
		mode = 4

#Update all values function
func _value_update(value):
	altitude = $H/start_menu/values/spinboxes/altitude.value
	radius = altitude + eRadius
	velocity = $H/start_menu/values/spinboxes/velocity.value
	zenith = deg2rad($H/start_menu/values/spinboxes/zenith.value)
	current_angle = deg2rad($H/start_menu/values/spinboxes/start_angle.value)
	apogee = $H/start_menu/values/spinboxes/apogee.value + eRadius
	perigee = $H/start_menu/values/spinboxes/perigee.value + eRadius
	apogee_angle = deg2rad($H/start_menu/values/spinboxes/apogee_angle.value)
	
	#make sure apogee is greater than perigee
	if apogee < perigee:
		apogee = perigee
	
	#calculate other values based on the toggled input switch
	match(mode):
		1:
			#prevent errors
			if (altitude == 0 or velocity == 0):
				pass
			else:
				#utilize apogee / perigee calc, Braeunig example problem 4.8
				#uses start radius, velocity, and zenith
				var C = 2*mu/(radius*pow(velocity,2))
				var a = radius * (-C + pow(pow(C,2)-4*(1-C)*(-sin(zenith)*sin(zenith)),0.5))/(2*(1-C))
				var p = radius * (-C - pow(pow(C,2)-4*(1-C)*(-sin(zenith)*sin(zenith)),0.5))/(2*(1-C))
				if a > p:
					perigee = p
					apogee = a
				else:
					perigee = a
					apogee = p
				#prevent errors
				if  (perigee == 0 or apogee == 0):
					pass
				else:
					#utilize true anomaly calc, wikipedia
					semi_major = (apogee + perigee)/2
					v_apogee = pow((2*mu*perigee)/(apogee*(apogee+perigee)),0.5)
					v_perigee = pow((2*mu*apogee)/(perigee*(apogee+perigee)),0.5)
					eccentricity = (perigee*v_perigee*v_perigee)/mu - 1
					if eccentricity == 0:
						eccentricity = 1
					if zenith == PI/2: #prevent errors with true anomaly at exactly 0 or 180
						if round(perigee) == round(radius):
							true_anomaly = 0
						else:
							true_anomaly = PI
					else:
						if zenith < PI/2:
							true_anomaly = acos(((semi_major/radius)*(1-pow(eccentricity,2))-1)/eccentricity)
						else:
							true_anomaly = -acos(((semi_major/radius)*(1-pow(eccentricity,2))-1)/eccentricity)
					apogee_angle = true_anomaly + current_angle - PI
					if apogee_angle < 0:
						apogee_angle = apogee_angle + 2*PI
		2:
			if (velocity == 0 or perigee == 0):
				pass
			else:
				#assumption is that input velocity and position indicate perigee values
				radius = perigee
				altitude = radius - eRadius
				zenith = PI/2
				v_perigee = velocity
				apogee_angle = current_angle + PI
				
				#utilize Braeunig equation 4.18 to calculate apogee
				apogee = perigee/(((2*mu)/(perigee*v_perigee*v_perigee))-1)
		3:
			if (velocity == 0 or perigee == 0):
				pass
			else:
				#assumption is that input velocity and position indicate apogee values
				radius = apogee
				altitude = radius - eRadius
				zenith = PI/2
				v_apogee = velocity
				apogee_angle = current_angle
				
				#utilize Braeunig equation 4.19 to calculate perigee
				perigee = apogee/(((2*mu)/(apogee*v_apogee*v_apogee))-1)
		4:
			if (apogee == 0 or perigee == 0):
				pass
			else:
				#for now, assumption is starting point is perigee, for simplicty
				radius = perigee
				altitude = radius - eRadius
				#Utilize Braeunig 4.16 and 4.17 to calc Vp and Va
				v_perigee = pow((2*mu*apogee)/(perigee*(apogee+perigee)),0.5)
				v_apogee = pow((2*mu*perigee)/(apogee*(apogee+perigee)),0.5)
				
				velocity = v_perigee
				zenith = PI/2
				current_angle = apogee_angle - PI
	
	#period is always the same, regardless of mode - for now
	semi_major = (apogee + perigee) / 2
	period = 2*PI*pow(pow(semi_major,3)/mu,0.5)
	$H/start_menu/values/spinboxes/period.value = period/3600 #display hours
	
	#don't trigger emit signal when this block sets values
	for i in $H/start_menu/values/spinboxes.get_children():
		i.set_block_signals(true)
	$H/start_menu/values/spinboxes/altitude.value = altitude
	$H/start_menu/values/spinboxes/velocity.value = velocity
	$H/start_menu/values/spinboxes/zenith.value = rad2deg(zenith)
	$H/start_menu/values/spinboxes/start_angle.value = rad2deg(current_angle)
	$H/start_menu/values/spinboxes/perigee.value = perigee - eRadius
	$H/start_menu/values/spinboxes/apogee.value = apogee - eRadius
	$H/start_menu/values/spinboxes/apogee_angle.value = rad2deg(apogee_angle)
	#turn signals back on
	for i in $H/start_menu/values/spinboxes.get_children():
		i.set_block_signals(false)
		
	#all parameters set, so calculate ellipse path, update draw function
	_calc_path()
	$H/simulation_container.update()
	g_theta = current_angle + PI
	var x = $H/simulation_container.get_rect().size.x/2+radius*sin(g_theta)/mscale
	var y = $H/simulation_container.get_rect().size.y/2+radius*cos(g_theta)/mscale
	$H/simulation_container/Node2D.position = Vector2(x,y)
	$H/simulation_container/Moon.position = Vector2($H/simulation_container.get_rect().size.x/2,$H/simulation_container.get_rect().size.y/2-moon_perigee/mscale) #moon always starts at 0 degrees at perigee
	$H/simulation_container/Moon.update()

#calculate the predicted orbital path
func _calc_path():
	path_points.resize(0)
	plot_points.resize(0)
	
	#calculate ellipse parameters
	var semi_minor = pow(apogee*perigee,0.5)
	var foci_distance = pow(pow(semi_major,2)-pow(semi_minor,2),0.5)
	
	#calculate plot path points
	path_points.append(Vector2(-semi_major+foci_distance,0))
	var temp = 0.0
	for i in range(-semi_major,semi_major,semi_major/100):
		temp = pow((semi_minor*semi_minor)/(semi_major*semi_major)*(semi_major*semi_major-i*i),0.5)
		if is_nan(temp):
			temp = 0
		path_points.append(Vector2(i+foci_distance,temp))
		path_points.append(Vector2(i+foci_distance,temp))
	var path_size = path_points.size()
	for i in path_size:
			path_points.append(Vector2(path_points[path_size-i-1].x,-path_points[path_size-i-1].y))	
	plot_points.resize(path_points.size())
	
	#rotate plot path points
	var rotate_angle = apogee_angle - 3*PI/2
	var xtemp
	var ytemp
	var counter = 0
	for i in path_points:
		xtemp = i.x
		ytemp = i.y
		path_points[counter].x = xtemp*cos(rotate_angle) - ytemp*sin(rotate_angle)
		path_points[counter].y = ytemp*cos(rotate_angle) + xtemp*sin(rotate_angle)
		counter += 1
	
	mscale = apogee*2.4/min($H/simulation_container.get_rect().size.x, $H/simulation_container.get_rect().size.y)
	counter = 0
	for i in path_points:
		plot_points[counter].x = $H/simulation_container.get_rect().size.x/2 + i.x/mscale
		plot_points[counter].y = $H/simulation_container.get_rect().size.y/2 - i.y/mscale
		counter += 1

#SIMULATION FUNCTIONS start here
#what happens when the sim start button is pressed
func _on_sim_start_button_up():
	#in case nothing ran this prior to pressing the button
	_value_update(0)
	#change visibility
	$H/start_menu.visible = false
	$running_menu.visible = true
	
	#redraw due to new window size.
	yield(get_tree().create_timer(0.01),"timeout")
	_calc_path()
	$H/simulation_container.update()
	var x = $H/simulation_container.get_rect().size.x/2+radius*sin(g_theta)/mscale
	var y = $H/simulation_container.get_rect().size.y/2+radius*cos(g_theta)/mscale
	$H/simulation_container/Node2D.position = Vector2(x,y)
	
	#fade in new menu
	var temp = 0
	while temp <= 1.05:
		$running_menu.modulate.a = temp
		temp = temp + 0.5
		yield(get_tree().create_timer(0.05), "timeout")
	
	
	#start the physics simulation
	active = true
	x_pos = radius*sin(-current_angle)
	y_pos = radius*cos(-current_angle)
	x_vel = velocity*sin(-current_angle+zenith)
	y_vel = velocity*cos(-current_angle+zenith)
	g_acc = mu/pow(radius,2)
	g_theta = current_angle + PI
	
	if (moon_on):
		moon_x = moon_apogee*sin(-moon_omega*time)
		moon_y = moon_apogee*cos(-moon_omega*time)
		if (x_pos == 0 and moon_x == 0):
			g_moon_acc = mumoon/pow(y_pos-moon_y,2)
		elif (y_pos == 0 and moon_y == 0):
			g_moon_acc = mumoon/pow(x_pos-moon_x,2)
		else:
			g_moon_acc = mumoon/pow(pow(pow(x_pos-moon_x,2)+pow(y_pos-moon_y,2),0.5),2)
		g_moon_theta = atan2(moon_y-y_pos,moon_x-x_pos)-PI/2
	else:
		g_moon_acc = 0.0
	
	x_acc = -g_acc*sin(g_theta) - g_moon_acc*sin(g_moon_theta)
	y_acc = g_acc*cos(g_theta) + g_moon_acc*cos(g_moon_theta)
	max_alt = altitude
	min_alt = altitude
	$running_menu/H/values/max_altitude.text = str(max_alt)
	$running_menu/H/values/min_altitude.text = str(min_alt)
	$running_menu/pause.text = "Pause"

#Physics simulation, processed 60 times / second
func _physics_process(delta):
	if active == false: #don't run if not active
		if return_to_parameters == true: #return to parameters if button has been pressed
			
			#don't trigger emit signal when this block sets values. Only need to set things that have changed during the simulation
			for i in $H/start_menu/values/spinboxes.get_children():
				i.set_block_signals(true)
			$H/start_menu/values/spinboxes/altitude.value = altitude
			$H/start_menu/values/spinboxes/velocity.value = velocity
			$H/start_menu/values/spinboxes/zenith.value = rad2deg(zenith)
			$H/start_menu/values/spinboxes/start_angle.value = rad2deg(current_angle)
			#turn signals back on
			for i in $H/start_menu/values/spinboxes.get_children():
				i.set_block_signals(false)
			
			$running_menu.visible = false #disable visibility of simulation info layer
			$H/start_menu.visible = true

			#redraw due to new window size.
			yield(get_tree().create_timer(0.01),"timeout")
			_calc_path()
			$H/simulation_container.update()
			var x = $H/simulation_container.get_rect().size.x/2+radius*sin(g_theta)/mscale
			var y = $H/simulation_container.get_rect().size.y/2+radius*cos(g_theta)/mscale
			$H/simulation_container/Node2D.position = Vector2(x,y)
			return_to_parameters = false #only need to run this section once
		else:
			pass
	else: #the bulk of the physics using Velocity Verlet
		var i=0
		while i < steps_per_frame:
			x_pos_f = x_pos + x_vel * dt + 0.5 * x_acc * dt * dt
			y_pos_f = y_pos + y_vel * dt + 0.5 * y_acc * dt * dt
	
			future_radius = pow(pow(x_pos_f,2)+pow(y_pos_f,2),0.5)
			g_future_acc = mu/pow(future_radius,2)
			g_future_theta = atan2(y_pos_f,x_pos_f) + PI/2
	
			if (moon_on):
				moon_x_f = moon_apogee*sin(-moon_omega*(time+dt))
				moon_y_f = moon_apogee*cos(-moon_omega*(time+dt))
				if (x_pos_f == 0 and moon_x_f == 0):
					g_future_moon_acc = mumoon/pow(y_pos_f-moon_y_f,2)
				elif (y_pos_f == 0 and moon_y_f == 0):
					g_future_moon_acc = mumoon/pow(x_pos_f-moon_x_f,2)
				else:
					g_future_moon_acc = mumoon/pow(pow(pow(x_pos_f-moon_x_f,2)+pow(y_pos_f-moon_y_f,2),0.5),2)
				g_future_moon_theta = atan2(moon_y_f-y_pos_f,moon_x_f-x_pos_f)-PI/2
			else:
				g_future_moon_acc = 0.0
			
			x_acc_f = -g_future_acc*sin(g_future_theta) - g_future_moon_acc*sin(g_future_moon_theta)
			y_acc_f = g_future_acc*cos(g_future_theta) + g_future_moon_acc*cos(g_future_moon_theta)
	
			x_vel_f = x_vel + 0.5 * (x_acc + x_acc_f) * dt
			y_vel_f = y_vel + 0.5 * (y_acc + y_acc_f) * dt
	
			x_pos = x_pos_f
			x_vel = x_vel_f
			x_acc = x_acc_f
			y_pos = y_pos_f
			y_vel = y_vel_f
			y_acc = y_acc_f

			radius = future_radius
			g_acc = g_future_acc
			g_theta = g_future_theta
	
			moon_x = moon_x_f
			moon_y = moon_y_f
			g_moon_acc = g_future_moon_acc
			g_moon_theta = g_future_moon_theta
	
			stopwatch_time += dt
			time += dt
			i += 1
			#check max and min radii
			if (radius-eRadius) > max_alt:
				max_alt = radius-eRadius
				$running_menu/H/values/max_altitude.text = str(max_alt)
			elif (radius-eRadius) < min_alt:
				min_alt = radius-eRadius
				$running_menu/H/values/min_altitude.text = str(min_alt)

		altitude = radius - eRadius
		$running_menu/H/values/altitude.text = str(altitude)
		velocity = pow(pow(x_vel,2)+pow(y_vel,2),0.5)
		$running_menu/H/values/velocity.text = str(velocity)
		zenith = asin((perigee*v_perigee)/(radius*velocity))
		if zenith != zenith: #check for divide by zero
			zenith = PI/2
		
		zenith = PI - (atan2(y_vel,x_vel) - PI/2) + g_theta
		if zenith > 2*PI:
			zenith = zenith - 2*PI
		
		current_angle = atan2(y_pos,x_pos)-(PI/2)
		if current_angle < 0:
			current_angle = current_angle + 2*PI
		$running_menu/H/values/position_angle.text = str(rad2deg(current_angle))
		var x = $H/simulation_container.get_rect().size.x/2+radius*sin(g_theta)/mscale
		var y = $H/simulation_container.get_rect().size.y/2+radius*cos(g_theta)/mscale
		$H/simulation_container/Node2D.position = Vector2(x,y)
		x = $H/simulation_container.get_rect().size.x/2+moon_x/mscale
		y = $H/simulation_container.get_rect().size.y/2-moon_y/mscale
		$H/simulation_container/Moon.position = Vector2(x,y)
		$running_menu/H/values/stopwatch_time_elapsed.text = str(stopwatch_time/3600) #display in hours
		$running_menu/H/values/zenith_angle.text = str(rad2deg(zenith))
		steps_per_frame = $running_menu/H/values/steps_per_frame.value

func _on_reset_mixmax_button_up():
	min_alt = altitude
	$running_menu/H/values/min_altitude.text = str(min_alt)
	max_alt = altitude
	$running_menu/H/values/max_altitude.text = str(max_alt)

func _on_reset_time_button_up():
	stopwatch_time = 0
	$running_menu/H/values/stopwatch_time_elapsed.text = str(stopwatch_time/3600)

func _on_pause_button_up():
	if active == true:
		active = false
		$running_menu/pause.text = "Unpause"
	else:
		active = true
		$running_menu/pause.text = "Pause"

func _on_return_to_parameters_button_up():
	active = false
	return_to_parameters = true

func _on_moon_on_button_button_up():
	if moon_on:
		moon_on = false
		$H/simulation_container/Moon.visible = false
		dt = 0.01
		$running_menu/return_to_parameters.disabled = false
	else:
		moon_on = true
		$H/simulation_container/Moon.visible = true
		dt = 0.1
		$running_menu/return_to_parameters.disabled = true
