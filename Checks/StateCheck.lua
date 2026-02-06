local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local StateCheck = {}

-- config
local RAYCAST_DISTANCE = 10
local CHECK_RADIUS = 8

function StateCheck:init(sentinelAC)
	self._sentinel = sentinelAC
	self._characterConnections = {}
end

function StateCheck:check(trackedPlayer, deltaTime)
	local memory = trackedPlayer:getMemory()
	local character = memory.character

	if not Utility.isCharacterValid(character) then
		return
	end

	if not memory.stateCheckSetup then
		self:_setupStateMonitoring(trackedPlayer, character)
		memory.stateCheckSetup = true
	end
end

function StateCheck:_setupStateMonitoring(trackedPlayer, character)
	local humanoid = Utility.getHumanoid(character)
	if not humanoid then
		return
	end

	local connection = humanoid.StateChanged:Connect(function(oldState, newState)
		self:_onStateChanged(trackedPlayer, character, humanoid, oldState, newState)
	end)

	local memory = trackedPlayer:getMemory()
	memory.stateConnection = connection
end

function StateCheck:_onStateChanged(trackedPlayer, character, humanoid, oldState, newState)
	-- skip during spawn/deploy
	local config = self._sentinel._config
	if config.respectForceField and Utility.hasForceField(character) then
		return
	end

	if trackedPlayer:hasTeleportGrace() then
		return
	end

	if oldState == Enum.HumanoidStateType.Dead then
		trackedPlayer:addStrikes("Death State Exploit", 10)
		humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		return
	end

	if newState == Enum.HumanoidStateType.Climbing then
		if not self:_hasLadderNearby(character) then
			trackedPlayer:addStrikes("Invalid Climb", 2)
			self:_correctState(character, humanoid)
		end
	end

	if newState == Enum.HumanoidStateType.Seated then
		if not self:_hasSeatNearby(character) then
			trackedPlayer:addStrikes("Invalid Sit", 2)
			self:_correctState(character, humanoid)
		end
	end
end

function StateCheck:_hasLadderNearby(character)
	local rootPart = Utility.getRootPart(character)
	if not rootPart then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.MaxParts = 50

	local cf, size = character:GetBoundingBox()
	local parts = workspace:GetPartBoundsInRadius(cf.Position, CHECK_RADIUS, overlapParams)

	for _, part in ipairs(parts) do
		if part:IsA("TrussPart") then
			return true
		end
	end

	for i, part in ipairs(parts) do
		for j, otherPart in ipairs(parts) do
			if i ~= j then
				local heightDiff = math.abs(part.Position.Y - otherPart.Position.Y)
				if heightDiff >= 4 and heightDiff <= 20 then
					local horizontalDist = (part.Position * Vector3.new(1, 0, 1) - otherPart.Position * Vector3.new(1, 0, 1)).Magnitude
					if horizontalDist < 3 then
						return true
					end
				end
			end
		end
	end

	return false
end

function StateCheck:_hasSeatNearby(character)
	local rootPart = Utility.getRootPart(character)
	if not rootPart then
		return false
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.MaxParts = 50

	local cf, size = character:GetBoundingBox()
	local parts = workspace:GetPartBoundsInRadius(cf.Position, CHECK_RADIUS, overlapParams)

	for _, part in ipairs(parts) do
		if part:IsA("Seat") or part:IsA("VehicleSeat") then
			return true
		end
	end

	return false
end

function StateCheck:_correctState(character, humanoid)
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

		local rootPart = Utility.getRootPart(character)
		if rootPart then
			rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.pi, 0)
		end
	end)
end

return StateCheck
