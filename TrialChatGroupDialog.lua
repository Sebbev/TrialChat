-- The "Create a group" and "Join a group" dialog, in the messenger's style.
-- TrialChatGroups checks what's entered and creates or joins the group;
-- when it can't, the reason shows in the dialog.
TrialChatGroupDialog = {}
local UI = TrialChatUI
local Color = UI.Color

local WIDTH = 360
local PADDING = 20
local TITLE_HEIGHT = 56
local LABEL_HEIGHT = 12
local LABEL_GAP = 6
local FIELD_HEIGHT = 32
local FIELD_GAP = 14
local BUTTON_HEIGHT = 32
local ICON_BUTTON_SIZE = 72

local dialog

local function getVisibleFields()
    local fields = {}
    for _, item in ipairs(dialog.fields) do
        if item.key ~= "memberName" or dialog.mode == "join" then
            fields[#fields + 1] = item
        end
    end
    return fields
end

local getChosenIcon

local function updateIconButton()
    if not dialog.iconButton then return end
    dialog.iconButton:SetIcon(getChosenIcon())
end

-- The icon the group will get: the one picked, or the one derived from the
-- name. Shown in the dialog so the preview matches what gets created.
getChosenIcon = function()
    if dialog.mode ~= "create" then return nil end
    if dialog.icon then return dialog.icon end
    local name = dialog.nameField and dialog.nameField:GetText() or ""
    return TrialChatCommon.GetDefaultGroupIcon(name)
end

-- The visible text fields, in display order.
local function getLayoutRows()
    local rows = {}
    for _, item in ipairs(getVisibleFields()) do
        rows[#rows + 1] = { label = item.label, control = item.field }
    end
    return rows
end

-- The icon preview (when creating), fields, problem (if any), then buttons.
local function layout()
    local y = -TITLE_HEIGHT
    for _, item in ipairs(dialog.fields) do
        item.label:Hide()
        item.field:Hide()
    end
    dialog.iconButton:Hide()
    if dialog.mode == "create" then
        dialog.iconButton:ClearAllPoints()
        dialog.iconButton:SetSize(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE)
        dialog.iconButton:SetPoint("TOP", dialog, "TOP", 0, y)
        dialog.iconButton:Show()
        y = y - ICON_BUTTON_SIZE - FIELD_GAP
    end
    for _, row in ipairs(getLayoutRows()) do
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", dialog, "TOPLEFT", PADDING, y)
        row.label:Show()
        y = y - LABEL_HEIGHT - LABEL_GAP
        row.control:ClearAllPoints()
        row.control:SetPoint("TOPLEFT", dialog, "TOPLEFT", PADDING, y)
        row.control:SetWidth(WIDTH - 2 * PADDING)
        row.control:Show()
        y = y - FIELD_HEIGHT - FIELD_GAP
    end
    local hasProblem = (dialog.problem:GetText() or "") ~= ""
    dialog.problem:SetShown(hasProblem)
    if hasProblem then
        dialog.problem:ClearAllPoints()
        dialog.problem:SetPoint("TOPLEFT", dialog, "TOPLEFT", PADDING, y + 2)
        y = y - math.ceil(dialog.problem:GetStringHeight()) - FIELD_GAP + 2
    end
    dialog:SetHeight(-y + BUTTON_HEIGHT + PADDING)
end

local function showProblem(text)
    dialog.problem:SetText(text or "")
    layout()
end

local function submit()
    local values = {}
    for _, item in ipairs(getVisibleFields()) do
        values[item.key] = item.field:GetText()
    end
    if dialog.mode == "create" then
        values.icon = getChosenIcon()
    end
    local problem = dialog.onSubmit(values)
    if problem then
        showProblem(problem)
        return
    end
    dialog:Hide()
end

-- Enter and Tab go to the next field; Enter in the last one submits.
local function focusNext(field, submitAtEnd)
    local fields = getVisibleFields()
    for index, item in ipairs(fields) do
        if item.field == field then
            local nextItem = fields[index + 1]
            if nextItem then
                nextItem.field:SetFocus()
            elseif submitAtEnd then
                submit()
            else
                fields[1].field:SetFocus()
            end
            return
        end
    end
end

local function addField(key, labelText, options)
    local item = { key = key }
    item.label = UI.CreateLabel(dialog, labelText)
    item.field = UI.CreateField(dialog, options)
    item.field:SetWidth(WIDTH - 2 * PADDING)
    item.field:SetScript("OnEnterPressed", function(field) focusNext(field, true) end)
    item.field:SetScript("OnTabPressed", function(field) focusNext(field, false) end)
    item.field:SetScript("OnEscapePressed", function() dialog:Hide() end)
    item.field:HookScript("OnTextChanged", function(_, userInput)
        if userInput and dialog.problem:IsShown() then
            showProblem(nil)
        end
    end)
    dialog.fields[#dialog.fields + 1] = item
    return item
end

local function createDialog()
    dialog = CreateFrame("Frame", "TrialChatGroupDialogFrame", UIParent)
    dialog:SetWidth(WIDTH)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    -- Above the TrialChat window.
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog.box = UI.CreateBox(dialog, { radius = 10, border = true })
    dialog.box:SetColor(Color.window)
    dialog.box:SetBorderColor(Color.outline)
    -- Esc closes it when no field has the cursor.
    if UISpecialFrames then
        table.insert(UISpecialFrames, "TrialChatGroupDialogFrame")
    end

    dialog.title = UI.CreateText(dialog, UI.Font.title)
    dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", PADDING, -20)
    dialog.close = UI.CreateButton(dialog, {
        style = "ghost", icon = "close", iconSize = 12, width = 28, height = 28,
        tooltip = "Close", onClick = function() dialog:Hide() end,
    })
    dialog.close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -12, -12)

    dialog.fields = {}
    addField("name", "Group name", {
        maxLetters = TrialChatGroups.MAX_NAME_BYTES,
        placeholder = "Letters, numbers, spaces",
    })
    dialog.nameField = dialog.fields[#dialog.fields].field
    dialog.nameField:HookScript("OnTextChanged", function(_, userInput)
        if userInput and dialog.mode == "create" then
            updateIconButton()
        end
    end)
    local password = addField("password", "Password", {
        maxLetters = TrialChatGroups.MAX_PASSWORD_BYTES,
        placeholder = "Shared by everyone in the group",
    })
    password.field:SetPassword(true)
    password.hint = UI.CreateText(dialog, UI.Font.small, Color.muted)
    password.hint:SetPoint("BOTTOMRIGHT", password.field, "TOPRIGHT", 0, LABEL_GAP)
    password.hint:SetText("Don't reuse a real password")
    password.field:SetScript("OnEnter", function(field)
        GameTooltip:SetOwner(field, "ANCHOR_RIGHT")
        GameTooltip:SetText("A shared key for the group, saved on this character.")
        GameTooltip:AddLine("It's sent in addon whispers to players who join or are invited.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    password.field:SetScript("OnLeave", GameTooltip_Hide)
    addField("memberName", "Connect through", {
        maxLetters = 64,
        placeholder = "Name of an online member",
    })

    dialog.iconButton = TrialChatIconPicker.CreateButton(dialog, {
        width = ICON_BUTTON_SIZE, height = ICON_BUTTON_SIZE, radius = 8,
        previewSize = ICON_BUTTON_SIZE - 8,
        tooltip = "Choose the group's icon. Everyone in the group sees it.",
        onClick = function()
            TrialChatIconPicker.Show(getChosenIcon(), function(icon)
                dialog.icon = icon
                updateIconButton()
            end)
        end,
    })

    dialog.problem = UI.CreateText(dialog, UI.Font.small, Color.error)
    dialog.problem:SetWidth(WIDTH - 2 * PADDING)
    dialog.problem:SetJustifyH("LEFT")
    dialog.problem:SetWordWrap(true)

    dialog.submit = UI.CreateButton(dialog, {
        style = "accent", text = "Create", height = BUTTON_HEIGHT, onClick = submit,
    })
    dialog.submit:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -PADDING, PADDING)
    dialog.cancel = UI.CreateButton(dialog, {
        style = "outline", text = "Cancel", height = BUTTON_HEIGHT,
        onClick = function() dialog:Hide() end,
    })
    dialog.cancel:SetPoint("RIGHT", dialog.submit, "LEFT", -8, 0)

    dialog:SetScript("OnHide", function()
        for _, item in ipairs(dialog.fields) do
            item.field:ClearFocus()
        end
    end)
    dialog:Hide()
end

-- mode is "create" or "join"; preset ({ name, password, memberName }) fills
-- the fields. onSubmit(values) creates or joins the group, or returns why it
-- can't.
function TrialChatGroupDialog.Show(mode, preset, onSubmit)
    if not dialog then createDialog() end
    dialog.mode = mode
    dialog.onSubmit = onSubmit
    dialog.title:SetText(mode == "create" and "Create a group" or "Join a group")
    dialog.submit:SetLabel(mode == "create" and "Create" or "Join")
    for _, item in ipairs(dialog.fields) do
        item.field:SetText(preset and preset[item.key] or "")
    end
    dialog.icon = preset and preset.icon or nil
    updateIconButton()
    dialog.problem:SetText("")
    layout()
    dialog:Show()
    dialog:Raise()
    -- The cursor starts in the first field that's still empty.
    local fields = getVisibleFields()
    local focus = fields[1]
    for _, item in ipairs(fields) do
        if (item.field:GetText() or "") == "" then
            focus = item
            break
        end
    end
    focus.field:SetFocus()
end
