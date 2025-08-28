--[[
MIT License

Copyright (c) 2016 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local suit = {}
suit._VERSION = "0.1"

-- internal id management
local _id_stack = {}
local function get_id(info)
  local id = {}
  for i = #_id_stack, 1, -1 do
    id[i] = _id_stack[i]
  end
  id[#id+1] = info
  return id
end

local function id_tostring(id)
  local t = {}
  for i,v in ipairs(id) do
    t[i] = tostring(v)
  end
  return table.concat(t, "/")
end

local function same_id(a, b)
  if #a ~= #b then return false end
  for i = 1,#a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

-- state management
local function Button(info, ...)
  info = info or {}
  local id = get_id(info.id or tostring(info) .. table.concat({...}))
  
  -- state
  local entered, hit = false, false
  if suit.mouse_in_rect(...) then
    suit.state.hovered = id
    if suit.mouse_hit() then
      hit = true
    end
  end
  
  if same_id(id, suit.state.hovered) then
    entered = suit.mouse_hit() or entered
  end
  
  if hit then
    suit.state.hit = id
  end
  
  local down = same_id(id, suit.state.hit) and love.mouse.isDown(1)
  entered = same_id(id, suit.state.hit) and not down and entered
  
  return {
    id = id,
    info = info,
    hit = entered,
    hovered = same_id(id, suit.state.hovered),
    down = down,
  }
end

local function Input(info, x, y, w, h)
  info = info or {}
  local id = get_id(info.id or info.text)
  
  -- state
  local text = info.text or ""
  local entered, hit = false, false
  
  if suit.mouse_in_rect(x, y, w, h) then
    suit.state.hovered = id
    if suit.mouse_hit() then
      hit = true
    end
  end
  
  if hit then
    suit.state.focused = id
  end
  
  local focused = same_id(id, suit.state.focused)
  
  if focused and suit.state.textinput then
    text = text .. suit.state.textinput
  end
  
  if focused and love.keyboard.isDown("backspace") and suit.state.backspace_time <= 0 then
    text = text:sub(1, -2)
    suit.state.backspace_time = 0.5
  end
  
  return {
    id = id,
    info = info,
    text = text,
    focused = focused,
    hovered = same_id(id, suit.state.hovered),
  }
end

-- theme
local theme = {}

-- Button theme
function theme.Button(arg, opt, x, y, w, h)
  local c = {
    normal  = {bg = {0.25,0.25,0.25}, fg = {0.73,0.73,0.73}, border = {0.13,0.13,0.13}},
    hovered = {bg = {0.19,0.55,0.75}, fg = {0.86,0.86,0.86}, border = {0.13,0.13,0.13}},
    active  = {bg = {0.05,0.32,0.47}, fg = {1,1,1}, border = {0.13,0.13,0.13}}
  }
  local color = c.normal
  if arg.hovered then
    color = c.hovered
  end
  if arg.down then
    color = c.active
  end

  love.graphics.setColor(color.bg)
  love.graphics.rectangle("fill", x+1, y+1, w-2, h-2)

  love.graphics.setColor(color.border)
  love.graphics.rectangle("line", x, y, w-1, h-1)

  love.graphics.setColor(color.fg)
  local f = love.graphics.getFont()
  love.graphics.printf(opt.text or "", x, y + (h - f:getHeight()) / 2, w, "center")
end

-- Input theme
function theme.Input(arg, opt, x, y, w, h)
  local c = {
    normal  = {bg = {0.13,0.13,0.13}, fg = {0.73,0.73,0.73}, border = {0.25,0.25,0.25}},
    focused = {bg = {0.16,0.16,0.16}, fg = {0.86,0.86,0.86}, border = {0.39,0.39,0.39}},
  }
  local color = c.normal
  if arg.focused then
    color = c.focused
  end

  love.graphics.setColor(color.bg)
  love.graphics.rectangle("fill", x+1, y+1, w-2, h-2)

  love.graphics.setColor(color.border)
  love.graphics.rectangle("line", x, y, w-1, h-1)

  love.graphics.setColor(color.fg)
  local f = love.graphics.getFont()
  local text = arg.text or ""
  if arg.focused then
    text = text .. "|"
  end
  love.graphics.printf(text, x+2, y + (h - f:getHeight()) / 2, w-4, "left")
end

-- Label theme
function theme.Label(arg, opt, x, y, w, h)
  local c = {
    normal = {fg = {0.73,0.73,0.73}},
  }
  
  love.graphics.setColor(c.normal.fg)
  local f = love.graphics.getFont()
  love.graphics.printf(opt.text or "", x, y + (h - f:getHeight()) / 2, w, opt.align or "left")
end

suit.theme = theme

-- state
suit.state = {
  hovered = {},
  focused = {},
  hit = {},
  textinput = "",
  backspace_time = 0,
}

-- helper functions
function suit.mouse_in_rect(x, y, w, h)
  local mx, my = love.mouse.getPosition()
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function suit.mouse_hit()
  return love.mouse.isDown(1) and not suit.state.mouse_down
end

-- event handling
function suit.mousepressed(x, y, button)
  suit.state.mouse_down = true
end

function suit.mousereleased(x, y, button)
  suit.state.mouse_down = false
end

function suit.textinput(t)
  suit.state.textinput = (suit.state.textinput or "") .. t
end

function suit.keypressed(key)
  if key == "backspace" then
    suit.state.backspace_time = 0
  end
end

function suit.update(dt)
  suit.state.backspace_time = math.max(0, (suit.state.backspace_time or 0) - dt)
  suit.state.textinput = ""
end

-- widgets
function suit.Button(info, opt, x, y, w, h)
  local arg = Button(info, x, y, w, h)
  
  if opt.draw ~= false then
    love.graphics.push("all")
    suit.theme.Button(arg, opt, x, y, w, h)
    love.graphics.pop()
  end
  
  return arg
end

function suit.Input(info, opt, x, y, w, h)
  local arg = Input(info, x, y, w, h)
  
  if opt.draw ~= false then
    love.graphics.push("all")
    suit.theme.Input(arg, opt, x, y, w, h)
    love.graphics.pop()
  end
  
  -- update info
  if info then
    info.text = arg.text
  end
  
  return arg
end

function suit.Label(info, opt, x, y, w, h)
  if opt.draw ~= false then
    love.graphics.push("all")
    suit.theme.Label({}, opt, x, y, w, h)
    love.graphics.pop()
  end
end

return suit