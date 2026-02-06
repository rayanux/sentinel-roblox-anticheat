# SentinelAC
SentinelAC is a server-authoritative anti-cheat system for Roblox games. It focuses on detecting common exploit behaviors while remaining performant and configurable for live production servers.
## Features
* Server-side validation with optional client integrity checks
* Speed, fly, noclip, teleport, and rotation detection
* Tool, humanoid state, and physics abuse checks
* Client tampering / executor behavior detection
* Progressive strike-based enforcement with decay
* Whitelist support for admins and trusted players
* Event-driven API for custom moderation logic
* ForceField-aware spawn/deploy detection (automatic)
* Teleport grace API for scripted movement systems
* Optional Discord webhook logging
* Studio-safe (client checks auto-disabled)
## Installation
Place the system inside `ServerScriptService`:
```
ServerScriptService/
├── InitSentinelAC (Script)
└── SentinelAC/
    ├── SentinelAC (ModuleScript)
    ├── Core/
    ├── Player/
    ├── Checks/
    └── Client/
```
## Usage
```lua
local SentinelAC = require(script.Parent.SentinelAC)
local sentinel = SentinelAC.getInstance()
sentinel:initialize()
```
The system will automatically begin tracking players once initialized.
## Configuration
Pass only the values you want to override. Everything else uses defaults.
```lua
sentinel:initialize({
    maxStrikes = 10,
    strikeCooldown = 60,
    strikeDecayRate = 1,
    enableClientChecks = true,
    clientHeartbeatTimeout = 10,
    enableVelocityCheck = true,
    enableTeleportCheck = true,
    enablePhysicsCheck = true,
    enableRotationCheck = true,
    enableStateCheck = true,
    enableToolCheck = true,
    checkInterval = 0.1,
    maxPlayersPerFrame = 5,
    autoKick = true,
    kickMessage = "Detected: {reason}",
    respectForceField = true,
    whitelistedUserIds = {},
    webhookUrl = nil,
})
```
All checks can be enabled or disabled individually.
## API
```lua
sentinel:whitelistPlayer(player)
sentinel:unwhitelistPlayer(player)
sentinel:flagPlayer(player, "Reason", 3)
sentinel:pardonPlayer(player, "Reason", 2)
sentinel:allowTeleport(player, 2) -- grace period in seconds

sentinel:on("onPlayerFlagged", function(player, reason, strikes) end)
sentinel:on("onPlayerKicked", function(player, reason, strikes) end)
sentinel:on("onStrikeAdded", function(player, reason, count, total) end)
```
## Integration
SentinelAC is designed to work with any game without modification. Two systems handle scripted movement:
### ForceField Detection (Automatic)
If your game gives players a ForceField on spawn or deploy, all movement checks are automatically paused until it expires. Most Roblox games already do this. No code changes needed.
Controlled by `respectForceField = true` (default).
### Teleport Grace (Manual)
For teleports that don't use a ForceField, call `allowTeleport` before moving the player:
```lua
sentinel:allowTeleport(player, 2)
player.Character.HumanoidRootPart.CFrame = destination
```
This pauses all movement checks for the given duration and resets position tracking so the player isn't flagged after the grace ends.
### Whitelist via Config
Pass user IDs directly in the config to whitelist players immediately on join with no race conditions:
```lua
sentinel:initialize({
    whitelistedUserIds = {123456, 789012},
})
```
## Strike Model
* Players start at 0 strikes
* Violations add strikes based on severity
* Strikes decay over time (1 strike per 60 seconds by default)
* Players are kicked when the maximum is reached
* Decay removes a fixed total per cycle, not per violation type
This reduces false positives from latency and physics edge cases.
## Performance
* <1% server CPU usage (≈100 players)
* ~2 MB memory usage
* Default: 10 checks/sec per player
* Player checking rotates each frame so all players are covered evenly
For large servers:
```lua
sentinel:initialize({
    checkInterval = 0.2,
    maxPlayersPerFrame = 3,
})
```
## Notes
* Client checks are disabled automatically in Studio
* ForceField detection handles most spawn/deploy systems automatically
* Use `allowTeleport` for any scripted movement that doesn't use a ForceField
* Test with conservative settings before deployment
