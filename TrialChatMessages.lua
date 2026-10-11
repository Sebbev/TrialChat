-- The message list of the TrialChat window: each message under its
-- sender's avatar and name, several in a row from the same person grouped
-- under one, day and "new" dividers, and emotes in the middle. It's a
-- scroll box, so only the rows on screen exist however long the history is.
TrialChatMessageList = {}
local UI = TrialChatUI
local Color = UI.Color

local SIDE_PADDING = 20
local RIGHT_PADDING = 10
local AVATAR_SIZE = 32
local TEXT_LEFT = SIDE_PADDING + AVATAR_SIZE + 12
local HEADER_TOP = 12
local NAME_HEIGHT = 18
local CONTINUATION_TOP = 2
local TEXT_BOTTOM = 2
local CENTERED_PADDING = 7
local DIVIDER_HEIGHT = 34
local MIN_TEXT_HEIGHT = 14
-- Messages from the same person this close together share one header.
local GROUP_SECONDS = 5 * 60
local RELAYOUT_DELAY = 0.15
local SCROLL_STEP = 40
local DEFAULT_WIDTH = 520

local List = {}
List.__index = List

local function dayLabel(timestamp)
    local now = GetServerTime()
    local day = date("%Y-%m-%d", timestamp)
    if day == date("%Y-%m-%d", now) then return "Today" end
    if day == date("%Y-%m-%d", now - 86400) then return "Yesterday" end
    if now - timestamp < 6 * 86400 then return date("%A", timestamp) end
    return date("%B ", timestamp) .. tonumber(date("%d", timestamp))
        .. date(", %Y", timestamp)
end

local function onHyperlinkClick(_, link, text, button)
    TrialChatCommon.HandleHyperlinkClick(link, text, button)
end

local function onHyperlinkEnter(self, link, text)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
    if string.sub(link or "", 1, 6) == "tcurl:" then
        GameTooltip:SetText("Click to copy URL")
    elseif string.sub(link or "", 1, 7) == "player:"
        or string.sub(link or "", 1, 9) == "tcplayer:" then
        GameTooltip:SetText("Click for player options: " .. (text or "player"))
    else
        GameTooltip:SetHyperlink(link)
    end
    GameTooltip:Show()
end

-- Rows without a header show their time in the avatar column on hover.
local function onRowEnter(row)
    if row.showsTimeOnHover then
        row.hoverTime:Show()
    end
end

local function onRowLeave(row)
    row.hoverTime:Hide()
end

local function onAvatarEnter(avatar)
    if not avatar.fullName then return end
    GameTooltip:SetOwner(avatar, "ANCHOR_RIGHT")
    GameTooltip:SetText(avatar.fullName)
    if not TrialChatCommon.IsSelf(avatar.fullName) then
        GameTooltip:AddLine("Right-click for player options.", 1, 1, 1)
    end
    GameTooltip:Show()
end

local function onAvatarClick(avatar)
    if avatar.fullName and not TrialChatCommon.IsSelf(avatar.fullName) then
        TrialChatCommon.ShowPlayerOptions(avatar.fullName, avatar.fullName, "RightButton")
    end
end

local function createRowParts(row)
    row:EnableMouse(true)
    row:SetHyperlinksEnabled(true)
    row:SetScript("OnHyperlinkClick", onHyperlinkClick)
    row:SetScript("OnHyperlinkEnter", onHyperlinkEnter)
    row:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
    row:SetScript("OnEnter", onRowEnter)
    row:SetScript("OnLeave", onRowLeave)

    row.avatar = UI.CreateAvatar(row, AVATAR_SIZE)
    row.avatar:SetPoint("TOPLEFT", row, "TOPLEFT", SIDE_PADDING, -HEADER_TOP)
    row.avatar:RegisterForClicks("RightButtonUp")
    row.avatar:SetScript("OnClick", onAvatarClick)
    row.avatar:SetScript("OnEnter", onAvatarEnter)
    row.avatar:SetScript("OnLeave", GameTooltip_Hide)

    row.name = UI.CreateText(row, UI.Font.name)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_LEFT, -HEADER_TOP - 1)
    row.time = UI.CreateText(row, UI.Font.time, Color.muted)
    row.time:SetPoint("BOTTOMLEFT", row.name, "BOTTOMRIGHT", 8, 0)
    row.hoverTime = UI.CreateText(row, UI.Font.time, Color.muted)
    row.hoverTime:SetPoint("TOPRIGHT", row, "TOPLEFT", TEXT_LEFT - 8, -CONTINUATION_TOP - 2)

    row.text = UI.CreateText(row, UI.Font.body)
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    row.text:SetNonSpaceWrap(true)

    row.label = UI.CreateText(row, UI.Font.small)
    row.label:SetPoint("CENTER", row, "CENTER", 0, 0)
    row.lineLeft = UI.CreateLine(row)
    row.lineLeft:SetHeight(1)
    row.lineLeft:SetPoint("LEFT", row, "LEFT", SIDE_PADDING, 0)
    row.lineLeft:SetPoint("RIGHT", row.label, "LEFT", -10, 0)
    row.lineRight = UI.CreateLine(row)
    row.lineRight:SetHeight(1)
    row.lineRight:SetPoint("LEFT", row.label, "RIGHT", 10, 0)
    row.lineRight:SetPoint("RIGHT", row, "RIGHT", -RIGHT_PADDING, 0)
end

local function hideRowParts(row)
    row.avatar:Hide()
    row.name:Hide()
    row.time:Hide()
    row.hoverTime:Hide()
    row.text:Hide()
    row.label:Hide()
    row.lineLeft:Hide()
    row.lineRight:Hide()
    row.showsTimeOnHover = false
end

-- Both corners of the text are anchored at its top, so only its width is
-- fixed and it grows down as it wraps. (A RIGHT anchor would also pin its
-- middle, which limits its height and cuts it off with "...".)
local function placeText(row, left, top)
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", left, top)
    row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -RIGHT_PADDING, top)
end

local function initializeRow(row, element)
    if not row.text then
        createRowParts(row)
    end
    hideRowParts(row)
    local kind = element.kind

    if kind == "day" or kind == "new" then
        local color = kind == "new" and Color.accent or Color.muted
        row.label:SetText(element.text)
        UI.SetTextColor(row.label, color)
        UI.Tint(row.lineLeft, kind == "new" and Color.accent or Color.divider)
        UI.Tint(row.lineRight, kind == "new" and Color.accent or Color.divider)
        row.label:Show()
        row.lineLeft:Show()
        row.lineRight:Show()
        return
    end

    local text = row.text
    text:ClearAllPoints()
    text:SetText(element.text)
    text:Show()
    if kind == "message" then
        text:SetJustifyH("LEFT")
        UI.SetTextColor(text, Color.text)
        if element.header then
            row.avatar.fullName = element.sender
            row.avatar:SetPerson(element.name, element.color)
            row.avatar:Show()
            row.name:SetText(element.name)
            UI.SetTextColor(row.name, element.color)
            row.name:Show()
            row.time:SetText(element.time)
            row.time:Show()
            placeText(row, TEXT_LEFT, -HEADER_TOP - NAME_HEIGHT)
        else
            placeText(row, TEXT_LEFT, -CONTINUATION_TOP)
            row.hoverTime:SetText(element.time)
            row.showsTimeOnHover = true
        end
        return
    end

    if kind == "line" then
        text:SetJustifyH("LEFT")
        UI.SetTextColor(text, Color.text)
        placeText(row, SIDE_PADDING, -TEXT_BOTTOM)
    else
        text:SetJustifyH("CENTER")
        UI.SetTextColor(text, element.color or Color.emote)
        placeText(row, SIDE_PADDING, -CENTERED_PADDING)
        if element.time then
            row.hoverTime:SetText(element.time)
            row.showsTimeOnHover = true
        end
    end
end

function TrialChatMessageList.Create(parent)
    local list = setmetatable({
        rowsByEntry = setmetatable({}, { __mode = "k" }),
    }, List)
    local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 2, -4)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 2, 4)
    list.scrollBox = scrollBox
    list.scrollBar = scrollBar

    list.measure = scrollBox:CreateFontString(nil, "ARTWORK")
    list.measure:SetFontObject(UI.Font.body)
    list.measure:SetPoint("TOPLEFT", scrollBox, "TOPLEFT")
    list.measure:SetWordWrap(true)
    list.measure:SetNonSpaceWrap(true)
    list.measure:Hide()

    local view = CreateScrollBoxListLinearView(4, 14, 0, 0, 0)
    view:SetElementFactory(function(factory)
        factory("Frame", initializeRow)
    end)
    view:SetElementExtentCalculator(function(_, element)
        return list:Measure(element)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar)
    scrollBox:SetPanExtent(SCROLL_STEP)

    list.newMessagesButton = UI.CreateButton(parent, {
        style = "accent", icon = "arrowDown", iconSize = 14, text = "New messages",
        height = 26, radius = 13, font = UI.Font.small,
        onClick = function() list:ScrollToBottom() end,
    })
    list.newMessagesButton:SetPoint("BOTTOM", scrollBox, "BOTTOM", 0, 10)
    list.newMessagesButton:SetFrameLevel(scrollBox:GetFrameLevel() + 100)
    list.newMessagesButton:Hide()

    list.emptyText = UI.CreateText(parent, UI.Font.body, Color.muted)
    list.emptyText:SetPoint("LEFT", scrollBox, "LEFT", SIDE_PADDING * 2, 0)
    list.emptyText:SetPoint("RIGHT", scrollBox, "RIGHT", -SIDE_PADDING * 2, 0)
    list.emptyText:SetJustifyH("CENTER")
    list.emptyText:Hide()

    scrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
        if list.newMessagesButton:IsShown() and list:IsAtBottom() then
            list.newMessagesButton:Hide()
        end
    end, list)
    scrollBox:RegisterCallback(BaseScrollBoxEvents.OnSizeChanged, function(_, width)
        list:OnWidthChanged(width)
    end, list)

    list:SetEntries({}, {})
    return list
end

function List:GetWidth()
    local width = self.width or self.scrollBox:GetWidth()
    if not width or width <= 0 then
        return DEFAULT_WIDTH
    end
    return width
end

function List:MeasureText(text, width)
    local measure = self.measure
    measure:SetWidth(math.max(1, width))
    measure:SetText(text)
    return math.max(MIN_TEXT_HEIGHT, measure:GetStringHeight() or 0)
end

-- Row heights depend on how the text wraps, so they're measured for the
-- current width and kept until the width changes.
function List:Measure(element)
    local width = self:GetWidth()
    if element.height and element.measuredWidth == width then
        return element.height
    end

    local height
    local kind = element.kind
    if kind == "day" or kind == "new" then
        height = DIVIDER_HEIGHT
    elseif kind == "message" then
        local textHeight = self:MeasureText(element.text,
            width - TEXT_LEFT - RIGHT_PADDING)
        if element.header then
            height = math.max(HEADER_TOP + NAME_HEIGHT + textHeight,
                HEADER_TOP + AVATAR_SIZE) + TEXT_BOTTOM
        else
            height = CONTINUATION_TOP + textHeight + TEXT_BOTTOM
        end
    elseif kind == "line" then
        height = self:MeasureText(element.text,
            width - SIDE_PADDING - RIGHT_PADDING) + TEXT_BOTTOM * 2
    else
        height = self:MeasureText(element.text,
            width - SIDE_PADDING - RIGHT_PADDING) + CENTERED_PADDING * 2
    end
    element.height = math.ceil(height)
    element.measuredWidth = width
    return element.height
end

function List:GetDistanceFromBottom()
    local scrollBox = self.scrollBox
    return scrollBox:GetDerivedScrollRange() - scrollBox:GetDerivedScrollOffset()
end

function List:IsAtBottom()
    return self:GetDistanceFromBottom() <= 2
end

function List:ScrollToBottom()
    self.scrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation)
    self.newMessagesButton:Hide()
end

function List:SetDistanceFromBottom(distance)
    local scrollBox = self.scrollBox
    local range = scrollBox:GetDerivedScrollRange()
    if range > 0 then
        scrollBox:SetScrollPercentage(math.max(0, range - distance) / range,
            ScrollBoxConstants.NoScrollInterpolation)
    end
end

-- Lays the rows out again (after a resize) without moving what's in view.
function List:Relayout()
    if not self.dataProvider then return end
    local atBottom = self:IsAtBottom()
    local fromBottom = self:GetDistanceFromBottom()
    self.scrollBox:Rebuild(ScrollBoxConstants.RetainScrollPosition)
    if atBottom then
        self:ScrollToBottom()
    else
        self:SetDistanceFromBottom(fromBottom)
    end
end

function List:OnWidthChanged(width)
    if not width or width <= 0 or width == self.width then return end
    if not self.width then
        self.width = width
        self:Relayout()
        return
    end

    self.pendingWidth = width
    if self.relayoutPending then return end
    self.relayoutPending = true
    C_Timer.After(RELAYOUT_DELAY, function()
        self.relayoutPending = false
        if self.pendingWidth and self.pendingWidth ~= self.width then
            self.width = self.pendingWidth
            self:Relayout()
        end
    end)
end

-- Turns history entries into rows. entries are tables of { sender, message,
-- isEmote, timestamp } or, from older versions, ready-made chat lines.
function List:AddEntry(elements, entry)
    local state = self.state
    local function addNewDivider()
        if state.newDivider then
            elements[#elements + 1] = state.newDivider
            state.newDivider = nil
            state.last = nil
        end
    end

    if type(entry) ~= "table" then
        if type(entry) == "string" then
            addNewDivider()
            elements[#elements + 1] = {
                kind = "line", text = TrialChatCommon.RemovePlayerLinks(entry),
            }
        end
        state.last = nil
        return
    end

    local timestamp = tonumber(entry.timestamp) or 0
    local day = date("%Y-%m-%d", timestamp)
    if day ~= state.day then
        state.day = day
        state.last = nil
        elements[#elements + 1] = { kind = "day", text = dayLabel(timestamp) }
    end
    addNewDivider()

    -- Rows are kept per entry, so drawing the list again (while history
    -- loads) doesn't format and measure every message again.
    local cached = self.rowsByEntry[entry]
    local sender = entry.sender or "?"
    local name = TrialChatCommon.ShortName(sender)
    if entry.isEmote then
        if not cached then
            cached = {
                kind = "emote",
                text = name .. " " .. state.format(entry),
                time = date("%H:%M", timestamp),
            }
            self.rowsByEntry[entry] = cached
        end
        elements[#elements + 1] = cached
        state.last = nil
        return
    end

    local last = state.last
    local header = not (last and TrialChatCommon.NamesMatch(last.sender, sender)
        and timestamp - (tonumber(last.timestamp) or 0) <= GROUP_SECONDS)
    local color = state.colorFor(entry)
    if not cached or cached.header ~= header or cached.color ~= color then
        cached = {
            kind = "message",
            header = header,
            sender = sender,
            name = name,
            color = color,
            time = date("%H:%M", timestamp),
            text = cached and cached.text or state.format(entry),
        }
        self.rowsByEntry[entry] = cached
    end
    elements[#elements + 1] = cached
    state.last = entry
end

-- options: format(entry) gives the message text, colorFor(entry) the name
-- color, firstUnread is the entry to put the "new" divider before, with
-- unreadCount, keepPosition stays where the reader is, and emptyText is
-- shown while there are no messages.
function List:SetEntries(entries, options)
    self.state = {
        format = options.format or function(entry) return entry.message end,
        colorFor = options.colorFor or function() return Color.textSoft end,
    }
    self.emptyText:SetText(options.emptyText or "")

    local elements = {}
    local newDivider
    for index, entry in ipairs(entries) do
        if index == options.firstUnread then
            -- Goes in after that day's divider.
            newDivider = { kind = "new", text = (options.unreadCount or 0) .. " new" }
            self.state.newDivider = newDivider
        end
        self:AddEntry(elements, entry)
    end
    self.state.newDivider = nil

    local fromBottom = options.keepPosition and self:GetDistanceFromBottom()
    local atBottom = not options.keepPosition or self:IsAtBottom()
    self.dataProvider = CreateDataProvider(elements)
    self.scrollBox:SetDataProvider(self.dataProvider, ScrollBoxConstants.RetainScrollPosition)
    self:UpdateEmptyText()

    if not atBottom then
        self:SetDistanceFromBottom(fromBottom)
        return
    end
    self:ScrollToBottom()
    -- Start at the first unread message when they don't all fit.
    if newDivider then
        local index = self.dataProvider:FindIndex(newDivider)
        if index and self.scrollBox:GetExtentUntil(index)
            < self.scrollBox:GetDerivedScrollOffset() then
            self.scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignBegin,
                0, ScrollBoxConstants.NoScrollInterpolation)
        end
    end
end

function List:UpdateEmptyText()
    self.emptyText:SetShown(self.dataProvider:GetSize() == 0)
end

function List:InsertElements(elements, scrollToBottom)
    if #elements == 0 then return end
    local atBottom = self:IsAtBottom()
    self.dataProvider:Insert(unpack(elements))
    self:UpdateEmptyText()
    if scrollToBottom or atBottom then
        self:ScrollToBottom()
    else
        self.newMessagesButton:Show()
    end
end

-- Adds a new message at the end. While the reader is scrolled up the view
-- stays put and a button offers to jump down, unless scrollToBottom.
function List:AppendEntry(entry, scrollToBottom)
    local elements = {}
    self:AddEntry(elements, entry)
    self:InsertElements(elements, scrollToBottom)
end

-- A line from TrialChat itself; it isn't kept in the history.
function List:AddNotice(text, color)
    self.state.last = nil
    self:InsertElements({ { kind = "notice", text = text, color = color or Color.muted } }, true)
end
