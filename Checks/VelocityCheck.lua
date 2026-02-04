local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local VelocityCheck = {}

-- config
local SPEED_TOLERANCE = 1.15 -- 15% tolerance
local SPEED_MULTIPLIER_THRESHOLD = 2.0 -- instant flag if 2x speed
local MIN_CHECK_INTERVAL = 0.1

local CHECKED_STATES = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Freefall] = true,
}

function VelocityCheck:check(trackedPlayer, deltaTime)
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

	local currentState = humanoid:GetState()

	if not CHECKED_STATES[currentState] then
		return
	end

	local velocity = rootPart.AssemblyLinearVelocity
	local xzVelocity = Utility.getXZVelocity(velocity)

	local maxAllowedSpeed = humanoid.WalkSpeed * SPEED_TOLERANCE

	if xzVelocity > humanoid.WalkSpeed * SPEED_MULTIPLIER_THRESHOLD then
		trackedPlayer:addStrikes("Extreme Speed", 3)
		self:_correctVelocity(trackedPlayer, rootPart, humanoid)
		return
	end

	if xzVelocity > maxAllowedSpeed then
		memory.velocityViolations = (memory.velocityViolations or 0) + 1

		if memory.velocityViolations >= 3 then
			trackedPlayer:addStrikes("Speed Hack", 1)
			self:_correctVelocity(trackedPlayer, rootPart, humanoid)
			memory.velocityViolations = 0
		end
	else
		if memory.velocityViolations then
			memory.velocityViolations = math.max(0, memory.velocityViolations - 1)
		end
	end

	memory.lastVelocity = velocity
	memory.lastPosition = rootPart.Position
end

function VelocityCheck:_correctVelocity(trackedPlayer, rootPart, humanoid)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	local memory = trackedPlayer:getMemory()
	if memory.lastPosition then
		pcall(function()
			rootPart.CFrame = CFrame.new(memory.lastPosition)
		end)
	end
end

return VelocityCheck
