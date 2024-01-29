# Register init logic event
# This kind of event will be called before the scene actually transition,
# the goal if that event is to setup the logic the way you want.
#
# In this example, we will setup light screen & reflect on AI side with infinite amount of turns
Battle::Scene.register_event(:logic_init) do |scene|

  class Battle::Effects::CrowdCheering < Battle::Effects::PositionTiedEffectBase
    # Create a new Pokemon tied effect
    # @param logic [Battle::Logic] logic used to get all the handler in order to allow the effect to work
    # @param bank [Integer] bank where the effect is tied
    # @param position [Integer] position where the effect is tied
    # @param turn_count [Integer] number of turn for the confusion (not including current turn)
    def initialize(logic, bank, position, turn_count = Float::INFINITY)
      super(logic, bank, position)
      self.counter = turn_count
    end

    # Give the atk modifier over given to the Pokemon with this effect
    # @return [Float, Integer] multiplier
    def atk_modifier
      return 2
    end

    # Give the dfe modifier over given to the Pokemon with this effect
    # @return [Float, Integer] multiplier
    def dfe_modifier
      return 2
    end

    # Give the speed modifier over given to the Pokemon with this effect
    # @return [Float, Integer] multiplier
    def spd_modifier
      return 2
    end

    # Give the ats modifier over given to the Pokemon with this effect
    # @return [Float, Integer] multiplier
    def ats_modifier
      return 2
    end

    # Give the dfs modifier over given to the Pokemon with this effect
    # @return [Float, Integer] multiplier
    def dfs_modifier
      return 2
    end
  end

  scene.logic.bank_effects[0].add(Battle::Effects::CrowdCheering.new(scene.logic, 0, 0, Float::INFINITY))

  # Here we will define utility function on the visual because we call something that does not exist quite often
  # It's highly recommanded that you make a script that add this function to Battle::Scene instead of doing it here
  # We can't just add this to PSDK by default because all games are different!
  def scene.show_event_message(*messages)
    visual.lock do
      sp = visual.battler_sprite(1, -1) # Trainer sprites are in negative part: -1 = 1st trainer sprite
      # => Show enemy trainer sprite
      animation_to_left = Yuki::Animation.move(0.4, sp, 320 + sp.width, sp.y, 290, sp.y)
      animation_to_left.start
      visual.animations << animation_to_left
      visual.hide_team_info
      visual.wait_for_animation

      show_message(*messages)

      # => Hide enemy trainer sprite
      animation_to_right = Yuki::Animation.move(0.4, sp, 290, sp.y, 320 + sp.width, sp.y)
      animation_to_right.start
      visual.animations << animation_to_right
      visual.show_team_info
      visual.wait_for_animation
    end
  end

  # Here we will define utility function on the visual because we call something that does not exist quite often
  # It's highly recommanded that you make a script that add this function to Battle::Scene instead of doing it here
  # We can't just add this to PSDK by default because all games are different!
  def scene.show_message(*messages)
    # => Show all messages
    messages.each do |message|
      # Tell message box to let player read
      message_window.blocking = true
      message_window.wait_input = true
      # Actually show the message
      display_message_and_wait(message)
    end
  end
end

# Register pre battle begin event
# This kind of event will be called just after the "Trainer wants to battle" message,
# if the transition supports it
# In this kind of event, you can show some pre-battle dialogs or anything else you want.
# Don't forget to call scene.visual.lock otherwise you might get some troubles!
#
# In this example we'll show the 1st AI and make it says something
Battle::Scene.register_event(:pre_battle_begin) do |scene|
  messages = [
    "17, 206 :[name=Palbolsky]:Cela faisait longtemps que je n'avais pas été aussi excité par un combat !",
    '17, 207 :[name=Palbolsky]:Écoute, même la foule est en délire !'
  ]
  scene.show_message(*messages)
  ya = Yuki::Animation
  animation = ya.wait(0.1)
                .play_before(ya.bgs_play('BGS_Crowd_BW2', 100, 100))
                .play_before(ya.wait(0.5))
  animation.start
  until animation.done?
    animation.update
    Graphics.update
  end
  PFM::Text.set_variable('[PLAYER]', $trainer.name)
  messages = [
    '17, 208 :[name=Foule]:Allez, [PLAYER], tu peux le faire !',
    '17, 209 :[name=Foule]:[PLAYER], on est tous avec toi, bats Palbolsky !'
  ]
  scene.show_message(*messages)
  Audio.bgs_fade(1000)
  messages = [
    "17, 210 Vous sentez que la foule vous donne de la force ! Vos Pokémon sont plus forts sous l'effet des encouragements !",
    "17, 211 :[name=Palbolsky]:C'est bien la première fois que la foule veut me voir perdre... Cela me donne encore plus envie de te vaincre !"
  ]
  scene.show_message(*messages)
end

# Register battle begin event
# This kind of event will be called right after everyone sent out their Pokémon and
# just before the player makes the first choice.
# In this kind of event, you can show some pre-battle dialogs or anything else you want.
# Don't forget to call scene.visual.lock otherwise you might get some troubles!
#
# In this example we'll show the 1st AI and make it says something
Battle::Scene.register_event(:battle_begin) do |scene|
  scene.show_event_message('17, 212 :[name=Palbolsky]:Je te présente mon premier Pokémon, qui fut aussi mon premier compagnon... Il risque certainement de te donner du fil à retordre !') # It's calling scene.visual.lock ;)
end

# Register after attack message
# This kind of event is called for all attacking Pokemon, after the end of any attack
# This allows you to write messages like "OMG YOU SO LUCKY WHY YOU CRIT" or "OOF, SUPER EFFECTIVE MOVE BE SUPER EFFECTIVE"
#
# In this example, we'll make Palbolsky talk when the player crit or hit a super effective move
Battle::Scene.register_event(:after_attack) do |scene, launcher, move|
  next if launcher.bank != 0
  next if launcher.dead?
  next if scene.instance_variable_get(:@super_effective_text) && scene.instance_variable_get(:@crit_message)

  if move.instance_variable_get(:@effectiveness) >= 2 && !scene.instance_variable_get(:@super_effective_text)
    scene.instance_variable_set(:@super_effective_text, true)
    next scene.show_event_message("17, 213 :[name=Palbolsky]:Une attaque rondement menée, on voit que tu as l'habitude de cibler les faiblesses adverses !")
  end

  if move.instance_variable_get(:@critical) && !scene.instance_variable_get(:@crit_message)
    scene.instance_variable_set(:@crit_text, true)
    next scene.show_event_message("17, 214 :[name=Palbolsky]:Ouille, ça a fait un max de dégâts ça !")
  end
end

# Register after action dialog event
# This kind of event is called right after all the actions got executed but right before ai send out Pokemon after KO
# Don't forget to call scene.visual.lock otherwise you might get some troubles!
#
# In this example, I'll wait that the 1st AI party has no more Pokemon to switch and make the enemy say something about it
Battle::Scene.register_event(:battle_phase_end) do |scene|
  next if scene.logic.alive_battlers_without_check(1).size > 1
  next if scene.instance_variable_get(:@event_last_dialog_executed)

  scene.instance_variable_set(:@event_last_dialog_executed, true)
  bgm_pos = Audio.bgm_position
  bgm_name = Audio.instance_variable_get(:@bgm_name)
  Audio.bgm_play(bgm_name, 100, 110)
  Audio.bgm_position = bgm_pos
  scene.show_event_message("17, 215 :[name=Palbolsky]:Tu me pousses dans mes derniers retranchements, mais je ne compte pas abandonner pour autant !")
end
