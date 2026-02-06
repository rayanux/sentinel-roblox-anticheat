local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local VelocityCheck = {}

-- config
local SPEED_TOLERANCE = 1.8       -- allow 80% over walkspeed for physics, slopes, momentum
local HARD_SPEED_CAP = 150        -- absolute max studs/check regardless of walkspeed
local MIN_DISTANCE_THRESHOLD = 2  -- ignore tiny movements to prevent noise

local MAX_VERTICAL_GAIN = 10
local FLY_VIOLATION_LIMIT = 3
local SPEED_VIOLATION_LIMIT = 5

function VelocityCheck:check(trackedPlayer, deltaTime)
	if deltaTime <= 0 then
		return
	end

	-- skip during game-allowed teleports
	if trackedPlayer:hasTeleportGrace() then
		local memory = trackedPlayer:getMemory()
		memory.lastPosition = nil
		memory.speedViolations = 0
		memory.flyViolations = 0
		return
	end

	local memory = trackedPlayer:getMemory()
	local character = memory.character

	if not Utility.isCharacterValid(character) then
		return
	end

	-- skip during spawn/deploy (forcefield present)
	local config = trackedPlayer._sentinel._config
	if config.respectForceField and Utility.hasForceField(character) then
		memory.lastPosition = nil
		memory.speedViolations = 0
		memory.flyViolations = 0
		return
	end

	local rootPart = Utility.getRootPart(character)
	local humanoid = Utility.getHumanoid(character)

	if not rootPart or not humanoid then
		return
	end

	-- skip dead or seated players
	if humanoid.Health <= 0 or humanoid.Sit then
		memory.lastPosition = rootPart.Position
		memory.speedViolations = 0
		return
	end

	local currentPos = rootPart.Position
	local lastPos = memory.lastPosition

	memory.lastPosition = currentPos

	if not lastPos then
		return
	end

	-- horizontal distance only for speed check (vertical handled separately)
	local horizontalDelta = Vector3.new(currentPos.X - lastPos.X, 0, currentPos.Z - lastPos.Z)
	local horizontalDistance = horizontalDelta.Magnitude

	if horizontalDistance < MIN_DISTANCE_THRESHOLD then
		memory.speedViolations = math.max((memory.speedViolations or 0) - 1, 0)
		memory.flyViolations = math.max((memory.flyViolations or 0) - 1, 0)
		return
	end

	-- speed check using horizontal movement
	local maxAllowedDistance = humanoid.WalkSpeed * deltaTime * SPEED_TOLERANCE

	-- hard cap catches teleport-like speed regardless of walkspeed
	if horizontalDistance > HARD_SPEED_CAP * deltaTime then
		memory.speedViolations = (memory.speedViolations or 0) + 2

		if memory.speedViolations >= SPEED_VIOLATION_LIMIT then
			trackedPlayer:addStrikes("Extreme Movement", 3)
			self:_hardCorrect(rootPart, humanoid, lastPos)
			memory.speedViolations = 0
		end
		return
	end

	if horizontalDistance > maxAllowedDistance then
		memory.speedViolations = (memory.speedViolations or 0) + 1

		if memory.speedViolations >= SPEED_VIOLATION_LIMIT then
			trackedPlayer:addStrikes("Speed Hack", 1)
			self:_hardCorrect(rootPart, humanoid, lastPos)
			memory.speedViolations = 0
		end
	else
		memory.speedViolations = math.max((memory.speedViolations or 0) - 1, 0)
	end

	-- fly check
	local yDelta = currentPos.Y - lastPos.Y
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local currentState = humanoid:GetState()

	-- skip fly check during jumps, freefall, or climbing
	local isFalling = currentState == Enum.HumanoidStateType.Freefall
	local isJumping = currentState == Enum.HumanoidStateType.Jumping
	local isClimbing = currentState == Enum.HumanoidStateType.Climbing

	if onGround or isFalling or isJumping or isClimbing then
		memory.flyViolations = math.max((memory.flyViolations or 0) - 1, 0)
		return
	end

	if yDelta > MAX_VERTICAL_GAIN then
		memory.flyViolations = (memory.flyViolations or 0) + 1

		if memory.flyViolations >= FLY_VIOLATION_LIMIT then
			trackedPlayer:addStrikes("Fly Hack", 2)
			self:_hardCorrect(rootPart, humanoid, lastPos)
			memory.flyViolations = 0
		end
	else
		memory.flyViolations = math.max((memory.flyViolations or 0) - 1, 0)
	end
end

function VelocityCheck:_hardCorrect(rootPart, humanoid, safePosition)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	task.defer(function()
		pcall(function()
			rootPart.CFrame = CFrame.new(safePosition)
		end)

		task.wait(0.05)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)
end

return VelocityCheck
