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
		origin << [:advance, 0, 0, 1000 * (i + 1) / time_of_flight] # Le 1000 joue sur la longueur de course et sur la hauteur indirectement.
		origin << [:move, 0, 0, last_ball_height = ((-trainer_height + 16) * cos(PI / 2 * (i * 4 - time_of_flight) / (time_of_flight * 4)) ).round ] # Changer le premier 0 donne une erreur.
		cv = 64 * (i * 4 / time_of_flight)
		origin << [:set_src_rect, 0, 0, lv = cv] if lv != cv # Changer le second zéro rend la ball invisible à mi-course.
		origin << :synchronize
	end
	
	origin << [:set_src_rect, 0, 0, 64 * 4]
	
	total_wait = time_of_flight + 5
	
	origin << [:waitcounter, total_wait]
	origin << [:set_src_rect, 0, 0, 64 * 5]
	origin << [:waitcounter, total_wait += 6]
	
	glittering_wait = 6
	
	target << [:waitcounter, total_wait]
	target << [:se_play, 'pokeopen'] # Bruitage ouverture de ball
	origin << [:set_src_rect, 0, 0, 64 * 6]
	origin << [:waitcounter, total_wait += glittering_wait] # Pour synchroniser la fin de l'animation.
	origin << [:set_src_rect, 0, 0, 64 * 7]
	origin << [:waitcounter, total_wait += glittering_wait]
	origin << [:set_src_rect, 0, 0, 64 * 8]
	origin << [:waitcounter, total_wait += glittering_wait]
	(unzoom_time = 20).times do |i|
		target << [:set_property, 0, {zoom: (19 - i) / 20.0}]
		target << :synchronize
	end
	origin << [:waitcounter, total_wait] #Comme j'ai rajouté 20 frames d'animation en (2 + 6 frames x3 sprites) pendant le dézoom, j'ai enlevé le "+= unzoom_time" à la fin.)
	
	
	9.upto(14) do |i|
		origin << [:set_src_rect, 0, 0, 64 * i]
		origin << [:waitcounter, total_wait += 6]
	end
	origin << [:set_src_rect, 0, 0, 64 * 3]
	origin << [:waitcounter, total_wait += 6]
	
	# Equation tombée de la ball : abs(cos(2 * pi * x / 40)) * exp(-abs(x / 35))
	# Dérivée : - exp(i / 35.0) * cos(PI * i / 20) * (7 * PI * sin(PI * i / 20) + 4 * cos(PI * i / 20)) / (140 * cos(PI * i / 20).abs)
	
	(fall_time = 51).times do |i|
		origin << [:move, 0, 0, (- last_ball_height + 22) * exp(-i / 35.0) * cos(PI * i / 20) * (7 * PI * sin(PI * i / 20) + 4 * cos(PI * i / 20)) / (140 * cos(PI * i / 20)	.abs) ]
		
		origin << [:se_play, 'pokerebond'] if ((i - 10) % 20) == 0	# Bruitage rebond de ball
		origin << :synchronize
	end
	
	suspence_time = 30
	
	origin << [:waitcounter, total_wait += (fall_time + suspence_time)]
	
	
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