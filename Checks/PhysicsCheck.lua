local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local PhysicsCheck = {}

-- config
local MAX_AIR_TIME = 3 -- max seconds in air without freefall
local MIN_GRAVITY = 150 -- min acceptable gravity
local NOCLIP_CHECK_DISTANCE = 5

function PhysicsCheck:init(sentinelAC)
	self._sentinel = sentinelAC
end

function PhysicsCheck:check(trackedPlayer, deltaTime)
	local memory = trackedPlayer:getMemory()
	local character = memory.character

	if not Utility.isCharacterValid(character) then
		return
	end

	-- skip during spawn/deploy (forcefield present) or teleport grace
	local config = self._sentinel._config
	if trackedPlayer:hasTeleportGrace() then
		memory.airTime = 0
		memory.sustainedAirFrames = 0
		memory.noclipViolations = 0
		return
	end

	if config.respectForceField and Utility.hasForceField(character) then
		memory.airTime = 0
		memory.sustainedAirFrames = 0
		memory.noclipViolations = 0
		return
	end

	local rootPart = Utility.getRootPart(character)
	local humanoid = Utility.getHumanoid(character)

	if not rootPart or not humanoid then
		return
	end

	-- skip dead or seated players
	if humanoid.Health <= 0 or humanoid.Sit then
		memory.airTime = 0
		memory.sustainedAirFrames = 0
		memory.noclipViolations = 0
		return
	end

	self:_checkFly(trackedPlayer, rootPart, humanoid, deltaTime)
	self:_checkNoclip(trackedPlayer, character, rootPart)
	self:_checkGravity(trackedPlayer, rootPart)
end

function PhysicsCheck:_checkFly(trackedPlayer, rootPart, humanoid, deltaTime)
	local memory = trackedPlayer:getMemory()
	local currentState = humanoid:GetState()

	local isInAir = currentState == Enum.HumanoidStateType.Freefall
		or currentState == Enum.HumanoidStateType.Flying

	local isMovingUp = rootPart.AssemblyLinearVelocity.Y > 5
	local isOnGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local isJumping = currentState == Enum.HumanoidStateType.Jumping
	local isClimbing = currentState == Enum.HumanoidStateType.Climbing

	-- reset on ground, during jumps, or while climbing
	if isOnGround or isJumping or isClimbing then
		memory.airTime = 0
		memory.sustainedAirFrames = 0
		return
	end

	-- normal freefall (falling down) is fine, only flag sustained upward/hovering
	if isInAir and not isMovingUp then
		-- falling normally, decay counters
		memory.sustainedAirFrames = math.max((memory.sustainedAirFrames or 0) - 1, 0)
		if memory.sustainedAirFrames <= 0 then
			memory.airTime = 0
		end
		return
	end

	if isInAir or isMovingUp then
		memory.airTime = (memory.airTime or 0) + deltaTime
		memory.sustainedAirFrames = (memory.sustainedAirFrames or 0) + 1
	else
		memory.airTime = 0
		memory.sustainedAirFrames = 0
		return
	end

	if memory.airTime > MAX_AIR_TIME and memory.sustainedAirFrames > 15 then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {memory.character}

		-- check directly below and at slight offsets
		local origin = rootPart.Position
		local noGroundCount = 0

		for _, offset in ipairs({Vector3.zero, Vector3.new(2, 0, 0), Vector3.new(-2, 0, 0)}) do
			local rayResult = workspace:Raycast(
				origin + offset,
				Vector3.new(0, -50, 0),
				raycastParams
			)
			if not rayResult then
				noGroundCount = noGroundCount + 1
			end
		end

		if noGroundCount >= 2 then
			trackedPlayer:addStrikes("Fly Hack", 2)
			self:_correctFly(rootPart, humanoid)
			memory.airTime = 0
			memory.sustainedAirFrames = 0
		end
	end
end

function PhysicsCheck:_checkNoclip(trackedPlayer, character, rootPart)
	local memory = trackedPlayer:getMemory()

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.MaxParts = 10

	-- check rootPart and head if available
	local partsToCheck = {rootPart}
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		table.insert(partsToCheck, head)
	end

	local totalSolidOverlaps = 0

	for _, part in ipairs(partsToCheck) do
		local overlappingParts = workspace:GetPartsInPart(part, overlapParams)

		for _, overlapping in ipairs(overlappingParts) do
			if overlapping.CanCollide and overlapping.Transparency < 1 then
				totalSolidOverlaps = totalSolidOverlaps + 1
			end
		end
	end

	if totalSolidOverlaps >= 2 then
		memory.noclipViolations = (memory.noclipViolations or 0) + 1

		if memory.noclipViolations >= 5 then
			trackedPlayer:addStrikes("Noclip", 2)
			self:_correctNoclip(trackedPlayer, rootPart, memory)
			memory.noclipViolations = 0
		end
	else
		if memory.noclipViolations and memory.noclipViolations > 0 then
			memory.noclipViolations = math.max(0, memory.noclipViolations - 0.5)
		end
	end
end

function PhysicsCheck:_checkGravity(trackedPlayer, rootPart)
	for _, child in ipairs(rootPart:GetChildren()) do
		if child:IsA("BodyMover") then
			local isBodyPosition = child:IsA("BodyPosition")
			local isBodyVelocity = child:IsA("BodyVelocity")
			local isBodyGyro = child:IsA("BodyGyro")

			if isBodyPosition or isBodyVelocity or isBodyGyro then
				trackedPlayer:addStrikes("Physics Manipulation", 3)
				child:Destroy()
			end
		end
	end
end

function PhysicsCheck:_correctFly(rootPart, humanoid)
	pcall(function()
		rootPart.AssemblyLinearVelocity = Vector3.new(
			rootPart.AssemblyLinearVelocity.X,
			-50,
			rootPart.AssemblyLinearVelocity.Z
		)
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)
end

function PhysicsCheck:_correctNoclip(trackedPlayer, rootPart, memory)
	if memory.lastPosition then
		pcall(function()
			rootPart.CFrame = CFrame.new(memory.lastPosition)
			rootPart.AssemblyLinearVelocity = Vector3.zero
		end)
	end
end

return PhysicsCheck
