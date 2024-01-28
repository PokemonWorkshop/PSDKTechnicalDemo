# Register init logic event
# This kind of event will be called before the scene actually transition,
# the goal if that event is to setup the logic the way you want.
#
# In this example, we will setup light screen & reflect on AI side with infinite amount of turns
Battle::Scene.register_event(:logic_init) do |scene|
  scene.logic.bank_effects[1].add(Battle::Effects::LightScreen.new(scene.logic, 1, 0, Float::INFINITY))
  scene.logic.bank_effects[1].add(Battle::Effects::Reflect.new(scene.logic, 1, 0, Float::INFINITY))

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

      # => Show all messages
      messages.each do |message|
        # Tell message box to let player read
        message_window.blocking = true
        message_window.wait_input = true
        # Actually show the message
        display_message_and_wait(message)
      end

      # => Hide enemy trainer sprite
      animation_to_right = Yuki::Animation.move(0.4, sp, 290, sp.y, 320 + sp.width, sp.y)
      animation_to_right.start
      visual.animations << animation_to_right
      visual.show_team_info
      visual.wait_for_animation
    end
  end
end

# Register battle begin event
# This kind of event will be called right after everyone sent out their Pokémon and
# just before the player makes the first choice.
# In this kind of event, you can show some pre-battle dialogs or anything else you want.
# Don't forget to call scene.visual.lock otherwise you might get some troubles!
#
# In this example we'll show the 1st AI and make it says something
Battle::Scene.register_event(:battle_begin) do |scene|
  scene.show_event_message('Ah Ah! I\'m so bad I need light screen & reflect effect on battle field by default!') # It's calling scene.visual.lock ;)
end

# Register trainer dialog event
# This kind of event is called after player made a choice and right before AI make any choice
# Don't forget to call scene.visual.lock otherwise you might get some troubles!
#
# In this example we'll make the enemy trainer say something on 1st turn
Battle::Scene.register_event(:trainer_dialog) do |scene|
  next if $game_temp.battle_turn != 1 # 1 = first turn

  scene.show_event_message('Oh, I forgot to tell you, I had no intention to fight :p') # It's calling scene.visual.lock ;)
end

# Register AI force action event
# This kind of event is called for all AI, it should return an Array of Battle::Actions::Base (or nil)
# This allows you to force the AI to make an action
#
# In this example, we'll make the 1st AI switch
Battle::Scene.register_event(:AI_force_action) do |scene, ai, index|
  next if index != 0

  controlled_pokemon = ai.controlled_pokemon
  next if controlled_pokemon.empty? # Safety net
  next unless scene.logic.can_battler_be_replaced?(ai_pokemon = controlled_pokemon.first) # Don't try to switch if we can't

  allies = ai.party.select { |pokemon| pokemon.alive? && !controlled_pokemon.include?(pokemon) }
  next if allies.empty? # Safety net

  next [Battle::Actions::Switch.new(scene, ai_pokemon, allies.sample)]
end

# Register after action dialog event
# This kind of event is called right after all the actions got executed but right before ai send out Pokemon after KO
# Don't forget to call scene.visual.lock otherwise you might get some troubles!
#
# In this example, I'll wait that the 1st AI party has no more Pokemon to switch and make the enemy say something about it
Battle::Scene.register_event(:after_action_dialog) do |scene|
  next if scene.artificial_intelligences[0].party.count { |pokemon| pokemon.alive? } > 1
  next if scene.instance_variable_get(:@event_last_dialog_executed)

  scene.instance_variable_set(:@event_last_dialog_executed, true)
  scene.show_event_message('Oh no! I can no longer switch :(') # It's calling scene.visual.lock ;)
end