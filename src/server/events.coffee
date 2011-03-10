model = require './model'

EventEmitter = require('events').EventEmitter

p = -> #require('util').debug
i = -> #require('util').inspect

# Map from docName to EventEmitter
emitters = {}

emitterForDoc = (docName, create = no) ->
	if create
		emitters[docName] ||= new EventEmitter
	else
		emitters[docName]

model.onApplyOp (docName, opData) ->
	p "onApplyOp #{docName} #{i opData}"
	emitterForDoc(docName)?.emit('op', opData)

# Registers a listener for ops on a particular document.
# callback(startingVersion) is called when the listener is first applied. All ops
# from then on are sent to the user.
# Listeners are of the form listener(op, appliedAt)
exports.listen = (docName, fromVersionCallback, listener) ->
	model.getVersion docName, (version) ->
		emitterForDoc(docName, yes).on 'op', listener
		fromVersionCallback(version)

# Remove a listener from a particular document.
exports.removeListener = (docName, listener) ->
	emitterForDoc(docName)?.removeListener('op', listener)
	p 'Listeners: ' + (i emitterForDoc(docName)?.listeners('op'))

# Listen to all ops from the specified version. The version cannot be in the
# future.
# The callback is called once the listener is attached. removeListener() will be
# ineffective before then.
exports.listenFromVersion = (docName, version, listener, callback) ->
	# The listener isn't attached until we have the historical ops from the database.
	model.getOps docName, version, null, (data) ->
		emitter = emitterForDoc(docName, yes)
		emitter.on 'op', listener
		callback() if callback?
		p 'Listener added -> ' + (i emitterForDoc(docName)?.listeners('op'))

		for op_data in data
			op_data.v = version
			listener op_data

			# The listener may well remove itself during the catchup phase. If this happens, break early.
			# This is done in a quite inefficient way. (O(n) where n = #listeners on doc)
			break unless listener in emitter.listeners('op')
			version += 1


