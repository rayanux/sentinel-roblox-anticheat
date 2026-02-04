local Utility = {}

function Utility.deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = Utility.deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function Utility.mergeTables(a, b)
	local result = Utility.deepCopy(a)
	for k, v in pairs(b) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = Utility.mergeTables(result[k], v)
		else
			result[k] = v
		end
	end
	return result
end

function Utility.clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

function Utility.isCharacterValid(character)
	if not character then return false end
	if not character:IsDescendantOf(workspace) then return false end
	if not character.PrimaryPart then return false end

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	return true
end

function Utility.getRootPart(character)
	if not character then return nil end
	return character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
end

function Utility.getHumanoid(character)
	if not character then return nil end
	return character:FindFirstChildWhichIsA("Humanoid")
end

function Utility.getXZVelocity(velocity)
	return (velocity * Vector3.new(1, 0, 1)).Magnitude
end

function Utility.getTime()
	return os.time()
end

function Utility.formatString(str, params)
	for key, value in pairs(params) do
		str = string.gsub(str, "{" .. key .. "}", tostring(value))
	end
	return str
end

function Utility.tableContains(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

function Utility.randomString(length)
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	local result = {}
	for i = 1, length do
		local rand = math.random(1, #chars)
		table.insert(result, string.sub(chars, rand, rand))
	end
	return table.concat(result)
end

function Utility.safePcall(func, ...)
	local success, result = pcall(func, ...)
	if not success then
		warn("[SentinelAC] Error:", result)
	end
	return success, result
end

return Utility
