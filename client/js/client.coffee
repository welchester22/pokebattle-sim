#= require templates/index
#= require_tree templates
#= require_tree models
#= require_tree collections
#= require_tree views
#= require_tree concerns

# A wrapper around the sockjs socket to support a higher level of abstraction
# Todo: Move this somewhere else
class @Socket
  constructor: (socket) ->
    @socket = socket
    @callbacks = {}

    handleEvent = (type, data) =>
      console.log "Received event #{type}"

      data ?= []
      for callback in (@callbacks[type] || [])
        callback.apply(this, [this, data...])

    @socket.onopen = =>
      handleEvent('connect')

    @socket.onmessage = (data) =>
      # todo: error handling. If there's a syntax error here, its because of Json.parse
      data = JSON.parse(data.data)
      handleEvent(data.messageType, data.data)

    @socket.onclose = => # nothing yet

  on: (type, callback) ->
    @callbacks[type] ?= []
    @callbacks[type].push(callback)

  addEvents: (events) ->
    @on(type, callback) for type, callback of events

  send: (type, data...) ->
    @socket.send(JSON.stringify(messageType: type, data: data))

@BattleTower = BattleTower = {}
BattleTower.socket = null
BattleTower.chatView = null

$ ->
  #$builder = $('.builder')
  #pokemon = new Team(({name: "Bulbasaur"}  for x in [0...6]))
  #builderView = new TeamBuilderView(el: $builder, collection: pokemon)
  #builderView.render()

  BattleTower.socket = new Socket(new SockJS('/socket'))
  BattleTower.socket.addEvents
    'connect': (socket) ->
      BattleTower.userList = new UserList()
      BattleTower.chatView = new ChatView(
        el: $('.chat')
        collection: BattleTower.userList
      )
      BattleTower.chatView.render()

    'list chatroom': (socket, users) ->
      BattleTower.userList.reset(users)

    'update chat': (socket, user, data) ->
      BattleTower.chatView.userMessage(user.id, data)

    'join chatroom': (socket, user) ->
      BattleTower.userList.add(user)

    'leave chatroom': (socket, user) ->
      BattleTower.userList.remove(user)

    'error': (socket, message) ->
      alert(message)

  new BattleCollection([]) # todo: move this elsewhere
