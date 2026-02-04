local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local RotationCheck = {}

-- config
local MAX_ANGULAR_VELOCITY = 50 -- max angular velocity magnitude
local EXTREME_ANGULAR_VELOCITY = 100 -- instant flag threshold
local DECAY_RATE = 0.5 -- rate at which to decay violations

function RotationCheck:check(trackedPlayer, deltaTime)
	local memory = trackedPlayer:getMemory()
	local character = memory.character

	if not Utility.isCharacterValid(character) then
		return
	end

	local rootPart = Utility.getRootPart(character)
	if not rootPart then
		return
	end

	local angularVelocity = rootPart.AssemblyAngularVelocity
	local magnitude = angularVelocity.Magnitude

	if magnitude > EXTREME_ANGULAR_VELOCITY then
		trackedPlayer:addStrikes("Extreme Spin", 3)
		self:_correctRotation(rootPart)
		memory.rotationViolations = 0
		return
	end

	if magnitude > MAX_ANGULAR_VELOCITY then
		memory.rotationViolations = (memory.rotationViolations or 0) + 1

		if memory.rotationViolations >= 3 then
			trackedPlayer:addStrikes("Spin Bot", 1)
			self:_correctRotation(rootPart)
			memory.rotationViolations = 0
		end
	else
		if memory.rotationViolations and memory.rotationViolations > 0 then
			memory.rotationViolations = math.max(0, memory.rotationViolations - DECAY_RATE)
		end
	end
end

function RotationCheck:_correctRotation(rootPart)
	pcall(function()
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end)
end

return RotationCheck
