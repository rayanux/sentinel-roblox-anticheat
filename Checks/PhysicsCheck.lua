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

	local rootPart = Utility.getRootPart(character)
	local humanoid = Utility.getHumanoid(character)

	if not rootPart or not humanoid then
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

	if isInAir or isMovingUp then
		memory.airTime = (memory.airTime or 0) + deltaTime
	else
		memory.airTime = 0
		return
	end

	if memory.airTime > MAX_AIR_TIME then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {memory.character}

		local rayResult = workspace:Raycast(
			rootPart.Position,
			Vector3.new(0, -20, 0),
			raycastParams
		)

		if not rayResult then
			trackedPlayer:addStrikes("Fly Hack", 2)
			self:_correctFly(rootPart, humanoid)
			memory.airTime = 0
		end
	end
end

function PhysicsCheck:_checkNoclip(trackedPlayer, character, rootPart)
	local memory = trackedPlayer:getMemory()

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.MaxParts = 10

	local overlappingParts = workspace:GetPartsInPart(rootPart, overlapParams)

	local solidPartsCount = 0
	for _, part in ipairs(overlappingParts) do
		if part.CanCollide then
			solidPartsCount = solidPartsCount + 1
		end
	end

	if solidPartsCount >= 2 then
		memory.noclipViolations = (memory.noclipViolations or 0) + 1

		if memory.noclipViolations >= 3 then
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
