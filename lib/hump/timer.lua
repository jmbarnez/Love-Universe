--[[
Copyright (c) 2010-2013 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local Timer = {}
Timer.__index = Timer

local function _call(self, ...)
	return self:new(...)
end

local function after(delay, func)
	return function(dt)
		delay = delay - dt
		if delay <= 0 then
			func()
			return true
		end
	end
end

local function every(delay, func)
	local timer = delay
	return function(dt)
		timer = timer - dt
		if timer <= 0 then
			func()
			timer = timer + delay
		end
	end
end

local function during(delay, func, after_func)
	local timer = delay
	return function(dt)
		if timer > 0 then
			timer = timer - dt
			func(dt)
		else
			if after_func then after_func() end
			return true
		end
	end
end

function Timer:new()
	return setmetatable({functions = {}}, Timer)
end

function Timer:update(dt)
	local delete = {}
	for handle, func in pairs(self.functions) do
		if func(dt) then
			delete[#delete+1] = handle
		end
	end
	for i = 1, #delete do
		self.functions[delete[i]] = nil
	end
end

function Timer:clear()
	self.functions = {}
end

function Timer:after(delay, func)
	local handle = after(delay, func)
	self.functions[handle] = handle
	return handle
end

function Timer:every(delay, func)
	local handle = every(delay, func)
	self.functions[handle] = handle
	return handle
end

function Timer:during(delay, func, after_func)
	local handle = during(delay, func, after_func)
	self.functions[handle] = handle
	return handle
end

function Timer:cancel(handle)
	self.functions[handle] = nil
end

-- Default timer
local default = Timer:new()

Timer.after = function(delay, func) return default:after(delay, func) end
Timer.every = function(delay, func) return default:every(delay, func) end
Timer.during = function(delay, func, after_func) return default:during(delay, func, after_func) end
Timer.update = function(dt) return default:update(dt) end
Timer.clear = function() return default:clear() end
Timer.cancel = function(handle) return default:cancel(handle) end

return setmetatable(Timer, {__call = _call})