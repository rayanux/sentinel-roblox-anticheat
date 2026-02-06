local RunService = game:GetService("RunService")

local CheckManager = {}
CheckManager.__index = CheckManager

function CheckManager.new(sentinelAC)
	local self = setmetatable({
		_sentinel = sentinelAC,
		_checks = {},
		_connections = {},
		_lastCheckTime = 0,
		_playerRotationIndex = 0,
	}, CheckManager)

	return self
end

function CheckManager:initialize()
	local logger = self._sentinel._logger
	local checksFolder = script.Parent.Parent:WaitForChild("Checks")

	for _, checkModule in ipairs(checksFolder:GetChildren()) do
		if checkModule:IsA("ModuleScript") then
			local success, check = pcall(require, checkModule)

			if success and check then
				local checkName = checkModule.Name:gsub("Check", "")
				self._checks[checkName] = check

				if check.init then
					check:init(self._sentinel)
				end

				logger:debug("Loaded check: %s", checkName)
			else
				logger:error("Failed to load check: %s - %s", checkModule.Name, tostring(check))
			end
		end
	end

	self:_startCheckLoop()
	logger:info("Loaded %d detection checks", self:_getActiveCheckCount())
end

function CheckManager:_getActiveCheckCount()
	local count = 0
	for checkName, check in pairs(self._checks) do
		local configKey = "enable" .. checkName .. "Check"
		if self._sentinel._config[configKey] ~= false then
			count = count + 1
		end
	end
	return count
end

function CheckManager:_startCheckLoop()
	local connection = RunService.Heartbeat:Connect(function(deltaTime)
		self:_runChecks(deltaTime)
	end)

	table.insert(self._connections, connection)
end

function CheckManager:_runChecks(deltaTime)
	local config = self._sentinel._config
	local currentTime = tick()

	if currentTime - self._lastCheckTime < config.checkInterval then
		return
	end

	local realDelta = currentTime - self._lastCheckTime
	self._lastCheckTime = currentTime

	local playerTracker = self._sentinel._playerTracker
	local allPlayers = playerTracker:getAllPlayers()

	local maxPlayersThisFrame = math.min(#allPlayers, config.maxPlayersPerFrame)

	for j = 1, maxPlayersThisFrame do
		local idx = ((self._playerRotationIndex + j - 1) % #allPlayers) + 1
		local trackedPlayer = allPlayers[idx]

		if trackedPlayer and not trackedPlayer:isWhitelisted() then
			for checkName, check in pairs(self._checks) do
				local configKey = "enable" .. checkName .. "Check"

				if config[configKey] ~= false and check.check then
					local success, err = pcall(check.check, check, trackedPlayer, realDelta)

					if not success then
						self._sentinel._logger:error("Check %s failed: %s", checkName, tostring(err))
					end
				end
			end
		end
	end

	self._playerRotationIndex = self._playerRotationIndex + maxPlayersThisFrame
end

function CheckManager:getCheck(checkName)
	return self._checks[checkName]
end

function CheckManager:shutdown()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self._connections)
	table.clear(self._checks)
end

return CheckManager
