class @BattleCollection extends Backbone.Collection
  model: Battle

  initialize: (models, options) =>
    PokeBattle.primus.on('updateBattle', @updateBattle)
    PokeBattle.primus.on('spectateBattle', @spectateBattle)
    PokeBattle.primus.on('joinBattle', @joinBattle)
    PokeBattle.primus.on('leaveBattle', @leaveBattle)
    PokeBattle.primus.on('updateTimers', @updateTimers)
    PokeBattle.primus.on('resumeTimer', @resumeTimer)
    PokeBattle.primus.on('pauseTimer', @pauseTimer)
    @updateQueue = {}
    @on 'add', (model) =>
      @updateQueue[model.id] = []
    @on 'remove', (model) =>
      delete @updateQueue[model.id]
      PokeBattle.primus.send('leaveBattle', model.id)

  isPlaying: =>
    @find((battle) -> battle.isPlaying())?

  playingBattles: =>
    @filter((battle) -> battle.isPlaying())

  updateBattle: (battleId, actions) =>
    battle = @get(battleId)
    if !battle
      console.log "Received events for #{battleId}, but no longer in battle!"
      return
    battle.notify()
    @queueBattleUpdates(battle, actions)

  queueBattleUpdates: (battle, actions) =>
    queue = @updateQueue[battle.id]
    hadStuff = (queue.length > 0)
    queue.push(actions...)
    if !hadStuff then @_updateBattle(battle)

  _updateBattle: (battle, wasAtBottom) =>
    view = battle.view
    queue = @updateQueue[battle.id]
    return  if !queue  # closed battle in the middle of getting updates
    if queue.length == 0
      view.renderUserInfo()
      view.resetPopovers()
      if wasAtBottom || view.skip? then view.chatView.scrollToBottom()
      if view.skip?
        delete view.skip
        view.$('.battle_pane').show()
      return
    wasAtBottom ||= view.chatView.isAtBottom()
    action = queue.shift()
    [ type, rest... ] = action
    protocol = (key  for key, value of Protocol when value == type)[0]
    console.log "Received protocol: #{protocol}"

    doneTimeout = ->
      setTimeout(done, 0)

    done = () =>
      return  if done.called
      done.called = true
      if view.skip?
        @_updateBattle.call(this, battle, wasAtBottom)
      else
        # setTimeout 0 lets the browser breathe.
        setTimeout(@_updateBattle.bind(this, battle, wasAtBottom), 0)

    try
      switch type
        when Protocol.CHANGE_HP
          [player, slot, newPixels] = rest
          pokemon = battle.getPokemon(player, slot)
          oldPixels = pokemon.get('pixels')
          pokemon.set('pixels', newPixels)
          # TODO: Have this be called automatically.
          view.changeHP(player, slot, oldPixels, done)
        when Protocol.CHANGE_EXACT_HP
          [player, slot, newHP] = rest
          pokemon = battle.getPokemon(player, slot)
          pokemon.set('hp', newHP)
          done()
        when Protocol.SWITCH_OUT
          [player, slot] = rest
          view.switchOut(player, slot, done)
        when Protocol.SWITCH_IN
          # TODO: Get Pokemon data, infer which Pokemon it is.
          # Currently, it cheats with `fromSlot`.
          [player, toSlot, fromSlot] = rest
          team = battle.getTeam(player).get('pokemon').models
          [team[toSlot], team[fromSlot]] = [team[fromSlot], team[toSlot]]
          # TODO: Again, automatic.
          view.switchIn(player, toSlot, fromSlot, done)
        when Protocol.CHANGE_PP
          [player, slot, moveIndex, newPP] = rest
          pokemon = battle.getPokemon(player, slot)
          pokemon.setPP(moveIndex, newPP)
          done()
        when Protocol.REQUEST_ACTIONS
          [validActions] = rest
          view.enableButtons(validActions)
          PokeBattle.notifyUser(PokeBattle.NotificationTypes.ACTION_REQUESTED, battle.id + "_" + battle.get('turn'))
          done()
        when Protocol.START_TURN
          [turn] = rest
          view.beginTurn(turn, doneTimeout)
        when Protocol.CONTINUE_TURN
          view.continueTurn(doneTimeout)
        when Protocol.RAW_MESSAGE
          [message] = rest
          view.addLog("#{message}<br>")
          done()
        when Protocol.FAINT
          [player, slot] = rest
          view.faint(player, slot, done)
        when Protocol.MAKE_MOVE
          # TODO: Send move id instead
          [player, slot, moveName] = rest
          view.logMove(player, slot, moveName, done)
        when Protocol.END_BATTLE
          [winner] = rest
          view.announceWinner(winner, done)
        when Protocol.FORFEIT_BATTLE
          [forfeiter] = rest
          view.announceForfeit(forfeiter, done)
        when Protocol.TIMER_WIN
          [winner] = rest
          view.announceTimer(winner, done)
        when Protocol.BATTLE_EXPIRED
          view.announceExpiration(done)
        when Protocol.MOVE_SUCCESS
          [player, slot, targetSlots, moveName] = rest
          view.moveSuccess(player, slot, targetSlots, moveName, done)
        when Protocol.CANNED_TEXT
          cannedInteger = rest.splice(0, 1)
          view.parseCannedText(cannedInteger, rest, done)
        when Protocol.EFFECT_END
          [player, slot, effect] = rest
          view.endEffect(player, slot, effect, done)
        when Protocol.POKEMON_ATTACH
          [player, slot, attachment] = rest
          view.attachPokemon(player, slot, attachment, done)
        when Protocol.TEAM_ATTACH
          [player, attachment] = rest
          view.attachTeam(player, attachment, done)
        when Protocol.BATTLE_ATTACH
          [attachment] = rest
          view.attachBattle(attachment, done)
        when Protocol.POKEMON_UNATTACH
          [player, slot, attachment] = rest
          view.unattachPokemon(player, slot, attachment, done)
        when Protocol.TEAM_UNATTACH
          [player, attachment] = rest
          view.unattachTeam(player, attachment, done)
        when Protocol.BATTLE_UNATTACH
          [attachment] = rest
          view.unattachBattle(attachment, done)
        when Protocol.INITIALIZE
          # TODO: Handle non-team-preview
          [teams] = rest
          battle.receiveTeams(teams)
          view.preloadImages()
          if !battle.get('spectating')
            PokeBattle.notifyUser(PokeBattle.NotificationTypes.BATTLE_STARTED, battle.id)
          done()
        when Protocol.START_BATTLE
          view.removeTeamPreview()
          view.renderBattle()
          done()
        when Protocol.REARRANGE_TEAMS
          arrangements = rest
          battle.get('teams').forEach (team, i) ->
            team.rearrange(arrangements[i])
          done()
        when Protocol.RECEIVE_TEAM
          [team] = rest
          battle.receiveTeam(team)
          done()
        when Protocol.SPRITE_CHANGE
          [player, slot, newSpecies, newForme] = rest
          pokemon = battle.getPokemon(player, slot)
          pokemon.set('species', newSpecies)
          pokemon.set('forme', newForme)
          view.changeSprite(player, slot, newSpecies, newForme, done)
        when Protocol.BOOSTS
          [player, slot, deltaBoosts] = rest
          view.boost(player, slot, deltaBoosts, floatText: true)
          done()
        when Protocol.SET_BOOSTS
          [player, slot, boosts] = rest
          view.setBoosts(player, slot, boosts)
          done()
        when Protocol.RESET_BOOSTS
          [player, slot] = rest
          view.resetBoosts(player, slot)
          done()
        when Protocol.MOVESET_UPDATE
          [player, slot, movesetJSON] = rest
          pokemon = battle.getPokemon(player, slot)
          pokemon.set(movesetJSON)
          done()
        when Protocol.WEATHER_CHANGE
          [newWeather] = rest
          view.changeWeather(newWeather, done)
        when Protocol.TEAM_PREVIEW
          view.renderTeamPreview()
          done()
        when Protocol.CANCEL_SUCCESS
          view.cancelSuccess(done)
        when Protocol.ACTIVATE_ABILITY
          [player, slot, ability] = rest
          pokemon = battle.getPokemon(player, slot)
          pokemon.set('ability', ability)
          view.activateAbility(player, slot, ability, done)
        else
          done()
    catch e
      console.error(e)
      console.error(e.stack)
      done()
    if wasAtBottom && !view.chatView.isAtBottom()
      view.chatView.scrollToBottom()

  spectateBattle: (id, generation, numActive, index, playerIds, spectators, log) =>
    console.log "SPECTATING BATTLE #{id}."
    isSpectating = (if index? then false else true)
    # If not playing, pick a random index; it doesn't matter.
    index ?= Math.floor(2 * Math.random())
    battle = new Battle({id, generation, numActive, index, playerIds, spectators})
    battle.set('spectating', isSpectating)
    createBattleWindow(this, battle)
    if log.length > 0
      battle.view.skip = 0
      battle.view.$('.battle_pane').hide()
      @queueBattleUpdates(battle, log)

  joinBattle: (id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.add(user)

  leaveBattle: (id, user) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.spectators.remove(id: user)

  updateTimers: (id, timers) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.view.updateTimers(timers)

  resumeTimer: (id, player) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.view.resumeTimer(player)

  pauseTimer: (id, player, timeSinceLastAction) =>
    battle = @get(id)
    if !battle
      console.log "Received events for #{id}, but no longer in battle!"
      return
    battle.view.pauseTimer(player, timeSinceLastAction)

createBattleWindow = (collection, battle) ->
  $battle = $(JST['battle_window'](battle: battle, window: window))
  $battle.appendTo $('#main-section')
  battle.view = new BattleView(el: $battle, model: battle)
  collection.add(battle)
