def save
	File.open(__FILE__.gsub(".rb",".dat"), "wb") do |f|
		Marshal.dump($data, f)
	end
end
begin
	include Math

	$data = {
		:origin => [],
		#:global => [],
		:target => [],
	}
	
	trainer_height = 60
	time_of_flight = 15
	
	origin = $data[:origin]
	target = $data[:target]
	
	# Create the ball sprite animation copy
	origin << [:spawn_sprite, 0]
	origin << [:set_property, 0, {z: 9_999}]
	origin << [:advance, 0, 0, 0] # Set the sprite at the original position
	origin << [:load_parameter, :ball_sprite] # Load the ball sprite
	origin << [:copy_bitmap, 0, false] # Copy the ball sprite image
	origin << [:set_src_rect, 0, 0, 0, 64, 64] # Largeur de sprite, Hauteur de sprite en fin d'array
	origin << [:set_sprite_origin_div, 0, 2, 1] # Division de quelque chose. (Inconnu, X, Y)
	origin << [:move, 0, 0, ((-trainer_height + 16 )* cos(-PI / 2 / 4) ).round ] # Le second chiffre modifie la coordonnée X de la première frame, mais la position normale reprend dès la seconde frame.
	origin << :synchronize
	target << [:spawn_sprite, 0]
	target << [:copy_bitmap, 0, false, true]
	target << [:set_property, false, {visible: false}]
	target << [:se_play, 'fall']
	
	lv = 0
	last_ball_height = 0
	time_of_flight.times do |i|
		origin << [:advance, 0, 0, 1000 * (i + 1) / time_of_flight]
		origin << [:move, 0, 0, last_ball_height = ((-trainer_height + 16) * cos(PI / 2 * (i * 4 - time_of_flight) / (time_of_flight * 4)) ).round ]
		cv = 64 * (i * 4 / time_of_flight)
		origin << [:set_src_rect, 0, 0, lv = cv] if lv != cv # Changer le second zéro rend la ball invisible à mi-course.
		origin << :synchronize
	end

	deflect_time = 5
	total_wait = deflect_time + 5
	origin << [:waitcounter, total_wait]
	origin << [:set_src_rect, 0, 0, 64 * 3]
	origin << [:move, 0, -50, -55]
	origin << [:set_sprite_origin_div, 0, -130, -110]
	origin << :synchronize
	target << [:waitcounter, total_wait]
	target << [:move, 0, -5, 0]
	target << [:se_play, '089-Attack01']
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	target << [:move, 0, -6, 0]
	origin << [:move, 0, 10, -10]
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	target << [:move, 0, -7, 0]
	origin << [:move, 0, 0, 0]
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	target << [:move, 0, 7, 0]
	origin << [:move, 0, -9, 10]
	target << [:se_play, '065-Swing04']
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	target << [:move, 0, 5, 0]
	origin << [:move, 0, -10, 15]
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	target << [:move, 0, 3, 0]
	origin << [:move, 0, -7, 12]
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	origin << [:set_src_rect, 0, 0, 64 * 2]
	target << [:move, 0, 2, 0]
	origin << [:move, 0, -6, 12]
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	target << [:move, 0, 1, 0]
	origin << [:move, 0, -6, 12]
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	origin << [:move, 0, -6, 12]
	target << [:waitcounter, total_wait += 1]
	origin << [:waitcounter, total_wait += 1]
	origin << [:set_src_rect, 0, 0, 64 * 1]
	origin << [:move, 0, -5, 13]
	origin << [:waitcounter, total_wait += 2]
	origin << [:move, 0, -5, 13]
	origin << [:waitcounter, total_wait += 2]
	origin << [:move, 0, -5, 13]
	origin << [:waitcounter, total_wait += 2]
	origin << [:move, 0, -5, 13]
	origin << [:waitcounter, total_wait += 2]
	origin << [:set_src_rect, 0, 0, 0]
	origin << [:move, 0, -5, 13]
	origin << [:waitcounter, total_wait += 2]
	origin << [:move, 0, -5, 13]
	origin << [:waitcounter, total_wait += 2]
	origin << [:move, 0, -5, 14]
	origin << :synchronize
	origin << [:waitcounter, total_wait += deflect_time]
	origin << [:terminate]
	origin << :synchronize

	
	
=begin
	origin << [:spawn_sprite, 0]
	target << [:spawn_sprite, 0, [[:visible, false]]]
	origin << [:copy_bitmap, 0, nil, true]
	origin << [:set_property, nil , [[:visible, false]]]
	target << [:load_bitmap, 0, :animation, "charge", 0]
	target << [:center, 0]
	target << [:set_sprite_origin_div,0 , 2, 2]
	target << [:waitcounter, 10]
	10.times do |i|
		origin << [:advance, 0, 0, (i+1)*2]
		origin << :synchronize
	end
	target << [:se_play, "hit", 50, 150]
	target << [:set_property, 0 , [[:visible, true]]]
	target << :synchronize
	20.times do |i|
		target << [:set_property, 0 , [[:opacity, (20-i)*255/20]]]
		target << :synchronize
		origin << [:advance, 0, 0, 19-i]
		origin << :synchronize
	end
	
	origin << [:set_property, nil , [[:visible, true]]]
	origin << [:terminate]
	origin << :synchronize
=end
	
	target << [:waitcounter, total_wait]
	target << [:set_property, false, {visible: true}]
	target << :synchronize
	origin << [:terminate]
	origin << :synchronize
	
	save
rescue Exception
	puts $!.class
	puts $!.message
	puts $!.backtrace.join("\n")
	system("pause")
end