{_} = require 'underscore'

class @User
  constructor: (args...) ->
    if args.length == 1
      [ @id ] = args
      @name = @id
    else if args.length == 2
      [ @socket, @connections ] = args
    else if args.length == 3
      [ @id, @socket, @connections ] = args
      @name = @id
    else if args.length == 4
      [ @id, @socket, @connections, @name ] = args

  toJSON: ->
    json = {}
    json['id'] = @_id
    json['name'] = @name
    json['authority'] = @authority  if @authority
    json

  send: (type, data...) ->
    @socket?.write(JSON.stringify(messageType: type, data: data))

  broadcast: (args...) ->
    user.send(args...)  for user in @connections.users when this != user

  error: (args...) ->
    @send("error", args...)

  message: (msg) ->
    @send("rawMessage", msg)

  close: ->
    @socket?.close()

  # Returns a new user object where the name has been masked (useful for alts)
  maskName: (name) ->
    return this  if name == @name

    # Copy over all properties.
    newUser = new User()
    newUser.original = this
    for key, value of this
      newUser[key] = value

    newUser.toJSON = ->
      json = @original.toJSON.apply(this, arguments)
      json.id = undefined
      json.isAlt = true
      json.authority = undefined
      json

    newUser.name = name
    return newUser
