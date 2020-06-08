local Anchor = require 'Resources.lib.hanker.anchor'

local Font = {}
local Font_mt = {__index = Font}

-- @function Context:newFont
-- @desc Creates a new font from an existing love2d font.
-- @param loveFont an existing ttf/image font
-- @return HankerFont
function Font.new(loveFont)
	local self = setmetatable({font=loveFont}, Font_mt)
	return self
end

function Font:newText()
	return love.graphics.newText(self.font)
end

function Font:getDefaultTextSize()
	return self.font:getAscent()
end

function Font:setFallbackFont(fontObject)
	self.fallback = fontObject
	return self
end

function Font:getFallbackFont()
	return self.fallback
end

function Font:getTextHeight(textSize)
	local scale = (textSize / self.font:getAscent())
	return self.font:getHeight() * scale
end

function Font:getTextWidth(text, textSize)
	local scale = (textSize / self.font:getAscent())
	local textWidth = self.textObject:getWidth(text)
	return textWidth * scale
end

function Font:setf(textObject, text, w, textSize, textAlignX)
	local scale = (textSize / self.font:getAscent())
	w = w / scale
	textObject:setf(text, w, textAlignX or 'left')
	local textWidth, textHeight = textObject:getDimensions()
	textWidth = textWidth * scale
	textHeight = textHeight * scale
	return w, textWidth, textHeight
end

function Font:draw(textObject, x, y, textSize)
	local scale = Anchor.xMultiplier * (textSize / self.font:getAscent())
	local floorX, floorY = math.floor(x), math.floor(y)
	love.graphics.draw(textObject, floorX, floorY, 0, scale)
end

local MSDFFont = {}
local MSDFFont_mt = {__index = MSDFFont}

-- @function Context:newMSDFFont
-- @desc Creates a new font from an existing MSDF image font.
-- MSDF fonts can be scaled up and down visually with fewer artifacts,
-- making it a good choice for text in 3D or heavily animated environments.
-- @param loveFont an existing image font
-- @param nativeSize the size the font is authored to take up
-- @param sharpness
-- @return HankerFont
function MSDFFont.new(loveFont, nativeSize, sharpness)
	local self = setmetatable({
		font = loveFont,
		nativeSize = nativeSize,
		sharpness = sharpness or .8,
	}, MSDFFont_mt)
	return self
end

function MSDFFont:newText()
	return love.graphics.newText(self.font)
end

function MSDFFont:getDefaultTextSize()
	return self.overrideTextSize or self.nativeSize
end

function MSDFFont:setDefaultTextSize(overrideTextSize)
	self.overrideTextSize = overrideTextSize
	return self
end

function MSDFFont:setFallbackFont(fontObject)
	self.fallback = fontObject
	return self
end

function MSDFFont:getFallbackFont()
	return self.fallback
end

function MSDFFont:getTextHeight(textSize)
	local msdfScale = textSize / self.nativeSize
	return self.font:getHeight() * msdfScale
end

function MSDFFont:getTextWidth(text, textSize)
	local msdfScale = textSize / self.nativeSize
	local textWidth = self.font:getWidth(text)
	return textWidth * msdfScale
end

function MSDFFont:setf(textObject, text, rectWidth, textSize, textAlignX)
	local msdfScale = textSize / self.nativeSize
	local computedWidth = rectWidth / msdfScale

	textObject:setf(text, computedWidth, textAlignX)
	local textWidth, textHeight = textObject:getDimensions()
	textWidth = textWidth * msdfScale
	textHeight = textHeight * msdfScale
	return computedWidth, textWidth, textHeight
end

local msdfShader = love.graphics.newShader([[
uniform float pxRange = 12;
uniform vec2 texSize = vec2(512, 512);

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

vec4 effect(vec4 fgColor, Image tex, vec2 texCoords, vec2 pixelCoords)
{
    vec2 msdfUnit = pxRange/texSize;
    vec3 s = texture2D(tex, texCoords).rgb;
    float sigDist = median(s.r, s.g, s.b) - 0.5;
    sigDist *= dot(msdfUnit, 0.5/fwidth(texCoords));
    float opacity = clamp(sigDist + 0.5, 0.0, 1.0);
	vec4 bgColor = vec4(fgColor.rgb, 0);
    return mix(bgColor, fgColor, opacity);
}
]])

local xoff = -5 -- my msdf font seems to be ever so slightly not centered?

function MSDFFont:draw(textObject, x, y, textSize)
	msdfShader:send("pxRange", math.floor(self.sharpness * self.nativeSize))
	love.graphics.setShader(msdfShader)
	local scale = Anchor.xMultiplier * (textSize / self.nativeSize)
	local floorX, floorY = math.floor(x+(xoff*scale)), math.floor(y)
	love.graphics.draw(textObject, floorX, floorY, 0, scale)
	love.graphics.setShader()
end

-- TODO: create a Font type that can support multiple sizes from a single TTF file
return {Font = Font, MSDFFont = MSDFFont}
