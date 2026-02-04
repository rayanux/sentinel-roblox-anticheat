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
	local memory = trackedPlayer:getMemory()
	local character = memory.character

	if not Utility.isCharacterValid(character) then
		return
	end

	local rootPart = Utility.getRootPart(character)
	local humanoid = Utility.getHumanoid(character)

	if not rootPart or not humanoid then
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

	if humanoid.Sit then
		memory.lastPosition = currentPosition
		memory.lastCheckTime = currentTime
		return
	end

	if distance > EXTREME_DISTANCE then
		trackedPlayer:addStrikes("Extreme Teleport", 5)
		self:_correctPosition(trackedPlayer, rootPart, memory)
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
	-- Teleport to previous valid position
	if memory.positionHistory and #memory.positionHistory > 0 then
		local safePosition = memory.positionHistory[#memory.positionHistory - 1] or memory.positionHistory[1]

		pcall(function()
			rootPart.CFrame = CFrame.new(safePosition)
			rootPart.AssemblyLinearVelocity = Vector3.zero
		end)

		self._sentinel._logger:debug("Corrected position for %s", trackedPlayer.player.Name)
	end
end


return TeleportCheck
