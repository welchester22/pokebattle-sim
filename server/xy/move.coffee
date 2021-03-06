coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../bw/move.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

@Move::criticalMultiplier = 1.5

@Move::determineCriticalHitFromLevel = (level, rand) ->
  switch level
    when -1
      true
    when 1
      rand < 0.0625
    when 2
      rand < 0.125
    when 3
      rand < 0.5
    else
      rand < 1

@Move::numHitsMessage = (hitNumber) ->
  times = (if hitNumber == 1 then "time" else "times")
  return "Hit #{hitNumber} #{times}!"

# In XY, voice moves and Infiltrator deal direct damage.
oldIsDirectHit = @Move::isDirectHit
@Move::isDirectHit = (battle, user, target) ->
  return true  if @hasFlag("sound")
  return true  if user.hasAbility("Infiltrator") && user.isActive()
  return oldIsDirectHit.apply(this, arguments)
