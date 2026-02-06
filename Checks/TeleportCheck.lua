local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local TeleportCheck = {}

-- config
local MAX_DISTANCE_PER_SECOND = 200 -- max studs/second
local EXTREME_DISTANCE = 500 -- instant teleport threshold
local POSITION_HISTORY_SIZE = 5
local MIN_CHECK_INTERVAL = 0.5

function TeleportCheck:init(sentinelAC)
	self._sentinel = sentinelAC
end

function TeleportCheck:check(trackedPlayer, deltaTime)
	-- skip if game granted teleport grace
	if trackedPlayer:hasTeleportGrace() then
		local memory = trackedPlayer:getMemory()
		local character = memory.character
		if Utility.isCharacterValid(character) then
			local rootPart = Utility.getRootPart(character)
			if rootPart then
				memory.lastPosition = rootPart.Position
				memory.lastCheckTime = tick()
				memory.positionHistory = {}
				memory.teleportViolations = 0
			end
		end
		return
	end

	local memory = trackedPlayer:getMemory()
	local character = memory.character

	if not Utility.isCharacterValid(character) then
		return
	end

	-- skip during spawn/deploy (forcefield present)
	local config = self._sentinel._config
	if config.respectForceField and Utility.hasForceField(character) then
		local rootPart = Utility.getRootPart(character)
		if rootPart then
			memory.lastPosition = rootPart.Position
			memory.lastCheckTime = tick()
			memory.positionHistory = {}
			memory.teleportViolations = 0
		end
		return
	end

	local rootPart = Utility.getRootPart(character)
	local humanoid = Utility.getHumanoid(character)

	if not rootPart or not humanoid then
		return
	end

	-- skip dead players
	if humanoid.Health <= 0 then
		memory.lastPosition = nil
		memory.lastCheckTime = nil
		memory.teleportViolations = 0
		return
	end

	if not memory.lastPosition or not memory.lastCheckTime then
		memory.lastPosition = rootPart.Position
		memory.lastCheckTime = tick()
		memory.positionHistory = memory.positionHistory or {}
		return
	end

	local currentTime = tick()
	local timeDelta = currentTime - memory.lastCheckTime

	if timeDelta < MIN_CHECK_INTERVAL then
		return
	end

	local currentPosition = rootPart.Position
	local distance = (currentPosition - memory.lastPosition).Magnitude
	local distancePerSecond = distance / timeDelta

	-- skip seated players or players on moving platforms
	if humanoid.Sit or humanoid:GetState() == Enum.HumanoidStateType.Seated then
		memory.lastPosition = currentPosition
		memory.lastCheckTime = currentTime
		return
	end

	if distance > EXTREME_DISTANCE then
		trackedPlayer:addStrikes("Extreme Teleport", 5)
		self:_correctPosition(trackedPlayer, rootPart, memory)
		memory.lastCheckTime = currentTime
		return
	end

	if distancePerSecond > MAX_DISTANCE_PER_SECOND then
		memory.teleportViolations = (memory.teleportViolations or 0) + 1

		if memory.teleportViolations >= 2 then
			trackedPlayer:addStrikes("Teleport", 2)
			self:_correctPosition(trackedPlayer, rootPart, memory)
			memory.teleportViolations = 0
		end
	else
		if memory.teleportViolations and memory.teleportViolations > 0 then
			memory.teleportViolations = math.max(0, memory.teleportViolations - 0.5)
		end
	end

	memory.positionHistory = memory.positionHistory or {}
	table.insert(memory.positionHistory, currentPosition)

	if #memory.positionHistory > POSITION_HISTORY_SIZE then
		table.remove(memory.positionHistory, 1)
	end

	memory.lastPosition = currentPosition
	memory.lastCheckTime = currentTime
end

function TeleportCheck:_correctPosition(trackedPlayer, rootPart, memory)
	-- teleport to previous valid position
	if memory.positionHistory and #memory.positionHistory > 0 then
		local histLen = #memory.positionHistory
		local safePosition = memory.positionHistory[math.max(1, histLen - 1)]

		pcall(function()
			rootPart.CFrame = CFrame.new(safePosition)
			rootPart.AssemblyLinearVelocity = Vector3.zero
		end)

		self._sentinel._logger:debug("Corrected position for %s", trackedPlayer.player.Name)
	end
end

return TeleportCheck
