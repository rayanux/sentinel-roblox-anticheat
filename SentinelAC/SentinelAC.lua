local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SentinelAC = {}
SentinelAC.__index = SentinelAC

local Utility = require(script:WaitForChild("Core"):WaitForChild("Utility"))
local Logger = require(script:WaitForChild("Core"):WaitForChild("Logger"))
local PlayerTracker = require(script:WaitForChild("Core"):WaitForChild("PlayerTracker"))
local CheckManager = require(script:WaitForChild("Core"):WaitForChild("CheckManager"))

local ActiveInstance = nil
local IsInitialized = false

-- default config
local DEFAULT_CONFIG = {
	-- strike system
	maxStrikes = 10,              -- kicks at 10 strikes
	strikeCooldown = 60,          -- decay every 60 seconds
	strikeDecayRate = 1,          -- remove 1 strike per decay

	-- client protection
	enableClientChecks = true,
	clientHeartbeatTimeout = 10,

	-- detection toggles
	enableVelocityCheck = true,   -- speed hacks
	enableRotationCheck = true,   -- spin bots
	enableStateCheck = true,      -- invalid states
	enableToolCheck = true,       -- multi tool exploits
	enablePhysicsCheck = true,    -- fly and noclip
	enableTeleportCheck = true,   -- teleportation

	-- performance
	checkInterval = 0.1,
	maxPlayersPerFrame = 5,

	-- logging
	verboseLogging = true,
	logToConsole = true,

	-- kick settings
	kickMessage = "Suspicious activity detected. Code: {reason}",
	autoKick = true,

	-- integration
	respectForceField = true,     -- skip checks during forcefield (deploy/spawn)

	-- discord webhook
	webhookUrl = nil, -- "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"

	-- whitelist
	whitelistedUserIds = {},
}

function SentinelAC.getInstance()
	if not ActiveInstance then
		ActiveInstance = setmetatable({
			_config = Utility.deepCopy(DEFAULT_CONFIG),
			_logger = nil,
			_playerTracker = nil,
			_checkManager = nil,
			_callbacks = {
				onPlayerFlagged = {},
				onPlayerKicked = {},
				onStrikeAdded = {},
			},
		}, SentinelAC)
	end
	return ActiveInstance
end

function SentinelAC:initialize(config)
	if IsInitialized then
		warn("[SentinelAC] Already initialized!")
		return false
	end

	if config then
		self._config = Utility.mergeTables(self._config, config)
	end

	self._logger = Logger.new(self._config)
	self._playerTracker = PlayerTracker.new(self)
	self._checkManager = CheckManager.new(self)

	self._logger:info("Initializing SentinelAC v2.0...")

	self._playerTracker:initialize()
	self._checkManager:initialize()

	self:_setupAntiTamper()

	IsInitialized = true
	self._logger:success("SentinelAC initialized successfully!")

	return true
end

function SentinelAC:on(eventName, callback)
	if self._callbacks[eventName] then
		table.insert(self._callbacks[eventName], callback)
	else
		self._logger:warn("Unknown event: " .. tostring(eventName))
	end
end

function SentinelAC:_triggerCallbacks(eventName, ...)
	local callbacks = self._callbacks[eventName]
	if callbacks then
		for _, callback in ipairs(callbacks) do
			task.spawn(callback, ...)
		end
	end
end

-- get tracked player
function SentinelAC:getPlayer(player)
	if not IsInitialized then
		self._logger:warn("Cannot get player - SentinelAC not initialized")
		return nil
	end
	return self._playerTracker:getPlayer(player)
end

-- manually flag
function SentinelAC:flagPlayer(player, reason, strikes)
	local trackedPlayer = self:getPlayer(player)
	if trackedPlayer then
		trackedPlayer:addStrikes(reason, strikes or 1)
	end
end

-- remove strikes
function SentinelAC:pardonPlayer(player, reason, strikes)
	local trackedPlayer = self:getPlayer(player)
	if trackedPlayer then
		trackedPlayer:removeStrikes(reason, strikes or 1)
	end
end

-- whitelist a player
function SentinelAC:whitelistPlayer(player)
	local trackedPlayer = self:getPlayer(player)
	if trackedPlayer then
		trackedPlayer:setWhitelisted(true)
		self._logger:info("Whitelisted player: " .. player.Name)
	end
end

-- remove player from whitelist
function SentinelAC:unwhitelistPlayer(player)
	local trackedPlayer = self:getPlayer(player)
	if trackedPlayer then
		trackedPlayer:setWhitelisted(false)
		self._logger:info("Removed whitelist for player: " .. player.Name)
	end
end

-- temporarily allow a teleport without flagging
function SentinelAC:allowTeleport(player, duration)
	local trackedPlayer = self:getPlayer(player)
	if trackedPlayer then
		trackedPlayer:grantTeleportGrace(duration or 1)
	end
end

-- anti tamper
function SentinelAC:_setupAntiTamper()
	local originalParent = script.Parent

	-- protect main script
	script.AncestryChanged:Connect(function()
		if script.Parent ~= originalParent then
			self._logger:critical("TAMPER DETECTED: Main script moved!")
			pcall(function()
				script.Parent = originalParent
			end)
		end
	end)

	for _, descendant in ipairs(script:GetDescendants()) do
		if descendant:IsA("ModuleScript") then
			local origParent = descendant.Parent
			descendant.AncestryChanged:Connect(function()
				if descendant.Parent ~= origParent then
					self._logger:critical("TAMPER DETECTED: Module moved - " .. descendant.Name)
					pcall(function()
						descendant.Parent = origParent
					end)
				end
			end)
		end
	end
end

function SentinelAC:shutdown()
	if not IsInitialized then
		return
	end

	self._logger:info("Shutting down SentinelAC...")

	if self._checkManager then
		self._checkManager:shutdown()
	end

	if self._playerTracker then
		self._playerTracker:shutdown()
	end

	IsInitialized = false
	self._logger:success("SentinelAC shutdown complete")
end

return SentinelAC
