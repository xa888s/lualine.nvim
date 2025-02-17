local utils = require 'lualine.utils.utils'

---------------
-- Constents --
---------------
-- fg and bg must have this much contrast range 0 < contrast_threshold < 0.5
local contrast_threshold = 0.3
-- how much brightness is changed in percentage for light and dark themes
local brightness_modifier_parameter = 10

-- retrives color value from highlight group name in syntax_list
-- first present highlight is returned
local function getHi(scope, syntaxlist)
  for _, highlight_name in pairs(syntaxlist) do
    if vim.fn.hlexists(highlight_name) ~= 0 then
      local color = utils.extract_highlight_colors(highlight_name)
      if color.reverse then
        if scope == 'bg' then
          scope = 'fg'
        else
          scope = 'bg'
        end
      end
      if color[scope] then return color[scope] end
    end
  end
  return '#000000'
end

-- truns #rrggbb -> { red, green, blue }
local function rgb_str2num(rgb_color_str)
  if rgb_color_str:find('#') == 1 then
    rgb_color_str = rgb_color_str:sub(2, #rgb_color_str)
  end
  local red = tonumber(rgb_color_str:sub(1, 2), 16)
  local green = tonumber(rgb_color_str:sub(3, 4), 16)
  local blue = tonumber(rgb_color_str:sub(5, 6), 16)
  return {red = red, green = green, blue = blue}
end

-- turns { red, green, blue } -> #rrggbb
local function rgb_num2str(rgb_color_num)
  local rgb_color_str = string.format('#%02x%02x%02x', rgb_color_num.red,
                                      rgb_color_num.green, rgb_color_num.blue)
  return rgb_color_str
end

-- returns brightness lavel of color in range 0 to 1
-- arbitary value it's basicaly an weighted average
local function get_color_brightness(rgb_color)
  local color = rgb_str2num(rgb_color)
  local brightness = (color.red * 2 + color.green * 3 + color.blue) / 6
  return brightness / 256
end

-- returns average of colors in range 0 to 1
-- used to ditermine contrast lavel
local function get_color_avg(rgb_color)
  local color = rgb_str2num(rgb_color)
  return (color.red + color.green + color.blue) / 3 / 256
end

-- clamps the val between left and right
local function clamp(val, left, right)
  if val > right then return right end
  if val < left then return left end
  return val
end

-- changes braghtness of rgb_color by percentage
local function brightness_modifier(rgb_color, parcentage)
  local color = rgb_str2num(rgb_color)
  color.red = clamp(color.red + (color.red * parcentage / 100), 0, 255)
  color.green = clamp(color.green + (color.green * parcentage / 100), 0, 255)
  color.blue = clamp(color.blue + (color.blue * parcentage / 100), 0, 255)
  return rgb_num2str(color)
end

-- changes contrast of rgb_color by amount
local function contrast_modifier(rgb_color, amount)
  local color = rgb_str2num(rgb_color)
  color.red = clamp(color.red + amount, 0, 255)
  color.green = clamp(color.green + amount, 0, 255)
  color.blue = clamp(color.blue + amount, 0, 255)
  return rgb_num2str(color)
end

-- Changes brightness of foreground color to achive contrast
-- without changing the color
local function apply_contrast(highlight)
  local hightlight_bg_avg = get_color_avg(highlight.bg)
  local contrast_threshold_config = clamp(contrast_threshold, 0, 0.5)
  local contranst_change_step = 5
  if hightlight_bg_avg > .5 then contranst_change_step = -contranst_change_step end

  -- donn't waste too much time here max 25 interation should be more than enough
  local iteration_count = 1
  while (math.abs(get_color_avg(highlight.fg) - hightlight_bg_avg) <
      contrast_threshold_config and iteration_count < 25) do
    highlight.fg = contrast_modifier(highlight.fg, contranst_change_step)
    iteration_count = iteration_count + 1
  end
end

-- Get the colors to create theme
local colors = {
  normal = getHi('bg', {'PmenuSel', 'PmenuThumb', 'TabLineSel'}),
  insert = getHi('fg', {'String', 'MoreMsg'}),
  replace = getHi('fg', {'Number', 'Type'}),
  visual = getHi('fg', {'Special', 'Boolean', 'Constant'}),
  command = getHi('fg', {'Identifier'}),
  back1 = getHi('bg', {'Normal', 'StatusLineNC'}),
  fore = getHi('fg', {'Normal', 'StatusLine'}),
  back2 = getHi('bg', {'StatusLine'})
}

-- Change brightness of colors
-- darken incase of light theme lighten incase of dark theme
local normal_color = utils.extract_highlight_colors('Normal', 'bg')
if normal_color ~= nil and get_color_brightness(normal_color) > 0.5 then
  brightness_modifier_parameter = -brightness_modifier_parameter
end

for name, color in pairs(colors) do
  colors[name] = brightness_modifier(color, brightness_modifier_parameter)
end

-- basic theme defination
local M = {
  normal = {
    a = {bg = colors.normal, fg = colors.back1, gui = 'bold'},
    b = {bg = colors.back1, fg = colors.normal},
    c = {bg = colors.back2, fg = colors.fore}
  },
  insert = {
    a = {bg = colors.insert, fg = colors.back1, gui = 'bold'},
    b = {bg = colors.back1, fg = colors.insert},
    c = {bg = colors.back2, fg = colors.fore}
  },
  replace = {
    a = {bg = colors.replace, fg = colors.back1, gui = 'bold'},
    b = {bg = colors.back1, fg = colors.replace},
    c = {bg = colors.back2, fg = colors.fore}
  },
  visual = {
    a = {bg = colors.visual, fg = colors.back1, gui = 'bold'},
    b = {bg = colors.back1, fg = colors.visual},
    c = {bg = colors.back2, fg = colors.fore}
  },
  command = {
    a = {bg = colors.command, fg = colors.back1, gui = 'bold'},
    b = {bg = colors.back1, fg = colors.command},
    c = {bg = colors.back2, fg = colors.fore}
  }
}

M.terminal = M.command
M.inactive = M.normal

-- Apply prpper contrast so text is readable
for _, section in pairs(M) do
  for _, highlight in pairs(section) do apply_contrast(highlight) end
end

return M
