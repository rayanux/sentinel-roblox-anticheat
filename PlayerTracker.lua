local Players = game:GetService("Players")
local TrackedPlayer = require(script.Parent.Parent:WaitForChild("Player"):WaitForChild("TrackedPlayer"))

local PlayerTracker = {}
PlayerTracker.__index = PlayerTracker

function PlayerTracker.new(sentinelAC)
	local self = setmetatable({
		_sentinel = sentinelAC,
		_players = {},
		_connections = {},
	}, PlayerTracker)

	return self
end

function PlayerTracker:initialize()
	local logger = self._sentinel._logger

	for _, player in ipairs(Players:GetPlayers()) do
		self:_onPlayerAdded(player)
	end

	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end))

	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end))

	logger:debug("PlayerTracker initialized")
end

function PlayerTracker:_onPlayerAdded(player)
	local logger = self._sentinel._logger

	if self._players[player] then
		logger:warn("Player %s already tracked", player.Name)
		return
	end

	local trackedPlayer = TrackedPlayer.new(player, self._sentinel)
	self._players[player] = trackedPlayer

	logger:info("Player joined: %s (UserId: %d)", player.Name, player.UserId)
end

function PlayerTracker:_onPlayerRemoving(player)
	local logger = self._sentinel._logger
	local trackedPlayer = self._players[player]

	if trackedPlayer then
		trackedPlayer:destroy()
		self._players[player] = nil
		logger:info("Player left: %s", player.Name)
	end
end

function PlayerTracker:getPlayer(player)
	return self._players[player]
end

function PlayerTracker:getAllPlayers()
	local players = {}
	for player, trackedPlayer in pairs(self._players) do
		table.insert(players, trackedPlayer)
	end
	return players
end

function PlayerTracker:shutdown()
	for player, trackedPlayer in pairs(self._players) do
		trackedPlayer:destroy()
	end
	table.clear(self._players)

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return PlayerTracker