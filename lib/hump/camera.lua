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

local _PATH = (...):match('^(.*[%./])[^%.%/]+$') or ''
local cos, sin = math.cos, math.sin

local camera = {}
camera.__index = camera

-- Movement interpolators
local function move_cam(cam, x, y)
	cam.x, cam.y = x, y
end

local function move_cam_with_offset(cam, x, y)
	cam.x, cam.y = x + cam.ox, y + cam.oy
end

-- Get transformation matrix
function camera:getTransformation()
	local x, y, zoom, rot, ox, oy = self.x, self.y, self.scale, self.rot, self.ox, self.oy
	return love.math.newTransform(ox, oy):
		scale(zoom):
		rotate(rot):
		translate(-x, -y)
end

-- Set/get position
function camera:set()
	love.graphics.push()
	love.graphics.applyTransform(self:getTransformation())
end

function camera:unset()
	love.graphics.pop()
end

function camera:move(dx, dy)
	self.x = self.x + (dx or 0)
	self.y = self.y + (dy or 0)
end

function camera:lookAt(x, y)
	self.x = x or self.x
	self.y = y or self.y
end

function camera:position()
	return self.x, self.y
end

-- Rotation
function camera:rotate(phi)
	self.rot = self.rot + phi
end

function camera:rotateTo(phi)
	self.rot = phi
end

function camera:getRotation()
	return self.rot
end

-- Scale/Zoom
function camera:zoom(mul)
	self.scale = self.scale * mul
end

function camera:zoomTo(zoom)
	self.scale = zoom
end

function camera:getScale()
	return self.scale
end

-- Screen to world coordinates
function camera:worldCoords(x, y)
	local t = self:getTransformation():inverse()
	return t:transformPoint(x, y)
end

-- World to screen coordinates
function camera:screenCoords(x, y)
	local t = self:getTransformation()
	return t:transformPoint(x, y)
end

-- Constructor
local function new(x, y, zoom, rot, ox, oy)
	x, y = x or love.graphics.getWidth()/2, y or love.graphics.getHeight()/2
	zoom = zoom or 1
	rot = rot or 0
	ox, oy = ox or love.graphics.getWidth()/2, oy or love.graphics.getHeight()/2
	return setmetatable({x = x, y = y, scale = zoom, rot = rot, ox = ox, oy = oy}, camera)
end

-- Module
return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})