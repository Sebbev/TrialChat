TrialChatCommon = {}

local playerName
local playerRealm
local fullPlayerName
local normalizedPlayerRealm
local playerClass
local linkInputs = {}
local linkInsertHooked = false

function TrialChatCommon.RefreshPlayerIdentity()
    playerName = UnitName("player")
    fullPlayerName, playerRealm = UnitFullName("player")
    normalizedPlayerRealm = GetNormalizedRealmName and GetNormalizedRealmName()
    _, playerClass = UnitClass("player")
    if fullPlayerName and playerRealm and playerRealm ~= "" then
        fullPlayerName = fullPlayerName .. "-" .. playerRealm
    end
end

function TrialChatCommon.GetPlayerName()
    return playerName
end

function TrialChatCommon.GetPlayerFullName()
    return fullPlayerName or playerName
end

function TrialChatCommon.GetPlayerClass()
    return playerClass
end

function TrialChatCommon.GetPlayerRealm()
    return playerRealm
end

function TrialChatCommon.NormalizeName(name)
    return name and strlower(name) or nil
end

function TrialChatCommon.ShortName(name)
    return string.match(name or "", "^([^-]+)") or name
end

function TrialChatCommon.NormalizeCharacterName(name)
    local normalized = TrialChatCommon.NormalizeName(name)
    if not normalized then return nil end

    local shortName, realm = string.match(name, "^([^-]+)%-(.+)$")
    if shortName then
        return TrialChatCommon.NormalizeName(shortName) .. "-"
            .. TrialChatCommon.NormalizeRealm(realm)
    end
    if playerRealm and playerRealm ~= "" then
        return normalized .. "-" .. TrialChatCommon.NormalizeRealm(playerRealm)
    end
    return normalized
end

function TrialChatCommon.NormalizeRealm(realm)
    return TrialChatCommon.NormalizeName((string.gsub(realm or "", "[%s']", "")))
end

function TrialChatCommon.IsSelf(sender)
    if not sender or sender == "" then return false end

    local senderKey = TrialChatCommon.NormalizeName(sender)
    if senderKey == TrialChatCommon.NormalizeName(fullPlayerName) then
        return true
    end

    local senderShort, senderRealm = string.match(sender, "^([^-]+)%-(.+)$")
    if not senderShort then
        return senderKey == TrialChatCommon.NormalizeName(playerName)
    end
    if TrialChatCommon.NormalizeName(senderShort)
        ~= TrialChatCommon.NormalizeName(playerName) then
        return false
    end

    local currentRealm = normalizedPlayerRealm or playerRealm
    if not currentRealm or currentRealm == "" then return false end
    return TrialChatCommon.NormalizeRealm(senderRealm)
        == TrialChatCommon.NormalizeRealm(currentRealm)
end

function TrialChatCommon.NamesMatch(left, right)
    if TrialChatCommon.NormalizeName(left) == TrialChatCommon.NormalizeName(right) then
        return true
    end
    if string.find(left or "", "-", 1, true)
        and string.find(right or "", "-", 1, true) then
        return false
    end

    local leftShort = string.match(left or "", "^([^-]+)")
    local rightShort = string.match(right or "", "^([^-]+)")
    return leftShort ~= nil
        and TrialChatCommon.NormalizeName(leftShort)
            == TrialChatCommon.NormalizeName(rightShort)
end

function TrialChatCommon.GetClassColor(classFile)
    local classColor = classFile and RAID_CLASS_COLORS[classFile]
    if not classColor then return nil end
    if classColor.colorStr then
        return "|c" .. classColor.colorStr
    end

    return string.format("|cff%02x%02x%02x",
        math.floor(classColor.r * 255),
        math.floor(classColor.g * 255),
        math.floor(classColor.b * 255))
end

TrialChatCommon.RefreshPlayerIdentity()

-- Classes of other TrialChat users, so names and avatars keep their class
-- color. Classes learned from nameplates are only kept for this session;
-- ones of people you chat with are saved.
local MAX_SAVED_CLASSES = 2000
local knownClasses = {}

local function getSavedClasses()
    TrialChatDB = TrialChatDB or {}
    if type(TrialChatDB.classes) ~= "table" then
        TrialChatDB.classes = {}
        TrialChatDB.classCount = 0
    end
    return TrialChatDB.classes
end

function TrialChatCommon.RememberClass(name, classFile, keep)
    if not name or name == "" or not classFile or not RAID_CLASS_COLORS[classFile] then
        return
    end
    local key = TrialChatCommon.NormalizeCharacterName(name)
    knownClasses[key] = classFile
    if not keep then return end

    local savedClasses = getSavedClasses()
    if savedClasses[key] == nil then
        if (TrialChatDB.classCount or 0) >= MAX_SAVED_CLASSES then return end
        TrialChatDB.classCount = (TrialChatDB.classCount or 0) + 1
    end
    savedClasses[key] = classFile
end

function TrialChatCommon.GetKnownClass(name)
    if not name or name == "" then return nil end
    if TrialChatCommon.IsSelf(name) then return playerClass end

    local key = TrialChatCommon.NormalizeCharacterName(name)
    local savedClasses = TrialChatDB and type(TrialChatDB.classes) == "table"
        and TrialChatDB.classes
    return knownClasses[key] or (savedClasses and savedClasses[key])
end

function TrialChatCommon.RegisterLinkInput(input)
    linkInputs[input] = true

    input:HookScript("OnEditFocusGained", function(self)
        if ChatFrameUtil and ChatFrameUtil.SetChatFocusOverride then
            ChatFrameUtil.SetChatFocusOverride(self)
        end
    end)
    local function clearChatFocusOverride(self)
        if ChatFrameUtil
            and ChatFrameUtil.GetChatFocusOverride
            and ChatFrameUtil.GetChatFocusOverride() == self
            and ChatFrameUtil.ClearChatFocusOverride then
            ChatFrameUtil.ClearChatFocusOverride()
        end
    end
    input:HookScript("OnEditFocusLost", clearChatFocusOverride)
    input:HookScript("OnHide", clearChatFocusOverride)

    if linkInsertHooked or not ChatFrameUtil or not ChatFrameUtil.InsertLink then
        return
    end

    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link)
        if not link then return end

        for registeredInput in pairs(linkInputs) do
            if registeredInput:IsShown() and registeredInput:HasFocus() then
                registeredInput:Insert(link)
                return
            end
        end
    end)
    linkInsertHooked = true
end

function TrialChatCommon.NormalizeMessageMarkup(text)
    text = string.gsub(text, "||([cChHrRtT])", "|%1")
    text = string.gsub(text, "\\124([cChHrRtT])", "|%1")

    local isPastedScript = string.match(text, "^%s*/script%s+")
        or string.find(text, "DEFAULT_CHAT_FRAME:AddMessage(", 1, true)
    if isPastedScript then
        local itemLink = string.match(text,
            "|cnIQ%d+:|Hitem:[^|]+|h[^|]*|h|r")
            or string.match(text,
                "|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h[^|]*|h|r")
        if itemLink then
            return itemLink
        end
    end

    return text
end

function TrialChatCommon.EncodeMessageMarkup(text)
    text = string.gsub(text, "~", "~~")
    return (string.gsub(text, "|", "~p"))
end

function TrialChatCommon.DecodeMessageMarkup(text)
    return (string.gsub(text, "~.", function(escape)
        if escape == "~~" then
            return "~"
        elseif escape == "~p" then
            return "|"
        end
        return escape
    end))
end

-- Messages longer than one addon message (255 bytes) are sent in numbered
-- parts and put back together by the receiver.
local MAX_MESSAGE_PARTS = 16
local MAX_PENDING_PER_SENDER = 4
local PART_TIMEOUT_SECONDS = 30

function TrialChatCommon.SplitIntoParts(text, partBytes)
    local parts = {}
    for start = 1, #text, partBytes do
        parts[#parts + 1] = string.sub(text, start, start + partBytes - 1)
    end
    return parts
end

function TrialChatCommon.NewPartId()
    return string.format("%06x", math.random(0, 0xffffff))
end

function TrialChatCommon.NewPartCollector()
    local pendingBySender = {}
    local lastSweepAt = 0
    local collector = {}

    local function sweepExpired(now)
        lastSweepAt = now
        for senderKey, pending in pairs(pendingBySender) do
            for id, message in pairs(pending) do
                if now - message.startedAt > PART_TIMEOUT_SECONDS then
                    pending[id] = nil
                end
            end
            if not next(pending) then
                pendingBySender[senderKey] = nil
            end
        end
    end

    -- Returns the whole text once every part has arrived, otherwise nil.
    function collector:Add(senderKey, partId, index, count, chunk)
        if not senderKey or not partId or not index or not count or not chunk
            or count < 2 or count > MAX_MESSAGE_PARTS
            or index < 1 or index > count then
            return nil
        end

        local now = GetTime()
        if now - lastSweepAt > PART_TIMEOUT_SECONDS then
            sweepExpired(now)
        end
        local pending = pendingBySender[senderKey] or {}
        pendingBySender[senderKey] = pending
        local oldestId, oldestTime, pendingCount = nil, nil, 0
        for id, message in pairs(pending) do
            if now - message.startedAt > PART_TIMEOUT_SECONDS then
                pending[id] = nil
            else
                pendingCount = pendingCount + 1
                if not oldestTime or message.startedAt < oldestTime then
                    oldestId, oldestTime = id, message.startedAt
                end
            end
        end

        local message = pending[partId]
        if not message then
            if pendingCount >= MAX_PENDING_PER_SENDER then
                pending[oldestId] = nil
            end
            message = { count = count, chunks = {}, received = 0, startedAt = now }
            pending[partId] = message
        elseif message.count ~= count then
            pending[partId] = nil
            return nil
        end

        if not message.chunks[index] then
            message.chunks[index] = chunk
            message.received = message.received + 1
        end
        if message.received < count then return nil end

        pending[partId] = nil
        if not next(pending) then
            pendingBySender[senderKey] = nil
        end
        return table.concat(message.chunks)
    end

    return collector
end

local function encodeLinkPayload(text)
    return (string.gsub(text, ".", function(char)
        return string.format("%02x", string.byte(char))
    end))
end

local function decodeLinkPayload(text)
    if #text % 2 ~= 0 or string.find(text, "[^%x]") then return nil end

    return (string.gsub(text, "%x%x", function(byte)
        return string.char(tonumber(byte, 16))
    end))
end

local function makeURLLink(url)
    local encodedURL = encodeLinkPayload(url)
    return "|cff00ccff|Htcurl:" .. encodedURL .. "|h" .. url .. "|h|r"
end

local function findHyperlinkEnd(text, position)
    local targetEnd = string.find(text, "|h", position + 2, true)
    if not targetEnd then return nil end

    local displayEnd = targetEnd + 2
    while true do
        local linkEnd = string.find(text, "|h", displayEnd, true)
        if not linkEnd then return nil end
        if string.sub(text, linkEnd - 1, linkEnd - 1) ~= "|" then
            return linkEnd + 1
        end
        displayEnd = linkEnd + 2
    end
end

function TrialChatCommon.FormatMessageText(text)
    local result = {}
    local position = 1

    while position <= #text do
        local namedColorLinkStart, namedColorLinkEnd =
            string.find(text, "^|cn[%a]+%d+:|H[^|]+|h[^|]*|h|r", position)
        if namedColorLinkStart ~= position then
            namedColorLinkStart = nil
        end

        if namedColorLinkStart then
            result[#result + 1] =
                string.sub(text, namedColorLinkStart, namedColorLinkEnd)
            position = namedColorLinkEnd + 1
        else
            local colorEnd = string.sub(text, position, position + 1) == "|c"
                and position + 9
                or nil
            if colorEnd and string.match(
                string.sub(text, position + 2, colorEnd),
                "^%x%x%x%x%x%x%x%x$") then
                result[#result + 1] = string.sub(text, position, colorEnd)
                position = colorEnd + 1
            elseif string.sub(text, position, position + 1) == "|r" then
                result[#result + 1] = "|r"
                position = position + 2
            elseif string.sub(text, position, position + 1) == "||" then
                result[#result + 1] = "||"
                position = position + 2
            else
                local url = string.match(text, "^https?://[^%s<>\"|]+", position)
                if url then
                    url = string.gsub(url, "[.,!?;:)]+$", "")
                end
                local linkStart, linkEnd
                if url and #url > 0 then
                    result[#result + 1] = makeURLLink(url)
                    position = position + #url
                else
                    linkEnd = findHyperlinkEnd(text, position)
                    if linkEnd then
                        linkStart = position
                    end
                end
                if not url and linkStart == position then
                    result[#result + 1] = string.sub(text, linkStart, linkEnd)
                    position = linkEnd + 1
                elseif not url then
                    local char = string.sub(text, position, position)
                    result[#result + 1] = char == "|" and "||" or char
                    position = position + 1
                end
            end
        end
    end

    return table.concat(result)
end

local urlDialog

local function showURLCopyDialog(url)
    if not urlDialog then
        urlDialog = CreateFrame("Frame", "TrialChatURLDialog", UIParent, "BackdropTemplate")
        urlDialog:SetSize(460, 130)
        urlDialog:SetPoint("CENTER")
        urlDialog:SetFrameStrata("DIALOG")
        urlDialog:SetFrameLevel(200)
        urlDialog:SetMovable(true)
        urlDialog:EnableMouse(true)
        urlDialog:RegisterForDrag("LeftButton")
        urlDialog:SetScript("OnDragStart", urlDialog.StartMoving)
        urlDialog:SetScript("OnDragStop", urlDialog.StopMovingOrSizing)
        urlDialog:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        urlDialog:SetBackdropColor(0.04, 0.04, 0.04, 0.95)

        local title = urlDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", urlDialog, "TOP", 0, -14)
        title:SetText("Copy this URL")

        local instructions = urlDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instructions:SetPoint("TOP", title, "BOTTOM", 0, -8)
        instructions:SetText("WoW does not allow addons to open arbitrary websites. Press Ctrl+C to copy.")

        urlDialog.input = CreateFrame("EditBox", nil, urlDialog, "InputBoxTemplate")
        urlDialog.input:SetPoint("TOPLEFT", urlDialog, "TOPLEFT", 18, -62)
        urlDialog.input:SetPoint("RIGHT", urlDialog, "RIGHT", -18, 0)
        urlDialog.input:SetHeight(24)
        urlDialog.input:SetAutoFocus(false)
        urlDialog.input:SetMaxLetters(2048)

        local closeButton = CreateFrame("Button", nil, urlDialog, "UIPanelButtonTemplate")
        closeButton:SetSize(70, 22)
        closeButton:SetPoint("BOTTOM", urlDialog, "BOTTOM", 0, 10)
        closeButton:SetText(CLOSE)
        closeButton:SetScript("OnClick", function()
            urlDialog:Hide()
        end)
        urlDialog:Hide()
    end

    urlDialog.input:SetText(url)
    urlDialog:Show()
    urlDialog.input:SetFocus()
    urlDialog.input:HighlightText()
end

function TrialChatCommon.HandleHyperlinkClick(link, text, button)
    local encodedPlayerName = string.match(link or "", "^tcplayer:(%x+)$")
    if encodedPlayerName then
        local playerName = decodeLinkPayload(encodedPlayerName)
        TrialChatCommon.ShowPlayerOptions(playerName, text, button)
        return
    end

    local encodedURL = string.match(link or "", "^tcurl:(%x+)$")
    local url = encodedURL and decodeLinkPayload(encodedURL)
    if url and string.match(url, "^https?://") and not string.find(url, "[%c|]") then
        showURLCopyDialog(url)
        return
    end

    SetItemRef(link, text, button, DEFAULT_CHAT_FRAME)
end

function TrialChatCommon.ShowPlayerOptions(playerName, displayName, button)
    if not playerName or playerName == ""
        or string.find(playerName, "[%c|]") then
        return
    end

    SetItemRef("player:" .. playerName, displayName or playerName,
        button or "LeftButton", DEFAULT_CHAT_FRAME)
end

function TrialChatCommon.RemovePlayerLinks(text)
    text = string.gsub(text, "|Htcplayer:%x+|h(.-)|h", "%1", 1)
    return (string.gsub(text, "|Hplayer:[^|]+|h(.-)|h", "%1", 1))
end

-- Musician song links you post name no player, because the song is yours.
-- In normal chat, Musician's own chat filter adds the sender as the song's
-- owner when the message arrives; TrialChat messages never go through that
-- filter, so without this, clicking the link asks the wrong player (the one
-- clicking) for the song and the import fails.
local SONG_LINK_WITHOUT_OWNER = "|HmusicianSong|h"

local function setSongLinkOwner(text, owner)
    return (string.gsub(text, SONG_LINK_WITHOUT_OWNER, function()
        return "|HmusicianSong:" .. owner .. "|h"
    end))
end

-- For received messages: links without an owner belong to the sender, and
-- with Musician installed, typed [Music: Title] text becomes a link too.
function TrialChatCommon.AddSongLinkOwner(text, sender)
    if not text or not sender or sender == ""
        or TrialChatCommon.IsSelf(sender) then
        return text
    end
    text = setSongLinkOwner(text, sender)
    local songLinks = Musician and Musician.SongLinks
    if songLinks and songLinks.ChatLinksToHyperlinks then
        text = songLinks.ChatLinksToHyperlinks(text, sender)
    end
    return text
end

-- For sent messages: name yourself as the owner, so players on older
-- TrialChat versions that don't add it get working links as well.
function TrialChatCommon.AddOwnSongLinkOwner(text)
    local playerFullName = TrialChatCommon.GetPlayerFullName()
    if not text or not playerFullName then return text end
    return setSongLinkOwner(text, playerFullName)
end

function TrialChatCommon.ParseEmote(message)
    message = TrialChatCommon.NormalizeMessageMarkup(message)
    local command, argument = string.match(message, "^/([%a]+)%s*(.-)%s*$")
    if not command then
        return message, false
    end

    command = string.lower(command)
    if command == "e" or command == "em" or command == "emote" or command == "me" then
        if argument == "" then
            return nil
        end
        return argument, true, nil, nil
    end

    local description = TrialChatCommon.EmoteDescriptions[command]
    if not description then
        return message, false
    end

    local target = argument
    if target == "" and UnitExists("target") then
        target = UnitName("target") or ""
    end

    if target ~= "" then
        local targetedDescription =
            TrialChatCommon.TargetedEmoteDescriptions[command]
        if targetedDescription then
            description = string.gsub(targetedDescription,
                "%[playername%]", function() return target end)
        end
    end

    local token = _G.hash_EmoteTokenList
        and _G.hash_EmoteTokenList["/" .. string.upper(command)]
    return description, true, token, target ~= "" and target or nil
end

function TrialChatCommon.PerformEmote(token, target)
    if not token then return end
    C_ChatInfo.PerformEmote(token, target)
end

-- Chat logs: stay where you are while you're scrolled up reading older
-- messages (the log keeps its place when lines are added), and show a
-- "New messages" button instead of jumping to the bottom.
function TrialChatCommon.SetUpChatLog(log)
    local newMessagesButton = CreateFrame(
        "Button", nil, log:GetParent(), "UIPanelButtonTemplate")
    newMessagesButton:SetSize(110, 18)
    newMessagesButton:SetPoint("BOTTOM", log, "BOTTOM", 0, 2)
    newMessagesButton:SetFrameLevel(log:GetFrameLevel() + 5)
    newMessagesButton:SetNormalFontObject("GameFontNormalSmall")
    newMessagesButton:SetText("New messages")
    newMessagesButton:SetScript("OnClick", function()
        log:ScrollToBottom()
    end)
    newMessagesButton:Hide()
    log.newMessagesButton = newMessagesButton

    log:SetOnScrollChangedCallback(function(_, offset)
        if offset == 0 then
            newMessagesButton:Hide()
        end
    end)

    -- A scroll bar to the right of the log, wired up the same way as
    -- Blizzard's own chat logs; this also makes the mouse wheel scroll
    -- three lines at a time.
    if ScrollUtil and ScrollUtil.InitScrollingMessageFrameWithScrollBar then
        local scrollBar = CreateFrame(
            "EventFrame", nil, log:GetParent(), "MinimalScrollBar")
        scrollBar:SetPoint("TOPLEFT", log, "TOPRIGHT", 6, 0)
        scrollBar:SetPoint("BOTTOMLEFT", log, "BOTTOMRIGHT", 6, 0)
        ScrollUtil.InitScrollingMessageFrameWithScrollBar(log, scrollBar)
        log.scrollBar = scrollBar
    else
        log:EnableMouseWheel(true)
        log:SetScript("OnMouseWheel", function(self, delta)
            if delta > 0 then
                self:ScrollUp()
            else
                self:ScrollDown()
            end
        end)
    end
end

function TrialChatCommon.AddChatLogMessage(log, line, scrollToBottom)
    log:AddMessage(line)
    if scrollToBottom then
        log:ScrollToBottom()
    elseif not log:AtBottom() and log.newMessagesButton then
        log.newMessagesButton:Show()
    end
end

-- Replaces everything in a chat log. With keepPosition, a reader who has
-- scrolled up stays the same distance from the bottom.
function TrialChatCommon.SetChatLogLines(log, lines, keepPosition)
    local offset = keepPosition and log:GetScrollOffset() or 0
    log:Clear()
    for _, line in ipairs(lines) do
        log:AddMessage(line)
    end
    if offset > 0 then
        log:SetScrollOffset(offset)
    else
        log:ScrollToBottom()
    end
end

-- First line of a chat log that holds more stored messages than it shows.
function TrialChatCommon.GetOlderMessagesLine(hiddenCount)
    return "|cff9d9d9d|Htcolder|h[Show older messages (" .. hiddenCount
        .. " more)]|h|r"
end

local FADE_IN_PER_SECOND = 4
local FADE_OUT_PER_SECOND = 1.5
local fadingFrames = {}
local fadeDriver = CreateFrame("Frame")
fadeDriver:Hide()
fadeDriver:SetScript("OnUpdate", function(self, elapsed)
    for frame, targetAlpha in pairs(fadingFrames) do
        local alpha = frame:GetAlpha()
        if alpha < targetAlpha then
            alpha = math.min(targetAlpha, alpha + elapsed * FADE_IN_PER_SECOND)
        else
            alpha = math.max(targetAlpha, alpha - elapsed * FADE_OUT_PER_SECOND)
        end
        frame:SetAlpha(alpha)
        if alpha == targetAlpha then
            fadingFrames[frame] = nil
        end
    end
    if not next(fadingFrames) then
        self:Hide()
    end
end)

local HOVER_CHECK_SECONDS = 0.05

-- OnEnter/OnLeave are missed when the cursor moves quickly onto or off a
-- child that takes the mouse (like a chat log), so while the frame is shown
-- also re-check whether the cursor is over it a few times a second.
function TrialChatCommon.WatchHover(frame, update)
    local sinceLastCheck = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        sinceLastCheck = sinceLastCheck + elapsed
        if sinceLastCheck >= HOVER_CHECK_SECONDS then
            sinceLastCheck = 0
            update()
        end
    end)
end

-- Fades a frame towards the given alpha instead of jumping to it: quickly
-- when it becomes more visible, more gently when it fades back.
function TrialChatCommon.FadeTo(frame, targetAlpha)
    if frame:GetAlpha() == targetAlpha then
        fadingFrames[frame] = nil
        return
    end
    fadingFrames[frame] = targetAlpha
    fadeDriver:Show()
end
