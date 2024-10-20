def save
  File.open(__FILE__.gsub(".rb",".dat"), "wb") do |f|
    Marshal.dump($data, f)
  end
end


EMPTY = { max_counter: 1, loop: false, data: [] }
$data = []
# Particles for tag 0
$data[0] = {}
# Particles for tag 1
$data[1] = {}
# Grass particle
$data[0][1] = {
  enter: {
    max_counter: 7,
    data: [
      { file: 'tall-grass', rect: [0, 0, 16, 16], zoom: 1, position: :grass_pos, se_player_play: 'audio/particles/step_tall-grass' },
      { wait: 3 },
      { rect: [16, 0, 16, 16] },
      { wait: 3 },
      { rect: [32, 0, 16, 16] },
      { wait: 3 },
      { rect: [48, 0, 16, 16] }
    ],
    loop: false
  },
  stay: {
    max_counter: 1,
    data: [
      { file: 'tall-grass', zoom: 1, position: :grass_pos, rect: [48, 0, 16, 16] }
    ],
    loop: false
  },
  leave: {
    max_counter: 1,
    data: [],
    loop: false
  }
}

# Taller grass particle
$data[0][2] = {
  enter: {
    max_counter: 8,
    data: [
      nil, nil, nil,
      { file: 'long-grass', zoom: 1, position: :grass_pos, add_z: 2, se_player_play: 'audio/particles/step_tall-grass' }
    ],
    loop: false
  },
  stay: {
    max_counter: 1,
    data: [
      { file: 'long-grass', zoom: 1, add_z: 2, position: :grass_pos }
    ],
    loop: false
  },
  leave: {
    max_counter: 1,
    data: [],
    loop: false
  }
}

# Exclamation emotion particle
$data[0][:exclamation] = {
  enter: {
    max_counter: 36,
    data: [
      { file: 'emotions', rect: [0, 0, 16, 16], zoom: 1, position: :center_pos, add_z: -1, oy_offset: 0, se_play: 'audio/particles/se_exclamation'},
      nil, {oy_offset: 2},
      nil, {oy_offset: 4},
      nil, {oy_offset: 8},
      nil, {oy_offset: 12},
      nil, {oy_offset: 16, add_z: 64},
      nil, {oy_offset: 20},
      nil, {oy_offset: 24},
      nil, {oy_offset: 20}
    ],
    loop: false
  },
  stay: {
    max_counter: 2,
    data: [
      { state: :leave }
    ],
    loop: false
  },
  leave: $data[0][2][:leave]
}
# interrogation emotion particle
# eval(format(emotion_str, name: 'interrogation', y: 32, x: 0, target: 16, se_play: 'audio/particles/exclamation'))
# All the existing emotions
emotion_str = <<-EOEMOTION
$data[0][:%<name>s] = {
  enter: {
    max_counter: 60,
    data: [
      { file: "emotions", rect: [%<x>d, %<y>d, 16, 16], zoom: 1, position: :center_pos, oy_offset: 10, se_play: 'audio/particles/' + :%<name>s.to_s},
      *Array.new(28),
      { rect: [%<target>d, %<y>d, 16, 16] }
    ],
    loop: false
  },
  stay: $data[0][:exclamation][:stay],
  leave: $data[0][2][:leave]
}
EOEMOTION
eval(format(emotion_str, name: 'poison', y: 0, x: 32, target: 48))
eval(format(emotion_str, name: 'exclamation2', y: 16, x: 0, target: 16))
eval(format(emotion_str, name: 'interrogation', y: 32, x: 0, target: 16))
eval(format(emotion_str, name: 'music', y: 16, x: 32, target: 48))
eval(format(emotion_str, name: 'love', y: 32, x: 32, target: 48))
eval(format(emotion_str, name: 'joy', y: 0, x: 64, target: 80))
eval(format(emotion_str, name: 'sad', y: 16, x: 64, target: 80))
eval(format(emotion_str, name: 'happy', y: 32, x: 64, target: 80))
eval(format(emotion_str, name: 'angry', y: 0, x: 96, target: 112))
eval(format(emotion_str, name: 'sulk', y: 16, x: 96, target: 112))
eval(format(emotion_str, name: 'nocomment', y: 32, x: 96, target: 112))

# The dust when the player jump
$data[0][:dust] = {
  enter: {
    max_counter: 9,
    loop: false,
    data: [
      { file: 'dust', rect: [0, 0, 32, 16], zoom: 1, position: :center_pos, add_z: 2 },
      { wait: 4 }, { rect: [32, 0, 32, 16], se_player_play: 'audio/particles/se_jump-landing' },
      { wait: 4 }, { rect: [64, 0, 32, 16] },
      { wait: 4 }, { rect: [96, 0, 32, 16] },
      { wait: 5 }, { rect: [128, 0, 1, 1] }
    ]
  },
  stay: EMPTY,
  leave: EMPTY
}

# Fading of a step on the ground
TRACK_OPACITY_FADING = [{ wait: 17 }, { opacity: 115 }, { wait: 17 }, { opacity: 100 }, { wait: 17 }, { opacity: 85 }, { wait: 17 }, { opacity: 70 }, { wait: 17 }, { opacity: 55 }, { wait: 17 }, { opacity: 40 }, { wait: 17 }, { opacity: 25 }, { wait: 17 }, { opacity: 10 }, { wait: 17 }, { opacity: 0 }]
# Footprint on sand tile (going down)
$data[0][:sand_d] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 19,
    loop: false,
    data: [
      { file: 'floor_print', rect: [0, 0, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 125 },
      *TRACK_OPACITY_FADING
    ]
  }
}
# Footprint on sand tile (going to the left)
$data[0][:sand_l] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 19,
    loop: false,
    data: [
      { file: 'floor_print', rect: [16, 0, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 125 },
      *TRACK_OPACITY_FADING
    ]
  }
}
# Footprint on sand tile (going to the right)
$data[0][:sand_r] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 19,
    loop: false,
    data: [
      { file: 'floor_print', rect: [32, 0, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 125 },
      *TRACK_OPACITY_FADING
    ]
  }
}
# Footprint on sand tile (going up)
$data[0][:sand_u] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 19,
    loop: false,
    data: [
      { file: 'floor_print', rect: [48, 0, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 125 },
      *TRACK_OPACITY_FADING
    ]
  }
}
# Circle shown when we surf on a pond tile
$data[0][:pond] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 13,
    loop: false,
    data: [
      { file: 'surf_print', rect: [0, 0, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 255 },
      { wait: 8 }, { rect: [16, 0, 16, 16] },
      { wait: 8 }, { rect: [32, 0, 16, 16] },
      { wait: 8 }, { rect: [48, 0, 16, 16] },
      { wait: 8 }, { rect: [64, 0, 16, 16] },
      { wait: 8 }, { rect: [80, 0, 16, 16] },
      { wait: 8 }, { rect: [96, 0, 16, 16] }
    ]
  }
}
# Circle shown when we step on a puddle tile
$data[0][:puddle] = {
  enter: {
    max_counter: 7,
    data: [
      { wait: 5 }, { se_player_play: 'audio/particles/step_puddle' }
    ],
    loop: false
  },
  stay: EMPTY,
  leave: {
    max_counter: 13,
    loop: false,
    data: [
      { file: 'ripple', rect: [0, 0, 16, 16], zoom: 1, set_z: -1, position: :center_pos, opacity: 255 },
      { wait: 8 }, { rect: [16, 0, 16, 16] },
      { wait: 8 }, { rect: [32, 0, 16, 16] },
      { wait: 8 }, { rect: [48, 0, 16, 16] }
    ]
  }
}
# Circle shown when we step on a muddy puddle tile
$data[1][:puddle] = {
  enter: {
    max_counter: 7,
    data: [
      { wait: 5 }, { se_player_play: 'audio/particles/step_swamp' }
    ],
    loop: false
  },
  stay: EMPTY,
  leave: {
    max_counter: 13,
    loop: false,
    data: [
      { file: 'ripple-mud', rect: [0, 0, 16, 16], zoom: 1, add_z: -1, position: :center_pos, opacity: 255 },
      { wait: 8 }, { rect: [16, 0, 16, 16] },
      { wait: 8 }, { rect: [32, 0, 16, 16] },
      { wait: 8 }, { rect: [48, 0, 16, 16] }
    ]
  }
}
# Fading of a step on the snow
TRACK_SNOW_OPACITY_FADING = [
  { wait: 9 }, { opacity: 240 }, { wait: 9 }, { opacity: 225 }, { wait: 9 }, { opacity: 210 }, { wait: 9 }, { opacity: 195 }, { wait: 9 }, { opacity: 180 }, { wait: 9 },
  { opacity: 165 }, { wait: 9 }, { opacity: 150 }, { wait: 9 }, { opacity: 135 }, { wait: 9 }, { opacity: 120 }, { wait: 9 }, { opacity: 105 }, { wait: 9 }, { opacity: 90 },
  { wait: 9 }, { opacity: 75 }, { wait: 9 }, { opacity: 60 }, { wait: 9 }, { opacity: 45 }, { wait: 9 }, { opacity: 30 }, { wait: 9 }, { opacity: 15 }, { wait: 9 }, { opacity: 0 }
]
# Snow footprint when going down
$data[0][:snow_d] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 35,
    loop: false,
    data: [
      { file: 'floor_print', rect: [0, 16, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 250 },
      *TRACK_SNOW_OPACITY_FADING
    ]
  }
}
# Snow footprint when going to the left
$data[0][:snow_l] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 35,
    loop: false,
    data: [
      { file: 'floor_print', rect: [16, 16, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 125 },
      *TRACK_SNOW_OPACITY_FADING
    ]
  }
}
# Snow footprint when going to the right
$data[0][:snow_r] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 35,
    loop: false,
    data: [
      { file: 'floor_print', rect: [32, 16, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 250 },
      *TRACK_SNOW_OPACITY_FADING
    ]
  }
}
# Snow footprint when going up
$data[0][:snow_u] = {
  enter: EMPTY,
  stay: EMPTY,
  leave: {
    max_counter: 35,
    loop: false,
    data: [
      { file: 'floor_print', rect: [48, 16, 16, 16], zoom: 1, add_z: -32, position: :center_pos, opacity: 125 },
      *TRACK_SNOW_OPACITY_FADING
    ]
  }
}

# Splash water particle (badly defined)
$data[0][:splash_water] = {
  enter: {
    max_counter: 31,
    loop: false,
    data: [
      { file: 'eclaboussures', rect: [0, 0, 40, 7], zoom: 1, position: :center_pos, add_z: 32, ox_offset: -11, se_player_play: 'audio/particles/diving' },
      { wait: 4 }, { rect: [40, 0, 40, 7] },
      { wait: 4 }, { rect: [80, 0, 40, 7] },
      { wait: 4 }, { rect: [0, 0, 40, 7] },
      { wait: 4 }, { rect: [40, 0, 40, 7] },
      { wait: 4 }, { rect: [80, 0, 40, 7] },
      { wait: 4 }, { rect: [0, 0, 40, 7] },
      { wait: 4 }, { rect: [40, 0, 40, 7] },
      { wait: 4 }, { rect: [80, 0, 40, 7] },
      { wait: 4 }, { rect: [0, 0, 40, 7] },
      { wait: 4 }, { rect: [40, 0, 40, 7] },
      { wait: 4 }, { rect: [80, 0, 40, 7] },
      { wait: 4 }, { rect: [0, 0, 40, 7] },
      { wait: 4 }, { rect: [40, 0, 40, 7] },
      { wait: 4 }, { rect: [80, 0, 40, 7] },
      { wait: 4 }, { rect: [0, 0, 40, 7] }
    ]
  },
  stay: { max_counter: 1, loop: false, data: [{ state: :leave }] },
  leave: EMPTY
}

# Splash when standing in the water
$data[0][:wetsand] = {
  enter: {
    max_counter: 1,
    loop: false,
    data: [
      { file: 'splash', rect: [0, 0, 32, 16], position: :character_pos, se_player_play: 'audio/particles/step_Puddle' }
    ]
  },
  stay: {
    max_counter: 9,
    loop: true,
    data: [
      { wait: 2, file: 'splash', rect: [0, 0, 32, 16], position: :character_pos }, { rect: [0, 0, 32, 16] }, 
      { wait: 2 }, { rect: [32, 0, 32, 16] },
      { wait: 2 }, { rect: [64, 0, 32, 16] }
    ]
  },
  leave: EMPTY
}

# Splash shown when we jump on water
$data[0][:water_dust] = {
  enter: {
    max_counter: 8,
    loop: false,
    data: [
      { file: 'splash', rect: [0, 0, 20, 11], zoom: 0.8, position: :character_pos, oy_offset: 6 },
      { wait: 1 }, { rect: [0, 0, 20, 11] },
      { wait: 1 }, { rect: [20, 0, 20, 11] },
      { wait: 1 }, { rect: [40, 0, 20, 11] },
      { state: :leave }
    ]
  },
  stay: EMPTY,
  leave: EMPTY
}

# Waterfall particle
$data[0][:waterfall] = {
  enter: {
    max_counter: 8,
    loop: false,
    data: [
      { file: 'waterfall_above', rect: [0, 0, 32, 32], zoom: 1, add_z: -32, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 3}, 
      { file: 'waterfall_above', rect: [32, 0, 32, 32], zoom: 1, add_z: -32, position: :character_pos, oy_offset: -10, opacity: 255 }
    ]
  },
  stay: {
    max_counter: 12,
    loop: true,
    data: [
      { file: 'waterfall', rect: [0, 0, 32, 64], zoom: 1, add_z: -32, position: :character_pos, oy_offset: -32, opacity: 255 },
      { wait: 4 }, { rect: [32, 0, 32, 64], zoom: 1, add_z: -32, position: :character_pos, oy_offset: -32, opacity: 255 },
    ]
  },
  leave: {
    max_counter: 5,
    loop: false,
    data: [
      { file: 'waterfall_above', rect: [0, 0, 32, 32], zoom: 1, add_z: -32, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 3}, 
      { file: 'waterfall_above', rect: [32, 0, 32, 32], zoom: 1, add_z: -32, position: :character_pos, oy_offset: -10, opacity: 255 }
    ]
  }
}

# Particles Rock Climb
$data[0][:rock_climb] = {
  enter: {
    max_counter: 34,
    loop: false,
    data: [
      { file: 'rock_climb', rect: [0, 0, 64, 64], zoom: 1, add_z: 0, position: :grass_pos, oy_offset: -10, opacity: 255 },
      { wait: 2 }, { rect: [64, 0, 64, 64] },
      { wait: 1 }, { rect: [128, 0, 64, 64] },
      { wait: 1 }, { rect: [192, 0, 64, 64] },
      { wait: 1 }, { rect: [256, 0, 64, 64] },
      { wait: 1 }, { rect: [320, 0, 64, 64] },
      { wait: 1 }, { rect: [384, 0, 64, 64] },
      { wait: 1 }, { rect: [448, 0, 64, 64] },
      { wait: 1 }, { rect: [512, 0, 64, 64] },
      { wait: 1 }, { rect: [576, 0, 64, 64] },
      { wait: 1 }, { rect: [640, 0, 64, 64] },
      { wait: 1 }, { rect: [704, 0, 64, 64] },
      { wait: 1 }, { rect: [768, 0, 64, 64] },
      { wait: 1 }, { rect: [832, 0, 64, 64] },
      { wait: 1 }, { rect: [896, 0, 64, 64] },
      { wait: 1 }, { rect: [960, 0, 64, 64] },
      { wait: 1 }, { rect: [1024, 0, 64, 64] },
      { wait: 1 }, { rect: [1088, 0, 64, 64] }
    ]
  },
  stay: EMPTY,
  leave: EMPTY
}

# Whirlpool particle when going to the left
$data[0][:whirlpool_l] = {
  enter: {
    max_counter: 1,
    loop: true,
    data: [
      { file: 'Whirlpool_l', rect: [0, 0, 56, 38], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 }
    ]
  },
  stay: {
    max_counter: 13,
    loop: true,
    data: [
      { file: 'Whirlpool_l', rect: [0, 0, 56, 38], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 1}, { rect: [56, 0, 56, 38] },
      {wait: 1}, { rect: [112, 0, 56, 38] },
      {wait: 1}, { rect: [168, 0, 56, 38] },
      {wait: 1}, { rect: [224, 0, 56, 38] },
      {wait: 1}, { rect: [280, 0, 56, 38] },
      {wait: 1}, { rect: [336, 0, 56, 38] },
      {wait: 1}, { rect: [392, 0, 56, 38] },
      {wait: 1}, { rect: [448, 0, 56, 38] },
      {wait: 1}, { rect: [504, 0, 56, 38] },
      {wait: 1}, { rect: [560, 0, 56, 38] },
      {wait: 1}, { rect: [616, 0, 56, 38] },
      {wait: 1}, { rect: [672, 0, 56, 38] },
    ]
  },
  leave: {
    max_counter: 13,
    loop: false,
    data: [
      { file: 'Whirlpool_l', rect: [0, 0, 56, 38], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 1}, { rect: [56, 0, 56, 38], opacity: 220 },
      {wait: 1}, { rect: [112, 0, 56, 38], opacity: 200 },
      {wait: 1}, { rect: [168, 0, 56, 38], opacity: 180 },
      {wait: 1}, { rect: [224, 0, 56, 38], opacity: 160 },
      {wait: 1}, { rect: [280, 0, 56, 38], opacity: 140 },
      {wait: 1}, { rect: [336, 0, 56, 38], opacity: 120 },
      {wait: 1}, { rect: [392, 0, 56, 38], opacity: 100 },
      {wait: 1}, { rect: [448, 0, 56, 38], opacity: 80 },
      {wait: 1}, { rect: [504, 0, 56, 38], opacity: 60 },
      {wait: 1}, { rect: [560, 0, 56, 38], opacity: 40 },
      {wait: 1}, { rect: [616, 0, 56, 38], opacity: 20 },
      {wait: 1}, { rect: [672, 0, 56, 38], opacity: 0 }
    ]
  },
}

# Whirlpool particle when going to the right
$data[0][:whirlpool_r] = {
  enter: {
    max_counter: 1,
    loop: true,
    data: [
      { file: 'Whirlpool_r', rect: [0, 0, 56, 38], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 }
    ]
  },
  stay: {
    max_counter: 13,
    loop: true,
    data: [
      { file: 'Whirlpool_r', rect: [0, 0, 56, 38], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 1}, { rect: [56, 0, 56, 38] },
      {wait: 1}, { rect: [112, 0, 56, 38] },
      {wait: 1}, { rect: [168, 0, 56, 38] },
      {wait: 1}, { rect: [224, 0, 56, 38] },
      {wait: 1}, { rect: [280, 0, 56, 38] },
      {wait: 1}, { rect: [336, 0, 56, 38] },
      {wait: 1}, { rect: [392, 0, 56, 38] },
      {wait: 1}, { rect: [448, 0, 56, 38] },
      {wait: 1}, { rect: [504, 0, 56, 38] },
      {wait: 1}, { rect: [560, 0, 56, 38] },
      {wait: 1}, { rect: [616, 0, 56, 38] },
      {wait: 1}, { rect: [672, 0, 56, 38] },
    ]
  },
  leave: {
    max_counter: 13,
    loop: false,
    data: [
      { file: 'Whirlpool_r', rect: [0, 0, 56, 38], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 1}, { rect: [56, 0, 56, 38], opacity: 220 },
      {wait: 1}, { rect: [112, 0, 56, 38], opacity: 200 },
      {wait: 1}, { rect: [168, 0, 56, 38], opacity: 180 },
      {wait: 1}, { rect: [224, 0, 56, 38], opacity: 160 },
      {wait: 1}, { rect: [280, 0, 56, 38], opacity: 140 },
      {wait: 1}, { rect: [336, 0, 56, 38], opacity: 120 },
      {wait: 1}, { rect: [392, 0, 56, 38], opacity: 100 },
      {wait: 1}, { rect: [448, 0, 56, 38], opacity: 80 },
      {wait: 1}, { rect: [504, 0, 56, 38], opacity: 60 },
      {wait: 1}, { rect: [560, 0, 56, 38], opacity: 40 },
      {wait: 1}, { rect: [616, 0, 56, 38], opacity: 20 },
      {wait: 1}, { rect: [672, 0, 56, 38], opacity: 0 }
    ]
  },
}

# Whirlpool particle when going down
$data[0][:whirlpool_d] = {
  enter: {
    max_counter: 1,
    loop: true,
    data: [
      { file: 'Whirlpool_d', rect: [0, 0, 46, 46], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 }
    ]
  },
  stay: {
    max_counter: 13,
    loop: true,
    data: [
      { file: 'Whirlpool_d', rect: [0, 0, 46, 46], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 1}, { rect: [46, 0, 46, 46] },
      {wait: 1}, { rect: [92, 0, 46, 46] },
      {wait: 1}, { rect: [138, 0, 46, 46] },
      {wait: 1}, { rect: [184, 0, 46, 46] },
      {wait: 1}, { rect: [230, 0, 46, 46] },
      {wait: 1}, { rect: [276, 0, 46, 46] },
      {wait: 1}, { rect: [322, 0, 46, 46] },
      {wait: 1}, { rect: [368, 0, 46, 46] },
      {wait: 1}, { rect: [414, 0, 46, 46] },
      {wait: 1}, { rect: [460, 0, 46, 46] },
      {wait: 1}, { rect: [506, 0, 46, 46] },
      {wait: 1}, { rect: [552, 0, 46, 46] }
    ]
  },
  leave: {
    max_counter: 13,
    loop: false,
    data: [
      { file: 'Whirlpool_d', rect: [0, 0, 46, 46], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -10, opacity: 255 },
      {wait: 1}, { rect: [46, 0, 46, 46], opacity: 220 },
      {wait: 1}, { rect: [92, 0, 46, 46], opacity: 200 },
      {wait: 1}, { rect: [138, 0, 46, 46], opacity: 180 },
      {wait: 1}, { rect: [184, 0, 46, 46], opacity: 160 },
      {wait: 1}, { rect: [230, 0, 46, 46], opacity: 140 },
      {wait: 1}, { rect: [276, 0, 46, 46], opacity: 120 },
      {wait: 1}, { rect: [322, 0, 46, 46], opacity: 100 },
      {wait: 1}, { rect: [368, 0, 46, 46], opacity: 80 },
      {wait: 1}, { rect: [414, 0, 46, 46], opacity: 60 },
      {wait: 1}, { rect: [460, 0, 46, 46], opacity: 40 },
      {wait: 1}, { rect: [506, 0, 46, 46], opacity: 20 },
      {wait: 1}, { rect: [552, 0, 46, 46], opacity: 0 }
    ]
  },
}

# Whirlpool particle when going up
$data[0][:whirlpool_u] = {
  enter: {
    max_counter: 1,
    loop: true,
    data: [
      { file: 'Whirlpool_u', rect: [0, 0, 89, 83], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -37, opacity: 255 }
    ]
  },
  stay: {
    max_counter: 13,
    loop: true,
    data: [
      { file: 'Whirlpool_u', rect: [0, 0, 89, 83], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -37, opacity: 255 },
      {wait: 1}, { rect: [89, 0, 89, 83] },
      {wait: 1}, { rect: [178, 0, 89, 83] },
      {wait: 1}, { rect: [267, 0, 89, 83] },
      {wait: 1}, { rect: [356, 0, 89, 83] },
      {wait: 1}, { rect: [445, 0, 89, 83] },
      {wait: 1}, { rect: [534, 0, 89, 83] },
      {wait: 1}, { rect: [623, 0, 89, 83] },
      {wait: 1}, { rect: [712, 0, 89, 83] },
      {wait: 1}, { rect: [801, 0, 89, 83] },
      {wait: 1}, { rect: [890, 0, 89, 83] },
      {wait: 1}, { rect: [979, 0, 89, 83] },
      {wait: 1}, { rect: [1068, 0, 89, 83] }
    ]
  },
  leave: {
    max_counter: 13,
    loop: false,
    data: [
      { file: 'Whirlpool_u', rect: [0, 0, 89, 83], zoom: 1, add_z: -1, position: :character_pos, oy_offset: -37, opacity: 255 },
      {wait: 1}, { rect: [89, 0, 89, 83], opacity: 220 },
      {wait: 1}, { rect: [178, 0, 89, 83], opacity: 200 },
      {wait: 1}, { rect: [267, 0, 89, 83], opacity: 180 },
      {wait: 1}, { rect: [356, 0, 89, 83], opacity: 160 },
      {wait: 1}, { rect: [445, 0, 89, 83], opacity: 140 },
      {wait: 1}, { rect: [534, 0, 89, 83], opacity: 120 },
      {wait: 1}, { rect: [623, 0, 89, 83], opacity: 100 },
      {wait: 1}, { rect: [712, 0, 89, 83], opacity: 80 },
      {wait: 1}, { rect: [801, 0, 89, 83], opacity: 60 },
      {wait: 1}, { rect: [890, 0, 89, 83], opacity: 40 },
      {wait: 1}, { rect: [979, 0, 89, 83], opacity: 20 },
      {wait: 1}, { rect: [1068, 0, 89, 83], opacity: 0 }
    ]
  },
}

# Save the particle data
save