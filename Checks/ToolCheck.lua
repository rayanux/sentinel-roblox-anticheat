local Utility = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Utility"))

local ToolCheck = {}

function ToolCheck:init(sentinelAC)
	self._sentinel = sentinelAC
end

function ToolCheck:check(trackedPlayer, deltaTime)
	local memory = trackedPlayer:getMemory()
	local character = memory.character

	if not Utility.isCharacterValid(character) then
		return
	end

	if not memory.toolCheckSetup then
		self:_setupToolMonitoring(trackedPlayer, character)
		memory.toolCheckSetup = true
	end

	self:_checkMultipleTools(trackedPlayer, character)
end

function ToolCheck:_setupToolMonitoring(trackedPlayer, character)
	local memory = trackedPlayer:getMemory()
	memory.normalEquips = 0
	memory.toolEquipTimes = {}

	-- Monitor child additions to character
	local connection = character.ChildAdded:Connect(function(child)
		self:_onChildAdded(trackedPlayer, character, child)
	end)

	memory.toolConnection = connection
end

function ToolCheck:_onChildAdded(trackedPlayer, character, child)
	if not child:IsA("BackpackItem") then
		return
	end

	-- skip during deploy (tools are given at once)
	local config = self._sentinel._config
	if config.respectForceField and Utility.hasForceField(character) then
		return
	end

	local memory = trackedPlayer:getMemory()
	local currentTime = tick()

	if memory.lastToolEquipTime then
		local timeSinceLastEquip = currentTime - memory.lastToolEquipTime

		if timeSinceLastEquip < 0.1 then
			memory.rapidEquips = (memory.rapidEquips or 0) + 1

			if memory.rapidEquips >= 3 then
				trackedPlayer:addStrikes("Tool Spam", 1)
				memory.rapidEquips = 0
			end
		else
			memory.rapidEquips = 0
		end
	end

	memory.lastToolEquipTime = currentTime
	memory.normalEquips = (memory.normalEquips or 0) + 1

	if memory.normalEquips > 5 then
		memory.normalEquips = 0
	end
end

function ToolCheck:_checkMultipleTools(trackedPlayer, character)
	-- skip during deploy
	local config = self._sentinel._config
	if config.respectForceField and Utility.hasForceField(character) then
		return
	end

	local equippedTools = {}

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BackpackItem") then
			table.insert(equippedTools, child)
		end
	end

	if #equippedTools > 1 then
		trackedPlayer:addStrikes("Multiple Tools", 3)

		local humanoid = Utility.getHumanoid(character)
		if humanoid then
			pcall(function()
				humanoid:UnequipTools()
			end)
		end

		self._sentinel._logger:debug("Player %s had %d tools equipped", 
			trackedPlayer.player.Name, #equippedTools)
	end
end

return ToolCheck
