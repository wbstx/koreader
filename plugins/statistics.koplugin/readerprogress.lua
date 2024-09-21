local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local Math = require("optmath")
local ProgressWidget = require("ui/widget/progresswidget")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local datetime = require("datetime")
local _ = require("gettext")
local Screen = Device.screen

local LINE_COLOR = Blitbuffer.COLOR_GRAY_9
local BG_COLOR = Blitbuffer.COLOR_LIGHT_GRAY
local WHITE_COLOR = Blitbuffer.COLOR_WHITE

local LineChartWidget = Widget:extend{
    width = nil,
    height = nil,
    line_color = LINE_COLOR,
    point_color = Blitbuffer.COLOR_GRAY_7,
    nb_items = nil,
    ratios = nil, -- table of 1...nb_items items, each with (0 <= value <= 1), denoting the point value
    x_axis = nil, -- values of x axis, nb_items items
    y_value = nil, -- the value of y axis
    bottom_v_padding = 0,
    face = Font:getFace("smallffont"),
    -- params for rectangles
    show_rectange = false,
    shrink = 0.6 -- shrink the width of the rectangles 
}

function LineChartWidget:init()
    self.dimen = Geom:new{w = self.width, h = self.height}

    self.line_thickness = self.height * 0.002
    self.bottom_v_padding = self.height * 0.02
    self.left_padding = self.width * 0.01
    self.read_text_padding = 0.0

    self.width = self.width - self.left_padding

    local item_width = math.floor(self.width / self.nb_items)
    local nb_item_width_add1 = self.width - self.nb_items * item_width
    local nb_item_width_add1_mod = math.floor(self.nb_items/nb_item_width_add1)
    self.item_widths = {}

    for n = 1, self.nb_items do
        local w = item_width
        if nb_item_width_add1 > 0 and n % nb_item_width_add1_mod == 0 then
            w = w + 1
            nb_item_width_add1 = nb_item_width_add1 - 1
        end
        table.insert(self.item_widths, w)
    end
    if BD.mirroredUILayout() then
        self.do_mirror = true
    end
end

function LineChartWidget:paintTo(bb, x, y)
    local i_x = 0
    local x_axis_start = 0
    local x_axis_end = 0    
    -- a list to save all painted 2D coordinates
    local points = {}
    -- a list to save the state of each point
    local states = {}

    local read_text_placeholder = TextWidget:new{
        text = "1234567890 mins",
        face = Font:getFace("smallffont", 10)
    }

    for n = 1, self.nb_items do
        local ratio = self.ratios and self.ratios[n] or 0
        local i_h = Math.round(ratio * (self.height - self.bottom_v_padding * 3.0))
        if i_h == 0 and ratio > 0 then -- show at least 1px
            i_h = 1
        end
        local i_y = (self.height - self.bottom_v_padding * 3.0) - i_h
        if i_h < read_text_placeholder:getSize().h / 2.0 then
            self.read_text_padding = -read_text_placeholder:getSize().h / 2.0
        end
    end

    for n = 1, self.nb_items do
        if self.do_mirror then
            n = self.nb_items - n + 1
        end
        local i_w = self.item_widths[n]
        local ratio = self.ratios and self.ratios[n] or 0
        local i_h = Math.round(ratio * (self.height - self.bottom_v_padding * 3.0))
        if i_h == 0 and ratio > 0 then -- show at least 1px
            i_h = 1
        end
        local i_y = (self.height - self.bottom_v_padding * 3.0) - i_h

        local bottom_height = self.height - self.bottom_v_padding

        if self.show_rectange then
            if i_h > 0 then
                bb:paintBorder(x + i_x + i_w * (1.0 - self.shrink) / 2.0 + self.left_padding, y + i_y, i_w * self.shrink + self.read_text_padding, i_h, self.line_thickness, LINE_COLOR)
            end
        end

        local text = TextWidget:new{
            text = self.x_axis[n],
            face = self.face,
            max_width = i_w
        }
        text:paintTo(bb, x + i_x + (i_w - text:getSize().w)/ 2.0 + self.left_padding, y + bottom_height)
        bb:paintRect(x + i_x + i_w / 2.0 + self.left_padding, y + bottom_height - self.bottom_v_padding - self.line_thickness * 2.5, self.line_thickness, self.line_thickness * 5, LINE_COLOR) -- x axis ticks
    
        if n == 1 then
            x_axis_start = x + i_x + i_w / 2.0 + self.left_padding
        end
        if n == self.nb_items then
            x_axis_end = x + i_x + i_w / 2.0 + self.left_padding
        end

        if n == 1 then
            if self.ratios[n] <= self.ratios[n+1] then
                table.insert(states, "trough")
            else
                table.insert(states, "peak")
            end
        elseif n == #self.ratios then
            if self.ratios[n] <= self.ratios[n-1] then
                table.insert(states, "trough")
            else
                table.insert(states, "peak")
            end
        elseif self.ratios[n] <= self.ratios[n-1] and self.ratios[n] <= self.ratios[n+1] then
            table.insert(states, "trough")
        elseif self.ratios[n] >= self.ratios[n-1] and self.ratios[n] >= self.ratios[n+1] then
            table.insert(states, "peak")
        elseif self.ratios[n] >= self.ratios[n-1] and self.ratios[n] <= self.ratios[n+1] then
            table.insert(states, "uphill")
        elseif self.ratios[n] <= self.ratios[n-1] and self.ratios[n] >= self.ratios[n+1] then
            table.insert(states, "downhill")
        end

        -- bb:paintCircleWidth(x + i_x + i_w / 2.0 + self.left_padding, y + i_y, 5.0, Blitbuffer.COLOR_BLACK, 5.0)
        table.insert(points, {x + i_x + i_w / 2.0 + self.left_padding, y + i_y + self.read_text_padding})
        
        i_x = i_x + i_w
    end

    bb:paintRect(x_axis_start, y + self.height - 2 * self.bottom_v_padding, x_axis_end - x_axis_start + self.line_thickness, self.line_thickness, LINE_COLOR) -- x axis
    -- bb:paintRect(x_axis_start, y, self.line_thickness, self.height - 2 * self.bottom_v_padding, LINE_COLOR) -- y axis

    for i = x_axis_start, x_axis_end, 20 do
        bb:paintRect(i, y + self.height / 2, 14, self.line_thickness, Blitbuffer.COLOR_DARK_GRAY)
    end

    -- insert the start point and end point to the list
    table.insert(points, 1, {x, points[1][2]})
    table.insert(points, {x + self.width, points[#points][2]})

    -- calculate the control points for the cubic bezier curve, so that the curve is smooth. keep the target always on the peak/trough of the curve
    local interpolation_interval = 6
    local control_points_interval = {}
    for i = 2, #points-2 do
        local p1_x, p1_y = points[i][1], points[i][2]
        local prev_level_off = (states[i-1] == "trough" or states[i-1] == "peak") and 1 or 0
        local level_off = (states[i] == "trough" or states[i] == "peak") and 1 or 0
        local p2_x, p2_y = points[i][1] + (points[i+1][1] - points[i-1][1]) / interpolation_interval, 
                           math.min(points[i][2] + (points[i+1][2] - points[i-1][2]) / interpolation_interval * (1 - prev_level_off), y + self.height - 2 * self.bottom_v_padding)
        local p3_x, p3_y = points[i+1][1] - (points[i+2][1] - points[i][1]) / interpolation_interval, 
                           math.min(points[i+1][2] - (points[i+2][2] - points[i][2]) / interpolation_interval * (1 - level_off), y + self.height- 2 * self.bottom_v_padding)
        local p4_x, p4_y = points[i+1][1], points[i+1][2]

        -- Debug, visualize the control points
        bb:paintCircleWidth(p2_x, p2_y, 4.0, Blitbuffer.COLOR_GRAY_7, 4.0)
        bb:paintCircleWidth(p3_x, p3_y, 4.0, Blitbuffer.COLOR_GRAY_7, 4.0)
        -- bb:paintLineWidth(p2_x, p2_y, p3_x, p3_y, Blitbuffer.COLOR_GRAY_7, 2)

        table.insert(control_points_interval, {p2_x, p2_y})
        table.insert(control_points_interval, {p3_x, p3_y})

        bb:paintCubicBezierWidth(p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x - 1, p4_y - 1, Blitbuffer.COLOR_GRAY_7, 2)

    end

    -- delete the end point from the list
    table.remove(points, 1)
    table.remove(points, #points)

    for i = 1, #points do
        bb:paintCircleWidth(points[i][1], points[i][2], 5.0, Blitbuffer.COLOR_BLACK, 5.0)
        
        -- local scatter_point = IconWidget:new{
        --     icon = "star.full",
        --     width = 16,
        --     height = 16,
        --     alpha = true
        -- }
        -- scatter_point:paintTo(bb, points[i][1] - 8, points[i][2] - 8)

        local read_time_text = TextWidget:new{
            text = string.format("%02d mins", self.y_value[i]/60),
            face = Font:getFace("smallffont", 10)
        }

        local offset_x, offset_y = 0, 0
        if states[i] == "downhill" then
            offset_x = read_time_text:getSize().w / 2.0 + 15
        elseif states[i] == "uphill" then
            offset_x = -read_time_text:getSize().w / 2.0 - 15
        elseif states[i] == "peak" then
            offset_y = -read_time_text:getSize().h / 2.0 - 10
        elseif states[i] == "trough" then
            offset_y = read_time_text:getSize().h / 2.0 + 10
        end

        -- bb:paintRect(points[i][1] - read_time_text:getSize().w / 2.0 + offset_x + self.left_padding, points[i][2] - read_time_text:getSize().h / 2.0 + offset_y, read_time_text:getSize().w, read_time_text:getSize().h, LINE_COLOR)
        read_time_text:paintTo(bb, points[i][1] - read_time_text:getSize().w / 2.0 + offset_x, points[i][2] - read_time_text:getSize().h / 2.0 + offset_y)

    end

    for i = 1, #points-2 do
        bb:paintLineWidth(control_points_interval[2 * i][1], control_points_interval[2 * i][2], control_points_interval[2 * i + 1][1], control_points_interval[2 * i + 1][2], Blitbuffer.COLOR_GRAY_7, 2)
    end

end

-- Oh, hey, this one actually *is* an InputContainer!
local ReaderProgress = InputContainer:extend{
    padding = Size.padding.fullscreen,
}

function ReaderProgress:init()
    self.current_pages = tostring(self.current_pages)
    self.today_pages = tostring(self.today_pages)
    self.small_font_face = Font:getFace("smallffont")
    self.medium_font_face = Font:getFace("ffont")
    self.large_font_face = Font:getFace("largeffont")

    local small_font_face_setting = G_reader_settings:readSetting("reading_progress_font", "Default")
    if small_font_face_setting ~= "Default" then
        local cre = require("document/credocument"):engineInit()
        local font_filename, font_faceindex, is_monospace = cre.getFontFaceFilenameAndFaceIndex(small_font_face_setting)
        self.small_font_face = Font:getFace(font_filename, 15)
        self.medium_font_face = Font:getFace(font_filename, 20)
        self.large_font_face = Font:getFace(font_filename, 25)
    end

    self.screen_width = Screen:getWidth()
    self.screen_height = Screen:getHeight()
    if self.screen_width < self.screen_height then
        self.header_span = 25
        self.stats_span = 20
    else
        self.header_span = 0
        self.stats_span = 10
    end

    self.covers_fullscreen = true -- hint for UIManager:_repaint()
    self[1] = FrameContainer:new{
        width = self.screen_width,
        height = self.screen_height,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        self:getStatusContent(self.screen_width),
    }
    -- We're full-screen, and the widget is built in a funky way, ensure dimen actually matches the full-screen,
    -- instead of only the content's effective area...
    self.dimen = Geom:new{ x = 0, y = 0, w = self.screen_width, h = self.screen_height }

    if Device:hasKeys() then
        -- don't get locked in on non touch devices
        self.key_events.AnyKeyPressed = { { Device.input.group.Any } }
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = function() return self.dimen end,
            }
        }
        self.ges_events.MultiSwipe = {
            GestureRange:new{
                ges = "multiswipe",
                range = function() return self.dimen end,
            }
        }
    end

    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function ReaderProgress:getTotalStats(stats_day)
    local total_time = 0
    local total_pages = 0
    for i=1, stats_day do
        total_pages = total_pages + self.dates[i][1]
        total_time = total_time + self.dates[i][2]
    end
    return total_time, total_pages
end

function ReaderProgress:getStatusContent(width)
    local title_bar = TitleBar:new{
        width = width,
        bottom_v_padding = 0,
        close_callback = not self.readonly and function() self:onClose() end,
        show_parent = self,
    }
    return VerticalGroup:new{
        align = "left",
        title_bar,
        self:genSingleHeader(_("Last week")),
        self:genSummaryWeek(width),
        self:genSingleHeader(_("Week progress")),
        self:genWeekStats(7),
        self:genDoubleHeader(_("Session"), _("Today") ),
        self:genSummaryDay(width),
    }
end

function ReaderProgress:genSingleHeader(title)
    local header_title = TextWidget:new{
        text = title,
        face = self.medium_font_face,
        fgcolor = LINE_COLOR,
    }
    local padding_span = HorizontalSpan:new{ width = self.padding }
    local line_width = (self.screen_width - header_title:getSize().w) / 2 - self.padding * 2
    local line_container = LeftContainer:new{
        dimen = Geom:new{ w = line_width, h = self.screen_height * (1/25) },
        LineWidget:new{
            background = BG_COLOR,
            dimen = Geom:new{
                w = line_width,
                h = Size.line.thick,
            }
        }
    }

    return VerticalGroup:new{
        VerticalSpan:new{ width = Screen:scaleBySize(self.header_span), height = self.screen_height * (1/25) },
        HorizontalGroup:new{
            align = "center",
            padding_span,
            line_container,
            padding_span,
            header_title,
            padding_span,
            line_container,
            padding_span,
        },
        VerticalSpan:new{ width = Size.span.vertical_large, height = self.screen_height * (1/25) },
    }
end

function ReaderProgress:genDoubleHeader(title_left, title_right)
    local header_title_left = TextWidget:new{
        text = title_left,
        face = self.medium_font_face,
        fgcolor = LINE_COLOR,
    }
    local header_title_right = TextWidget:new{
        text = title_right,
        face = self.medium_font_face,
        fgcolor = LINE_COLOR,
    }
    local padding_span = HorizontalSpan:new{ width = self.padding }
    local line_width = (self.screen_width - header_title_left:getSize().w - header_title_right:getSize().w - self.padding * 7) / 4
    local line_container = LeftContainer:new{
        dimen = Geom:new{ w = line_width, h = self.screen_height * (1/25) },
        LineWidget:new{
            background = BG_COLOR,
            dimen = Geom:new{
                w = line_width,
                h = Size.line.thick,
            }
        }
    }

    return VerticalGroup:new{
        VerticalSpan:new{ width = Screen:scaleBySize(25), height = self.screen_height * (1/25) },
        HorizontalGroup:new{
            align = "center",
            padding_span,
            line_container,
            padding_span,
            header_title_left,
            padding_span,
            line_container,
            padding_span,
            line_container,
            padding_span,
            header_title_right,
            padding_span,
            line_container,
            padding_span,
        },
        VerticalSpan:new{ width = Size.span.vertical_large, height = self.screen_height * (1/25) },
    }
end

function ReaderProgress:genWeekStats(stats_day)
    local second_in_day = 86400
    local date_format_show
    local select_day_time
    local diff_time
    local now_time = os.time()
    local user_duration_format = G_reader_settings:readSetting("duration_format")
    local height = Screen:scaleBySize(60)
    local statistics_container = CenterContainer:new{
        dimen = Geom:new{ w = self.screen_width , h = height },
    }
    local statistics_group = VerticalGroup:new{ align = "left" }
    local max_week_time = -1
    local day_time
    for i=1, stats_day do
        self.dates[i][2] = math.random(0, 7200)
        day_time = self.dates[i][2]
        if day_time > max_week_time then max_week_time = day_time end
    end
    local top_padding_span = HorizontalSpan:new{ width = Screen:scaleBySize(15) }
    local top_span_group = HorizontalGroup:new{
        align = "center",
        LeftContainer:new{
            dimen = Geom:new{ h = Screen:scaleBySize(30) },
            top_padding_span
        },
    }
    table.insert(statistics_group, top_span_group)

    local padding_span = HorizontalSpan:new{ width = Screen:scaleBySize(15) }
    local span_group = HorizontalGroup:new{
        align = "center",
        LeftContainer:new{
            dimen = Geom:new{ h = Screen:scaleBySize(self.stats_span) },
            padding_span
        },
    }

    local line_chart_height = {}
    local day_readtime = {}
    local stat_date = {}

    -- Lines have L/R self.padding. Make this section even more indented/padded inside the lines
    local inner_width = self.screen_width - 4*self.padding
    local j = 1
    for i = 1, stats_day do
        diff_time = now_time - second_in_day * (i - 1)
        if self.dates[j][3] == os.date("%Y-%m-%d", diff_time) then
            select_day_time = self.dates[j][2]
            j = j + 1
        else
            select_day_time = 0
        end
        date_format_show = datetime.shortDayOfWeekToLongTranslation[os.date("%a", diff_time)] .. os.date(" (%Y-%m-%d)", diff_time)
        local total_group = HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = inner_width , h = height * (1/3) },
                TextWidget:new{
                    padding = Size.padding.small,
                    text = date_format_show .. " — " .. datetime.secondsToClockDuration(user_duration_format, select_day_time, true, true),
                    face = self.small_font_face,
                },
            },
        }
        local titles_group = HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = inner_width , h = height * (1/3) },
                ProgressWidget:new{
                    width = math.floor(inner_width * select_day_time / max_week_time),
                    height = Screen:scaleBySize(14),
                    percentage = 1.0,
                    ticks = nil,
                    last = nil,
                    margin_h = 0,
                    margin_v = 0,
                }
            },
        }

        table.insert(line_chart_height, select_day_time / max_week_time * 0.9)
        table.insert(day_readtime, select_day_time)
        table.insert(stat_date,  string.sub(datetime.shortDayOfWeekToLongTranslation[os.date("%a", diff_time)], 1, 3) .. os.date(" %m-%d", diff_time))

        table.insert(statistics_group, total_group)
        table.insert(statistics_group, titles_group)
        table.insert(statistics_group, span_group)
    end  --for i=1
    table.insert(statistics_container, statistics_group)

    return LineChartWidget:new{
        width = self.screen_width,
        height = math.floor(self.screen_height * 0.5),
        nb_items = 7,
        ratios = line_chart_height,
        x_axis = stat_date,
        y_value = day_readtime,
        face = self.small_font_face
    }

    -- return CenterContainer:new{
    --     dimen = Geom:new{ w = self.screen_width, h = math.floor(self.screen_height * 0.5) },
    --     statistics_container,
    -- }
end

function ReaderProgress:genSummaryDay(width)
    local height = Screen:scaleBySize(60)
    local statistics_container = CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
    }
    local statistics_group = VerticalGroup:new{ align = "left" }
    local tile_width = width * (1/4)
    local tile_height = height * (1/3)
    local user_duration_format = G_reader_settings:readSetting("duration_format")

    local titles_group = HorizontalGroup:new{
        align = "center",
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = _("Pages"),
                face = self.small_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = _("Time"),
                face = self.small_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = _("Pages"),
                face = self.small_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = _("Time"),
                face = self.small_font_face,
            },
        },
    }

    local padding_span = HorizontalSpan:new{ width = Screen:scaleBySize(15) }
    local span_group = HorizontalGroup:new{
        align = "center",
        LeftContainer:new{
            dimen = Geom:new{ h = Size.span.horizontal_default },
            padding_span
        },
    }

    local data_group = HorizontalGroup:new{
        align = "center",
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = self.current_pages,
                face = self.medium_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = datetime.secondsToClockDuration(user_duration_format, self.current_duration, true),
                face = self.medium_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = self.today_pages,
                face = self.medium_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = datetime.secondsToClockDuration(user_duration_format, self.today_duration, true),
                face = self.medium_font_face,
            },
        },
    }
    table.insert(statistics_group, titles_group)
    table.insert(statistics_group, span_group)
    table.insert(statistics_group, data_group)
    table.insert(statistics_group, span_group)
    table.insert(statistics_group, span_group)
    table.insert(statistics_container, statistics_group)
    return CenterContainer:new{
        dimen = Geom:new{ w = self.screen_width , h = math.floor(self.screen_height * 0.13) },
        statistics_container,
    }
end

function ReaderProgress:genSummaryWeek(width)
    local height = Screen:scaleBySize(60)
    local total_time, total_pages = self:getTotalStats(#self.dates)
    local statistics_container = CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
    }
    local statistics_group = VerticalGroup:new{ align = "left" }
    local tile_width = width * (1/4)
    local tile_height = height * (1/3)
    local user_duration_format = G_reader_settings:readSetting("duration_format")
    local total_group = HorizontalGroup:new{
        align = "center",
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextBoxWidget:new{
                alignment = "center",
                text = _("Total\npages"),
                face = self.small_font_face,
                width = tile_width * 0.95,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextBoxWidget:new{
                alignment = "center",
                text = _("Total\ntime"),
                face = self.small_font_face,
                width = tile_width * 0.95,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextBoxWidget:new{
                alignment = "center",
                text = _("Average\npages/day"),
                face = self.small_font_face,
                width = tile_width * 0.95,
            }
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextBoxWidget:new{
                alignment = "center",
                text = _("Average\ntime/day"),
                face = self.small_font_face,
                width = tile_width * 0.95,
            }
        }
    }

    local padding_span = HorizontalSpan:new{ width = Screen:scaleBySize(15) }
    local span_group = HorizontalGroup:new{
        align = "center",
        LeftContainer:new{
            dimen = Geom:new{ h = Size.span.horizontal_default },
            padding_span
        },
    }

    local data_group = HorizontalGroup:new{
        align = "center",
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = tostring(total_pages),
                face = self.medium_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = datetime.secondsToClockDuration(user_duration_format, math.floor(total_time), true),
                face = self.medium_font_face,
            },
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = tostring(math.floor(total_pages * (1/7))),
                face = self.medium_font_face,
            }
        },
        CenterContainer:new{
            dimen = Geom:new{ w = tile_width, h = tile_height },
            TextWidget:new{
                text = datetime.secondsToClockDuration(user_duration_format, math.floor(total_time) * (1/7), true),
                face = self.medium_font_face,
            }
        }
    }
    table.insert(statistics_group, total_group)
    table.insert(statistics_group, span_group)
    table.insert(statistics_group, data_group)
    table.insert(statistics_container, statistics_group)
    return CenterContainer:new{
        dimen = Geom:new{ w = self.screen_width , h = math.floor(self.screen_height * 0.10) },
        statistics_container,
    }
end

function ReaderProgress:onSwipe(arg, ges_ev)
    if ges_ev.direction == "south" then
        -- Allow easier closing with swipe up/down
        self:onClose()
    elseif ges_ev.direction == "east" or ges_ev.direction == "west" or ges_ev.direction == "north" then
        -- no use for now
        do end -- luacheck: ignore 541
    else -- diagonal swipe
        -- trigger full refresh
        UIManager:setDirty(nil, "full")
        -- a long diagonal swipe may also be used for taking a screenshot,
        -- so let it propagate
        return false
    end
end

function ReaderProgress:onClose()
    UIManager:close(self)
    return true
end
ReaderProgress.onAnyKeyPressed = ReaderProgress.onClose
-- For consistency with other fullscreen widgets where swipe south can't be
-- used to close and where we then allow any multiswipe to close, allow any
-- multiswipe to close this widget too.
ReaderProgress.onMultiSwipe = ReaderProgress.onClose


return ReaderProgress
