libTimer_VERSION = 0.1 -- Any way to fetch this from TOC?

local timers = {}
local timers_index = {}
local repeatables = {}
local next_timer = nil

local DEBUG = 0

function libTimer_SetDebug(level)
	DEBUG = level
end

local function debug(text, level)
	if level and level <= DEBUG then
		print("Debug ("..level.."): " .. text)
	end
end

local function UpdateIndex()
	timers_index = {}
	for n in pairs(timers) do table.insert(timers_index, n) end
	table.sort(timers_index)
	debug("Index updated!", 5)
end

function StopTimer(runtime)
	if timers[runtime] then
		timers[runtime] = nil
	elseif repeatables[runtime] then
		timers[repeatables[runtime]] = nil
		repeatables[runtime] = nil
	else
		debug("Error, timer " .. runtime .. " not found!", 1)
	end
	UpdateIndex()
end

local function getUpTo(maxtime)
	local i = 0
	local iter = function ()
		i = i + 1
		if timers_index[i] == nil then return nil
		elseif timers_index[i] > maxtime then return nil
		else
			return timers_index[i], timers[timers_index[i]]
		end
	end
	return iter
end

local function getFirstUpto(maxtime)
	return getUpTo(maxtime)()
end

local function refresh()
	if not next_timer then return end
	local now = Inspect.Time.Real()
	if next_timer <= now then
		debug("Finding stuff to run..", 3)
		for k, v in getUpTo(now) do
			debug("Starting task!", 7)
			v.callback(v.param)
			timers[k] = nil
			if v.repeating then
				debug("Re-setting repeating task", 8)
				timers[now + v.duration] = v
				repeatables[v.repeatkey] = now + v.duration
			end
		end
		UpdateIndex()
		next_timer = timers_index[1]
	end
end

function StartTimer(duration, callback, param, repeating)
	local now = Inspect.Time.Real()
	local runtime = now + duration
	local addtable = {}
	
	addtable.callback = callback
	addtable.param = param
	addtable.duration = duration
	addtable.repeating = repeating
	if repeating then addtable.repeatkey = runtime end
	timers[runtime] = addtable
	
	debug("Timer added!", 5)
	
	UpdateIndex()
	next_timer = timers_index[1]
	return runtime
end

table.insert(Event.System.Update.Begin, {refresh, "libTimer", "refresh"})