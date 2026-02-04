local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local TrackedPlayer = {}
TrackedPlayer.__index = TrackedPlayer

function TrackedPlayer.new(player, sentinelAC)
	local self = setmetatable({
		player = player,
		_sentinel = sentinelAC,
		_strikes = {},
		_totalStrikes = 0,
		_lastStrikeTime = 0,
		_whitelisted = false,
		_lastHeartbeat = os.time(),
		_memory = {},
		_connections = {},
		_alive = true,
	}, TrackedPlayer)

	if player.Character then
		self:_onCharacterAdded(player.Character)
	end

	table.insert(self._connections, player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdded(character)
	end))

	self:_startStrikeDecay()

	return self
end

function TrackedPlayer:_onCharacterAdded(character)
	self._memory.character = character
	self._memory.lastPosition = nil
	self._memory.lastVelocity = Vector3.zero
	self._memory.positionHistory = {}

	task.wait(0.5)

	if Utility.isCharacterValid(character) then
		local rootPart = Utility.getRootPart(character)
		if rootPart then
			self._memory.lastPosition = rootPart.Position
		end
	end
end

function TrackedPlayer:_startStrikeDecay()
	task.spawn(function()
		while self._alive and self.player and self.player.Parent do
			local config = self._sentinel._config
			task.wait(config.strikeCooldown)

			if not self._alive then
				break
			end

			if self._totalStrikes > 0 then
				for reason, count in pairs(self._strikes) do
					local newCount = math.max(0, count - config.strikeDecayRate)
					self._strikes[reason] = newCount > 0 and newCount or nil
				end

				self:_recalculateStrikes()
			end
		end
	end)
end

function TrackedPlayer:_recalculateStrikes()
	local total = 0
	for _, count in pairs(self._strikes) do
		total = total + count
	end
	self._totalStrikes = total
end

function TrackedPlayer:addStrikes(reason, count)
	if self._whitelisted then
		return
	end

	count = count or 1
	self._strikes[reason] = (self._strikes[reason] or 0) + count
	self:_recalculateStrikes()
	self._lastStrikeTime = os.time()

	local logger = self._sentinel._logger
	logger:warn("Player %s flagged: %s (+%d strikes, total: %d/%d)",
		self.player.Name,
		reason,
		count,
		self._totalStrikes,
		self._sentinel._config.maxStrikes
	)

	self._sentinel:_triggerCallbacks("onStrikeAdded", self.player, reason, count, self._totalStrikes)
	self._sentinel:_triggerCallbacks("onPlayerFlagged", self.player, reason, self._totalStrikes)

	self:_checkThreshold()
end

function TrackedPlayer:removeStrikes(reason, count)
	count = count or 1

	if self._strikes[reason] then
		self._strikes[reason] = math.max(0, self._strikes[reason] - count)
		if self._strikes[reason] == 0 then
			self._strikes[reason] = nil
		end
		self:_recalculateStrikes()
	end
end

function TrackedPlayer:_checkThreshold()
	local config = self._sentinel._config

	if self._totalStrikes >= config.maxStrikes and config.autoKick then
		self:kick()
	end
end

function TrackedPlayer:kick()
	local config = self._sentinel._config
	local logger = self._sentinel._logger

	local topReason = "Suspicious Activity"
	local maxCount = 0

	for reason, count in pairs(self._strikes) do
		if count > maxCount then
			maxCount = count
			topReason = reason
		end
	end

	local message = Utility.formatString(config.kickMessage, {
		reason = topReason,
		strikes = self._totalStrikes
	})

	logger:critical("Kicking player %s - Reason: %s (Strikes: %d)",
		self.player.Name,
		topReason,
		self._totalStrikes
	)

	self._sentinel:_triggerCallbacks("onPlayerKicked", self.player, topReason, self._totalStrikes)

	task.spawn(function()
		self.player:Kick(message)
	end)
end

function TrackedPlayer:heartbeat()
	self._lastHeartbeat = os.time()
end

function TrackedPlayer:isHeartbeatValid()
	local config = self._sentinel._config
	if not config.enableClientChecks then
		return true
	end

	return (os.time() - self._lastHeartbeat) < config.clientHeartbeatTimeout
end

function TrackedPlayer:setWhitelisted(whitelisted)
	self._whitelisted = whitelisted
end

function TrackedPlayer:isWhitelisted()
	return self._whitelisted
end

function TrackedPlayer:getStrikeInfo()
	return {
		total = self._totalStrikes,
		strikes = Utility.deepCopy(self._strikes),
		lastStrikeTime = self._lastStrikeTime,
	}
end

function TrackedPlayer:getMemory()
	return self._memory
end

function TrackedPlayer:setMemory(key, value)
	self._memory[key] = value
end

function TrackedPlayer:destroy()
	self._alive = false

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self._connections)
	table.clear(self._strikes)
	table.clear(self._memory)

	setmetatable(self, nil)
end

return TrackedPlayer
