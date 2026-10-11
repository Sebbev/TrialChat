-- The minimal view of TrialChat: the newest messages of the open
-- conversation over the game world, fading with age like the chat frames,
-- a row of conversations and a message box. When another conversation gets
-- a message, a notice shows in the corner. The full window is a click away.
TrialChatMinimalView = {}
local UI = TrialChatUI
local Color = UI.Color

local WIDTH = 520
local MAX_LINES = 8
local LINE_GAP = 4
local LINE_PADDING_X = 8
local LINE_PADDING_Y = 4
local LINE_TEXT_WIDTH = WIDTH - 2 * LINE_PADDING_X
local LINE_VISIBLE_SECONDS = 30
local LINE_FADE_SECONDS = 4
-- While you aren't using the view, older lines are dimmer (newest first).
local LINE_ALPHA_BY_AGE = { 1, 1, 0.8, 0.55 }
local OLDEST_LINE_ALPHA = 0.35
local PILL_HEIGHT = 26
local PILL_GAP = 6
local GRIP_WIDTH = 18
local ROW_GAP = 8
local COMPOSER_HEIGHT = 38
local IDLE_ALPHA = 0.45
local RECENT_SECONDS = 7
local UPDATE_SECONDS = 0.1
local TOAST_WIDTH = 300
local TOAST_SECONDS = 8
local DEFAULT_X, DEFAULT_Y = 40, 300
local SEPARATOR = " \194\183 " -- a middle dot

local View = {}
View.__index = View

-- The keybinding to reply with, when there is one.
local function getReplyHint()
    local key = GetBindingKey and GetBindingKey("TRIALCHAT_OPEN")
    if key then
        return "Press " .. (GetBindingText and GetBindingText(key) or key) .. " to reply"
    end
    return "Click to reply"
end

-- controller gives the view its data and does what it asks:
-- GetSelected(), Select(key), Cycle(step), GetConversations() (Nearby and
-- connected groups as { key, name, unread }), GetEntries() (the open
-- conversation's history, how to format a message and color a name),
-- GetName(), GetMessageLimit(), Send(text), ShowFullView(), GetSettings(),
-- OnShown() and OnHidden().
function TrialChatMinimalView.Create(controller)
    local view = setmetatable({
        controller = controller, lines = {}, chips = {}, pills = {},
    }, View)

    local frame = CreateFrame("Frame", "TrialChatMinimalFrame", UIParent)
    view.frame = frame
    frame:SetWidth(WIDTH)
    frame:SetHeight(COMPOSER_HEIGHT + ROW_GAP + PILL_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    view:DragBy(frame)
    view:RestorePosition()

    -- Everything but the messages fades back while you aren't using it.
    view.chrome = CreateFrame("Frame", nil, frame)
    view.chrome:SetAllPoints()
    view:CreateComposer()
    view.fullButton = UI.CreateButton(view.chrome, {
        style = "hud", icon = "expand", iconSize = 13, text = "Full view",
        height = PILL_HEIGHT, radius = 13, font = UI.Font.small,
        tooltip = "Open the full TrialChat window",
        onClick = function() controller.ShowFullView() end,
    })
    view.fullButton:SetPoint("BOTTOMRIGHT", view.composer, "TOPRIGHT", 0, ROW_GAP)
    view.grip = UI.CreateButton(view.chrome, {
        style = "ghost", icon = "grip", iconSize = 14, width = GRIP_WIDTH, height = PILL_HEIGHT,
        tooltip = "Drag to move",
    })
    view.grip:SetPoint("BOTTOMLEFT", view.composer, "TOPLEFT", 0, ROW_GAP)
    view:DragBy(view.grip)
    view:CreateToast()

    local sinceUpdate = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceUpdate = sinceUpdate + elapsed
        if sinceUpdate >= UPDATE_SECONDS then
            sinceUpdate = 0
            view:UpdateFade()
        end
    end)
    frame:SetScript("OnShow", function()
        controller.OnShown()
        view:UpdateFade()
    end)
    frame:SetScript("OnHide", function()
        view.input:ClearFocus()
        controller.OnHidden()
    end)
    frame:Hide()
    return view
end

-- The view can be dragged by its grip, its messages, the "To ..." end of
-- the message box, and any empty space in it.
function View:DragBy(region)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", function()
        self.moving = true
        self.frame:StartMoving()
    end)
    region:SetScript("OnDragStop", function()
        self.frame:StopMovingOrSizing()
        self.moving = false
        self.movedAt = GetTime()
        self:SavePosition()
    end)
end

function View:CreateComposer()
    local composer = CreateFrame("Frame", nil, self.chrome)
    self.composer = composer
    composer:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 0)
    composer:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
    composer:SetHeight(COMPOSER_HEIGHT)
    composer.box = UI.CreateBox(composer, { radius = COMPOSER_HEIGHT / 2, border = true })
    composer.box:SetColor(Color.sidebar, 0.88)
    composer.box:SetBorderColor(Color.white, 0.18)
    composer:EnableMouse(true)
    self:DragBy(composer)
    -- A click there (not the end of a drag) starts typing.
    composer:SetScript("OnMouseUp", function(_, button)
        local justMoved = self.movedAt and GetTime() - self.movedAt < 0.2
        if button == "LeftButton" and not self.moving and not justMoved then
            self.input:SetFocus()
        end
    end)

    self.label = UI.CreateText(composer, UI.Font.item, Color.accent)
    self.label:SetPoint("LEFT", composer, "LEFT", 16, 0)

    local input = CreateFrame("EditBox", nil, composer)
    self.input = input
    input:EnableMouse(true)
    input:SetAutoFocus(false)
    input:SetFontObject(UI.Font.body)
    UI.SetTextColor(input, Color.text)
    input:SetHeight(COMPOSER_HEIGHT - 8)
    input:SetPoint("LEFT", self.label, "RIGHT", 10, 0)
    input:SetPoint("RIGHT", composer, "RIGHT", -16, 0)

    self.placeholder = UI.CreateText(composer, UI.Font.body, Color.muted)
    self.placeholder:SetPoint("LEFT", input, "LEFT", 0, 0)
    self.placeholder:SetText("Say something...")
    self.hint = UI.CreateText(composer, UI.Font.small, Color.muted)
    self.hint:SetPoint("RIGHT", composer, "RIGHT", -16, 0)
    self.hint:SetText("Tab switches" .. SEPARATOR .. "Esc hides")

    TrialChatCommon.RegisterLinkInput(input)
    -- Like the game's chat: Enter sends and stops typing, Esc hides.
    input:SetScript("OnEnterPressed", function(box)
        local text = box:GetText()
        box:SetText("")
        box:ClearFocus()
        self.controller.Send(text)
    end)
    input:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        self:Hide()
    end)
    input:SetScript("OnTabPressed", function()
        self.controller.Cycle(IsShiftKeyDown() and -1 or 1)
    end)
    local function update()
        local empty = (input:GetText() or "") == ""
        self.placeholder:SetShown(empty)
        self.hint:SetShown(empty)
        self:UpdateFade()
    end
    input:HookScript("OnTextChanged", update)
    input:HookScript("OnEditFocusGained", update)
    input:HookScript("OnEditFocusLost", update)
end

---------------------------------------------------------------------------
-- Conversations
---------------------------------------------------------------------------
function View:CreatePill()
    local pill = UI.CreateButton(self.chrome, {
        style = "hud", text = "", height = PILL_HEIGHT, radius = 13, font = UI.Font.small,
        onClick = function(button) self.controller.Select(button.key) end,
    })
    self.pills[#self.pills + 1] = pill
    return pill
end

-- Pills for each conversation, in rows from the message box up, leaving
-- room for the Full view button on the first row.
function View:UpdateConversations()
    local selected = self.controller.GetSelected()
    local left = GRIP_WIDTH + 4
    local x, row = left, 0
    local rowWidth = WIDTH - self.fullButton:GetWidth() - PILL_GAP
    local count = 0
    for index, conversation in ipairs(self.controller.GetConversations()) do
        count = index
        local pill = self.pills[index] or self:CreatePill()
        pill.key = conversation.key
        local text = conversation.name
        if conversation.unread > 0 then
            text = text .. "  " .. UI.ColorText(Color.accent, tostring(conversation.unread))
        end
        pill:SetLabel(text)
        UI.SetButtonStyle(pill, conversation.key == selected and "accent" or "hud")
        local width = pill:GetWidth()
        if x > left and x + width > rowWidth then
            x, row, rowWidth = left, row + 1, WIDTH
        end
        pill:ClearAllPoints()
        pill:SetPoint("BOTTOMLEFT", self.composer, "TOPLEFT", x,
            ROW_GAP + row * (PILL_HEIGHT + PILL_GAP))
        pill:Show()
        x = x + width + PILL_GAP
    end
    for index = count + 1, #self.pills do
        self.pills[index]:Hide()
    end
    self.frame:SetHeight(COMPOSER_HEIGHT + ROW_GAP + (row + 1) * (PILL_HEIGHT + PILL_GAP) - PILL_GAP)
end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
function View:MakeLine(entry, format, colorFor)
    if type(entry) == "string" then
        return { text = TrialChatCommon.RemovePlayerLinks(entry), color = Color.text }
    end
    if type(entry) ~= "table" then return nil end

    local name = TrialChatCommon.ShortName(entry.sender or "?")
    if entry.isEmote then
        return { text = name .. " " .. format(entry), color = Color.emote }
    end
    return {
        text = UI.ColorText(colorFor(entry), name) .. ": " .. format(entry),
        color = Color.text,
    }
end

function View:CreateChip()
    local chip = CreateFrame("Frame", nil, self.frame)
    chip.box = UI.CreateBox(chip, { radius = 4 })
    chip.box:SetColor(Color.black, 0.55)
    chip.text = UI.CreateText(chip, UI.Font.body)
    chip.text:SetPoint("TOPLEFT", chip, "TOPLEFT", LINE_PADDING_X, -LINE_PADDING_Y)
    chip.text:SetJustifyH("LEFT")
    chip.text:SetWordWrap(true)
    chip.text:SetNonSpaceWrap(true)
    TrialChatMessageList.EnableLinks(chip)
    self:DragBy(chip)
    chip:Hide()
    self.chips[#self.chips + 1] = chip
    return chip
end

-- The lines stack up from the conversations, the newest at the bottom; each
-- background is as wide as its text.
function View:LayoutLines()
    local y = ROW_GAP
    local count = #self.lines
    for rank = 1, count do
        local line = self.lines[count - rank + 1]
        local chip = self.chips[rank] or self:CreateChip()
        chip.line = line
        chip.text:SetText(line.text)
        UI.SetTextColor(chip.text, line.color)
        local width = math.min(math.ceil(chip.text:GetUnboundedStringWidth()) + 1, LINE_TEXT_WIDTH)
        chip.text:SetWidth(width)
        chip:SetSize(width + 2 * LINE_PADDING_X,
            math.ceil(chip.text:GetStringHeight()) + 2 * LINE_PADDING_Y)
        chip:ClearAllPoints()
        chip:SetPoint("BOTTOMLEFT", self.frame, "TOPLEFT", 0, y)
        y = y + chip:GetHeight() + LINE_GAP
    end
    for rank = count + 1, #self.chips do
        self.chips[rank].line = nil
        self.chips[rank]:Hide()
    end
    self:UpdateFade()
end

function View:AddLine(line)
    line.shownAt = GetTime()
    self.lines[#self.lines + 1] = line
    while #self.lines > MAX_LINES do
        table.remove(self.lines, 1)
    end
    self.lastLineAt = line.shownAt
    self:LayoutLines()
end

-- Shows the newest messages of the open conversation.
function View:Render()
    local entries, format, colorFor = self.controller.GetEntries()
    local now = GetTime()
    self.lines = {}
    for index = math.max(1, #entries - MAX_LINES + 1), #entries do
        local line = self:MakeLine(entries[index], format, colorFor)
        if line then
            line.shownAt = now
            self.lines[#self.lines + 1] = line
        end
    end
    self:LayoutLines()
end

function View:AddEntry(entry)
    local _, format, colorFor = self.controller.GetEntries()
    local line = self:MakeLine(entry, format, colorFor)
    if line then
        self:AddLine(line)
    end
end

-- A line from TrialChat itself; it isn't kept in the history.
function View:AddNotice(text, color)
    self:AddLine({ text = text, color = color or Color.muted })
end

function View:Refresh()
    self.label:SetText("To " .. self.controller.GetName())
    self.input:SetMaxLetters(self.controller.GetMessageLimit())
    self:UpdateConversations()
    self:Render()
end

---------------------------------------------------------------------------
-- Fading
---------------------------------------------------------------------------
function View:IsActive()
    if self.input:HasFocus() or self.frame:IsMouseOver() then return true end
    for _, chip in ipairs(self.chips) do
        if chip:IsShown() and chip:IsMouseOver() then return true end
    end
    return false
end

-- While you hover or type, everything shows. Otherwise the rest fades back
-- and each message fades out a while after it came in, older ones dimmer.
function View:UpdateFade()
    local now = GetTime()
    local active = self:IsActive()
    local recent = self.lastLineAt and now - self.lastLineAt < RECENT_SECONDS
    TrialChatCommon.FadeTo(self.chrome, (active or recent) and 1 or IDLE_ALPHA)
    for rank, chip in ipairs(self.chips) do
        local line = chip.line
        local alpha = 0
        if line and active then
            alpha = 1
        elseif line then
            local left = 1 - math.max(0, now - line.shownAt - LINE_VISIBLE_SECONDS) / LINE_FADE_SECONDS
            alpha = math.max(0, left) * (LINE_ALPHA_BY_AGE[rank] or OLDEST_LINE_ALPHA)
        end
        chip:SetAlpha(alpha)
        chip:SetShown(alpha > 0)
    end
end

---------------------------------------------------------------------------
-- Showing, typing and position
---------------------------------------------------------------------------
function View:Show() self.frame:Show() end
function View:Hide() self.frame:Hide() end
function View:IsShown() return self.frame:IsShown() end
function View:FocusInput() self.input:SetFocus() end

function View:RestorePosition()
    local settings = self.controller.GetSettings()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
        tonumber(settings.minimalX) or DEFAULT_X, tonumber(settings.minimalY) or DEFAULT_Y)
end

function View:SavePosition()
    local settings = self.controller.GetSettings()
    settings.minimalX = self.frame:GetLeft()
    settings.minimalY = self.frame:GetBottom()
end

---------------------------------------------------------------------------
-- Notices of messages elsewhere
---------------------------------------------------------------------------
function View:CreateToast()
    local toast = CreateFrame("Button", "TrialChatToast", UIParent)
    self.toast = toast
    toast:SetWidth(TOAST_WIDTH)
    toast:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -230)
    toast:SetFrameStrata("HIGH")
    toast:RegisterForClicks("LeftButtonUp")
    toast.box = UI.CreateBox(toast, { radius = 10, border = true })
    toast.box:SetColor(Color.window, 0.92)
    toast.box:SetBorderColor(Color.white, 0.12)

    toast.title = UI.CreateText(toast, UI.Font.item, Color.accent)
    toast.title:SetPoint("TOPLEFT", toast, "TOPLEFT", 16, -14)
    toast.count = UI.CreateText(toast, UI.Font.small, Color.muted)
    toast.count:SetPoint("LEFT", toast.title, "RIGHT", 8, 0)
    toast.close = UI.CreateButton(toast, {
        style = "ghost", icon = "close", iconSize = 12, width = 24, height = 24,
        onClick = function() toast:Hide() end,
    })
    toast.close:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -8, -8)
    toast.text = UI.CreateText(toast, UI.Font.body)
    toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -8)
    toast.text:SetWidth(TOAST_WIDTH - 32)
    toast.text:SetJustifyH("LEFT")
    toast.text:SetWordWrap(true)
    toast.text:SetMaxLines(2)
    toast.hint = UI.CreateText(toast, UI.Font.small, Color.muted)
    toast.hint:SetPoint("TOPLEFT", toast.text, "BOTTOMLEFT", 0, -6)

    toast:SetScript("OnClick", function() self:Reply() end)
    toast:SetScript("OnUpdate", function()
        if GetTime() > (toast.hideAt or 0) and not toast:IsMouseOver() then
            toast:Hide()
        end
    end)
    toast:Hide()
end

-- entry is the message that came in for conversation key, which has unread
-- messages; format and colorFor are as for the conversation's history.
function View:ShowToast(key, name, unread, entry, format, colorFor)
    local line = self:MakeLine(entry, format, colorFor)
    if not line then return end
    local toast = self.toast
    toast.key = key
    toast.title:SetText(name)
    toast.count:SetText(unread > 1 and (unread .. " new") or "")
    toast.text:SetText(line.text)
    UI.SetTextColor(toast.text, line.color)
    toast.hint:SetText(getReplyHint())
    toast:SetHeight(math.ceil(14 + toast.title:GetStringHeight() + 8
        + toast.text:GetStringHeight() + 6 + toast.hint:GetStringHeight() + 14))
    toast.hideAt = GetTime() + TOAST_SECONDS
    toast:Show()
end

function View:GetToastKey()
    return self.toast:IsShown() and self.toast.key or nil
end

-- Opens the conversation from the notice, ready to type.
function View:Reply()
    local key = self.toast.key
    self.toast:Hide()
    self:Show()
    self.controller.Select(key)
    self:FocusInput()
end
