local HttpService = game:GetService("HttpService")

local Logger = {}
Logger.__index = Logger

local LOG_LEVELS = {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
	CRITICAL = 4,
	SUCCESS = 5,
}

local LOG_COLORS = {
	[LOG_LEVELS.DEBUG] = "\27[36m",    -- Cyan
	[LOG_LEVELS.INFO] = "\27[37m",     -- White
	[LOG_LEVELS.WARN] = "\27[33m",     -- Yellow
	[LOG_LEVELS.ERROR] = "\27[31m",    -- Red
	[LOG_LEVELS.CRITICAL] = "\27[35m", -- Magenta
	[LOG_LEVELS.SUCCESS] = "\27[32m",  -- Green
}

local RESET_COLOR = "\27[0m"

function Logger.new(config)
	local self = setmetatable({
		_config = config,
		_logHistory = {},
		_maxHistorySize = 100,
	}, Logger)

	return self
end

function Logger:_formatMessage(level, message)
	local timestamp = os.date("%H:%M:%S")
	local levelName = ""

	for name, lvl in pairs(LOG_LEVELS) do
		if lvl == level then
			levelName = name
			break
		end
	end

	local color = LOG_COLORS[level] or ""
	local formattedMessage = string.format("%s[SentinelAC][%s][%s]%s %s",
		color, timestamp, levelName, RESET_COLOR, message)

	return formattedMessage
end

function Logger:_log(level, message, ...)
	if not self._config.logToConsole then
		return
	end

	local formattedMsg = string.format(message, ...)
	local finalMessage = self:_formatMessage(level, formattedMsg)

	table.insert(self._logHistory, {
		timestamp = os.time(),
		level = level,
		message = formattedMsg,
	})

	if #self._logHistory > self._maxHistorySize then
		table.remove(self._logHistory, 1)
	end

	if level >= LOG_LEVELS.ERROR then
		warn(finalMessage)
	else
		print(finalMessage)
	end

	if self._config.webhookUrl and level >= LOG_LEVELS.WARN then
		self:_sendWebhook(level, formattedMsg)
	end
end

function Logger:_sendWebhook(level, message)
	if not self._config.webhookUrl then return end

	task.spawn(function()
		local success, err = pcall(function()
			local levelName = ""
			for name, lvl in pairs(LOG_LEVELS) do
				if lvl == level then
					levelName = name
					break
				end
			end

			local color = 0
			if level == LOG_LEVELS.WARN then
				color = 16776960 -- Yellow
			elseif level == LOG_LEVELS.ERROR then
				color = 16711680 -- Red
			elseif level == LOG_LEVELS.CRITICAL then
				color = 8388736  -- Purple
			end

			local payload = {
				embeds = {{
					title = "SentinelAC Alert",
					description = message,
					color = color,
					fields = {
						{
							name = "Level",
							value = levelName,
							inline = true
						},
						{
							name = "Time",
							value = os.date("%Y-%m-%d %H:%M:%S"),
							inline = true
						}
					},
					footer = {
						text = "SentinelAC v2.0"
					}
				}}
			}

			HttpService:PostAsync(
				self._config.webhookUrl,
				HttpService:JSONEncode(payload),
				Enum.HttpContentType.ApplicationJson
			)
		end)

		if not success then
			warn("[Logger] Failed to send webhook:", err)
		end
	end)
end

function Logger:debug(message, ...)
	if self._config.verboseLogging then
		self:_log(LOG_LEVELS.DEBUG, message, ...)
	end
end

function Logger:info(message, ...)
	self:_log(LOG_LEVELS.INFO, message, ...)
end

function Logger:warn(message, ...)
	self:_log(LOG_LEVELS.WARN, message, ...)
end

function Logger:error(message, ...)
	self:_log(LOG_LEVELS.ERROR, message, ...)
end

function Logger:critical(message, ...)
	self:_log(LOG_LEVELS.CRITICAL, message, ...)
end

function Logger:success(message, ...)
	self:_log(LOG_LEVELS.SUCCESS, message, ...)
end

function Logger:getHistory()
	return self._logHistory
end

return Logger
