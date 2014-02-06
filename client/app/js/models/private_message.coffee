class @PrivateMessage extends Backbone.Model
  initialize: =>
    @clear()

  add: (username, message, opts = {}) =>
    log = @get('log')
    log.push({username, message, opts})
    @trigger("receive", @id, username, message, opts)

  clear: =>
    @set('log', [])

  openChallenge: (args...) =>
    @trigger("openChallenge", args...)

  cancelChallenge: (args...) =>
    @trigger("cancelChallenge", args...)

  closeChallenge: (args...) =>
    @trigger("closeChallenge", args...)
