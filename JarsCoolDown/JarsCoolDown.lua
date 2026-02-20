local configFrame
local icons = {}
local currentStacks = {}
local chargeCooldowns = {}
local iconContainer
local currentSpec = 1
local f -- Forward declaration for event frame
local isInCombat = false -- Cached combat state

-- Per-character, per-spec saved variables
JarsCoolDownDB = JarsCoolDownDB or {}

-- Get current profile based on spec
local function GetCurrentProfile()
    local specIndex = GetSpecialization() or 1
    currentSpec = specIndex
    
    -- Initialize spec profile if it doesn't exist
    if not JarsCoolDownDB[specIndex] then
        JarsCoolDownDB[specIndex] = {
            spells = {
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false},
                {spellID = 0, cooldown = 0, stacks = 0, resetID = 0, alwaysShow = false, haste = false}
            },
            iconSize = 64,
            bgOpacity = 0.8,
            locked = true,
            position = nil,
            onlyInCombat = false
        }
    end
    
    -- Ensure onlyInCombat exists for existing profiles
    if JarsCoolDownDB[specIndex].onlyInCombat == nil then
        JarsCoolDownDB[specIndex].onlyInCombat = false
    end
    
    return JarsCoolDownDB[specIndex]
end

-- Reload icons when spec changes
local function ReloadIcons()
    -- Clear existing icons
    if iconContainer then
        iconContainer:Hide()
        for i = 1, 6 do
            if icons[i] then
                icons[i]:Hide()
                icons[i]:SetScript("OnUpdate", nil)
            end
        end
    end

    -- Reset state
    icons = {}
    currentStacks = {}
    chargeCooldowns = {}
    iconContainer = nil

    -- Recreate config window for new spec
    if configFrame then
        configFrame:Hide()
        configFrame = nil
    end

    -- Trigger recreation by firing the PLAYER_ENTERING_WORLD handler directly
    C_Timer.After(0.1, function()
        f:GetScript("OnEvent")(f, "PLAYER_ENTERING_WORLD")
    end)
end

-- Modern dark UI color palette
local UI = {
    bg        = { 0.10, 0.10, 0.12, 0.95 },
    header    = { 0.13, 0.13, 0.16, 1 },
    accent    = { 0.30, 0.75, 0.75, 1 },
    accentDim = { 0.20, 0.50, 0.50, 1 },
    text      = { 0.90, 0.90, 0.90, 1 },
    textDim   = { 0.55, 0.55, 0.58, 1 },
    border    = { 0.22, 0.22, 0.26, 1 },
    sliderBg  = { 0.18, 0.18, 0.22, 1 },
    sliderFill= { 0.30, 0.75, 0.75, 0.6 },
    btnNormal = { 0.18, 0.18, 0.22, 1 },
    btnHover  = { 0.24, 0.24, 0.28, 1 },
    btnPress  = { 0.14, 0.14, 0.17, 1 },
    checkOn   = { 0.30, 0.75, 0.75, 1 },
    checkOff  = { 0.22, 0.22, 0.26, 1 },
}

local modernBackdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function CreateModernSlider(parent, name, labelText, minVal, maxVal, curVal, step, width, formatFunc, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, 40)

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(unpack(UI.text))
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText .. ": " .. formatFunc(curVal))
    container.label = label

    local track = CreateFrame("Frame", nil, container, "BackdropTemplate")
    track:SetSize(width, 6)
    track:SetPoint("TOPLEFT", 0, -18)
    track:SetBackdrop(modernBackdrop)
    track:SetBackdropColor(unpack(UI.sliderBg))
    track:SetBackdropBorderColor(unpack(UI.border))

    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetHeight(4)
    fill:SetColorTexture(unpack(UI.sliderFill))

    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(12, 12)
    thumb:SetFrameLevel(track:GetFrameLevel() + 2)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints()
    thumbTex:SetColorTexture(unpack(UI.accent))

    local function UpdateVisual(val)
        local pct = (val - minVal) / (maxVal - minVal)
        local usable = width - 12
        local xOff = pct * usable
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", track, "LEFT", xOff, 0)
        fill:SetWidth(math.max(1, xOff + 6))
        label:SetText(labelText .. ": " .. formatFunc(val))
    end

    container.value = curVal
    UpdateVisual(curVal)

    container.SetValue = function(self, v)
        v = math.max(minVal, math.min(maxVal, v))
        local stepped = math.floor(v / step + 0.5) * step
        self.value = stepped
        UpdateVisual(stepped)
        if onChange then onChange(stepped) end
    end
    container.GetValue = function(self) return self.value end

    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.dragging = true
        end
    end)
    track:SetScript("OnMouseUp", function(self)
        self.dragging = false
    end)
    track:SetScript("OnUpdate", function(self)
        if self.dragging and IsMouseButtonDown("LeftButton") then
            local x = select(1, GetCursorPosition()) / self:GetEffectiveScale()
            local left = self:GetLeft()
            local pct = math.max(0, math.min(1, (x - left) / width))
            local val = minVal + pct * (maxVal - minVal)
            container:SetValue(val)
        elseif self.dragging then
            self.dragging = false
        end
    end)

    return container
end

local function CreateModernCheck(parent, labelText, checked, onClick)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 18)

    local box = CreateFrame("Frame", nil, container, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(modernBackdrop)
    box:SetBackdropBorderColor(unpack(UI.border))

    local mark = box:CreateFontString(nil, "OVERLAY")
    mark:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    mark:SetPoint("CENTER", 0, 0)
    mark:SetTextColor(unpack(UI.accent))

    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetTextColor(unpack(UI.text))
    label:SetPoint("LEFT", box, "RIGHT", 6, 0)
    label:SetText(labelText)

    local state = checked and true or false

    local function Refresh()
        if state then
            box:SetBackdropColor(unpack(UI.checkOn))
            mark:SetText("\226\156\147")
        else
            box:SetBackdropColor(unpack(UI.checkOff))
            mark:SetText("")
        end
    end
    Refresh()

    container.SetChecked = function(self, v) state = v and true or false; Refresh() end
    container.GetChecked = function(self) return state end

    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
        state = not state
        Refresh()
        if onClick then onClick(container, state) end
    end)
    container:EnableMouse(true)
    container:SetScript("OnMouseDown", function()
        state = not state
        Refresh()
        if onClick then onClick(container, state) end
    end)

    return container
end

local function CreateSmallCheck(parent, checked, onClick)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetBackdrop(modernBackdrop)
    box:SetBackdropBorderColor(unpack(UI.border))

    local mark = box:CreateFontString(nil, "OVERLAY")
    mark:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    mark:SetPoint("CENTER", 0, 0)
    mark:SetTextColor(unpack(UI.accent))

    local state = checked and true or false

    local function Refresh()
        if state then
            box:SetBackdropColor(unpack(UI.checkOn))
            mark:SetText("\226\156\147")
        else
            box:SetBackdropColor(unpack(UI.checkOff))
            mark:SetText("")
        end
    end
    Refresh()

    box.SetChecked = function(self, v) state = v and true or false; Refresh() end
    box.GetChecked = function(self) return state end

    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
        state = not state
        Refresh()
        if onClick then onClick(box, state) end
    end)

    return box
end

local function CreateModernButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(modernBackdrop)
    btn:SetBackdropColor(unpack(UI.btnNormal))
    btn:SetBackdropBorderColor(unpack(UI.border))

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    label:SetPoint("CENTER", 0, 0)
    label:SetTextColor(unpack(UI.text))
    label:SetText(text)
    btn.label = label

    btn.SetText = function(self, t) self.label:SetText(t) end

    btn:EnableMouse(true)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(UI.btnHover))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(UI.btnNormal))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(unpack(UI.btnPress))
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(unpack(UI.btnHover))
        if onClick then onClick() end
    end)

    return btn
end

local function CreateSectionHeader(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    label:SetTextColor(unpack(UI.textDim))
    label:SetText(string.upper(text))
    return label
end

local function CreateConfigWindow()
    local profile = GetCurrentProfile()

    configFrame = CreateFrame("Frame", "JarsCoolDownConfig", UIParent, "BackdropTemplate")
    configFrame:SetSize(680, 480)
    configFrame:SetPoint("CENTER")
    configFrame:SetBackdrop(modernBackdrop)
    configFrame:SetBackdropColor(unpack(UI.bg))
    configFrame:SetBackdropBorderColor(unpack(UI.border))
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    tinsert(UISpecialFrames, "JarsCoolDownConfig")

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    titleBar:SetHeight(30)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop(modernBackdrop)
    titleBar:SetBackdropColor(unpack(UI.header))
    titleBar:SetBackdropBorderColor(unpack(UI.border))

    local specID, specName = GetSpecializationInfo(GetSpecialization() or 1)
    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    titleText:SetTextColor(unpack(UI.accent))
    titleText:SetPoint("LEFT", 10, 0)
    titleText:SetText("Jar's Cooldowns  -  " .. (specName or "Unknown"))
    configFrame.title = titleText

    -- Close button
    local closeBtn = CreateFrame("Frame", nil, titleBar)
    closeBtn:SetSize(30, 30)
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:EnableMouse(true)
    local closeX = closeBtn:CreateFontString(nil, "OVERLAY")
    closeX:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    closeX:SetPoint("CENTER", 0, 0)
    closeX:SetTextColor(unpack(UI.textDim))
    closeX:SetText("x")
    closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(1, 0.4, 0.4, 1) end)
    closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(unpack(UI.textDim)) end)
    closeBtn:SetScript("OnMouseDown", function() configFrame:Hide() end)

    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, configFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(636, 500)
    scrollFrame:SetScrollChild(content)

    -- Style the scrollbar
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -4, -34)
        scrollBar:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -4, 6)
    end

    local leftPad = 20
    local yOff = -8

    -- SPELLS section header
    local spellHeader = CreateSectionHeader(content, "Spells")
    spellHeader:SetPoint("TOPLEFT", leftPad, yOff)
    yOff = yOff - 18

    -- Column headers
    local cols = {
        { text = "SPELL ID", x = leftPad },
        { text = "COOLDOWN", x = leftPad + 110 },
        { text = "STACKS",   x = leftPad + 200 },
        { text = "RESET ID", x = leftPad + 280 },
        { text = "ALWAYS",   x = leftPad + 400 },
        { text = "HASTE",    x = leftPad + 470 },
    }
    for _, col in ipairs(cols) do
        local h = content:CreateFontString(nil, "OVERLAY")
        h:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        h:SetTextColor(unpack(UI.textDim))
        h:SetText(col.text)
        h:SetPoint("TOPLEFT", col.x, yOff)
    end
    yOff = yOff - 18

    -- Store input boxes for save button access
    local inputBoxes = {}

    -- Create 6 rows of inputs
    for i = 1, 6 do
        local index = i
        local rowY = yOff - ((i - 1) * 30)

        inputBoxes[index] = {}

        -- Spell ID input
        local spellIDBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        spellIDBox:SetSize(80, 25)
        spellIDBox:SetPoint("TOPLEFT", leftPad, rowY)
        spellIDBox:SetAutoFocus(false)
        spellIDBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        spellIDBox:SetText(tostring(profile.spells[index].spellID))
        spellIDBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        -- Spell icon display next to spellID box
        local spellIcon = CreateFrame("Frame", nil, content)
        spellIcon:SetSize(20, 20)
        spellIcon:SetPoint("LEFT", spellIDBox, "RIGHT", 5, 0)
        spellIcon.texture = spellIcon:CreateTexture(nil, "ARTWORK")
        spellIcon.texture:SetAllPoints()
        local iconTexture = C_Spell.GetSpellTexture(profile.spells[index].spellID)
        if iconTexture and profile.spells[index].spellID > 0 then
            spellIcon.texture:SetTexture(iconTexture)
        else
            spellIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        spellIDBox:SetScript("OnEnterPressed", function(self)
            profile.spells[index].spellID = tonumber(self:GetText()) or 0

            -- Update config icon
            local texture = C_Spell.GetSpellTexture(profile.spells[index].spellID)
            if texture and profile.spells[index].spellID > 0 then
                spellIcon.texture:SetTexture(texture)
            else
                spellIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Update main icon
            if icons[index] then
                if texture then
                    icons[index].texture:SetTexture(texture)
                end
            end
            self:ClearFocus()
        end)
        inputBoxes[index].spellIDBox = spellIDBox
        inputBoxes[index].spellIcon = spellIcon

        -- Cooldown input
        local cooldownBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        cooldownBox:SetSize(70, 25)
        cooldownBox:SetPoint("TOPLEFT", leftPad + 110, rowY)
        cooldownBox:SetAutoFocus(false)
        cooldownBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        cooldownBox:SetText(tostring(profile.spells[index].cooldown))
        cooldownBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        cooldownBox:SetScript("OnEnterPressed", function(self)
            profile.spells[index].cooldown = tonumber(self:GetText()) or 0
            self:ClearFocus()
        end)
        inputBoxes[index].cooldownBox = cooldownBox

        -- Stacks input
        local stacksBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        stacksBox:SetSize(60, 25)
        stacksBox:SetPoint("TOPLEFT", leftPad + 200, rowY)
        stacksBox:SetAutoFocus(false)
        stacksBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        stacksBox:SetText(tostring(profile.spells[index].stacks))
        stacksBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        stacksBox:SetScript("OnEnterPressed", function(self)
            profile.spells[index].stacks = tonumber(self:GetText()) or 0
            self:ClearFocus()
        end)
        inputBoxes[index].stacksBox = stacksBox

        -- Reset Spell ID input
        local resetBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        resetBox:SetSize(80, 25)
        resetBox:SetPoint("TOPLEFT", leftPad + 280, rowY)
        resetBox:SetAutoFocus(false)
        resetBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        resetBox:SetText(tostring(profile.spells[index].resetID))
        resetBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        -- Reset icon display next to resetID box
        local resetIcon = CreateFrame("Frame", nil, content)
        resetIcon:SetSize(20, 20)
        resetIcon:SetPoint("LEFT", resetBox, "RIGHT", 5, 0)
        resetIcon.texture = resetIcon:CreateTexture(nil, "ARTWORK")
        resetIcon.texture:SetAllPoints()
        local resetIconTexture = C_Spell.GetSpellTexture(profile.spells[index].resetID)
        if resetIconTexture and profile.spells[index].resetID > 0 then
            resetIcon.texture:SetTexture(resetIconTexture)
        else
            resetIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        resetBox:SetScript("OnEnterPressed", function(self)
            profile.spells[index].resetID = tonumber(self:GetText()) or 0

            -- Update icon
            local texture = C_Spell.GetSpellTexture(profile.spells[index].resetID)
            if texture and profile.spells[index].resetID > 0 then
                resetIcon.texture:SetTexture(texture)
            else
                resetIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            self:ClearFocus()
        end)
        inputBoxes[index].resetBox = resetBox
        inputBoxes[index].resetIcon = resetIcon

        -- Always Show checkbox (small)
        local alwaysCheck = CreateSmallCheck(content, profile.spells[index].alwaysShow, function(self, val)
            profile.spells[index].alwaysShow = val
            if icons[index] then
                if currentStacks[index] and currentStacks[index] == 0 then
                    icons[index]:Show()
                else
                    if profile.spells[index].alwaysShow and profile.spells[index].spellID > 0 then
                        icons[index]:Show()
                    else
                        icons[index]:Hide()
                    end
                end
            end
        end)
        alwaysCheck:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + 410, rowY - 4)
        inputBoxes[index].alwaysCheck = alwaysCheck

        -- Haste checkbox (small)
        local hasteCheck = CreateSmallCheck(content, profile.spells[index].haste, function(self, val)
            profile.spells[index].haste = val
        end)
        hasteCheck:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + 478, rowY - 4)
        inputBoxes[index].hasteCheck = hasteCheck
    end

    -- SETTINGS section
    yOff = yOff - (6 * 30) - 14
    local settingsHeader = CreateSectionHeader(content, "Settings")
    settingsHeader:SetPoint("TOPLEFT", leftPad, yOff)
    yOff = yOff - 22

    -- Icon Size slider
    local sizeSlider = CreateModernSlider(content, "IconSize", "Icon Size", 20, 100, profile.iconSize or 64, 1, 240,
        function(v) return tostring(math.floor(v)) end,
        function(val)
            local size = math.floor(val)
            profile.iconSize = size

            -- Update icon sizes and positions if icons exist
            if iconContainer and #icons > 0 then
                local padding = 2
                local spacing = size + padding
                local fontSize = math.max(12, math.floor(size * 0.75))

                for ii = 1, 6 do
                    if icons[ii] then
                        icons[ii]:SetSize(size, size)
                        if icons[ii].text then
                            icons[ii].text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                        end
                        local row = math.floor((ii - 1) / 3)
                        local col = (ii - 1) % 3
                        icons[ii]:ClearAllPoints()
                        icons[ii]:SetPoint("TOPLEFT", col * spacing, -row * spacing)
                    end
                end

                local containerWidth = (spacing * 3) - padding
                local containerHeight = (spacing * 2) - padding
                iconContainer:SetSize(containerWidth, containerHeight)
            end
        end
    )
    sizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOff)

    -- BG Opacity slider
    local opacitySlider = CreateModernSlider(content, "BgOpacity", "BG Opacity", 0, 1, profile.bgOpacity or 0.8, 0.01, 240,
        function(v) return string.format("%.0f%%", v * 100) end,
        function(val)
            profile.bgOpacity = val
            if iconContainer and iconContainer.background then
                iconContainer.background:SetAlpha(val)
            end
        end
    )
    opacitySlider:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad + 280, yOff)

    yOff = yOff - 52

    -- Only Show in Combat checkbox
    local combatCheck = CreateModernCheck(content, "Only Show in Combat", profile.onlyInCombat, function(self, val)
        profile.onlyInCombat = val
        if iconContainer then
            if profile.onlyInCombat and not isInCombat then
                iconContainer:Hide()
            else
                iconContainer:Show()
            end
        end
    end)
    combatCheck:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOff)

    -- ACTIONS section
    yOff = yOff - 30
    local actionsHeader = CreateSectionHeader(content, "Actions")
    actionsHeader:SetPoint("TOPLEFT", leftPad, yOff)
    yOff = yOff - 22

    -- Save button
    local saveButton = CreateModernButton(content, "Save", 100, 28, function()
        for i = 1, 6 do
            profile.spells[i].spellID = tonumber(inputBoxes[i].spellIDBox:GetText()) or 0
            profile.spells[i].cooldown = tonumber(inputBoxes[i].cooldownBox:GetText()) or 0
            profile.spells[i].stacks = tonumber(inputBoxes[i].stacksBox:GetText()) or 0
            profile.spells[i].resetID = tonumber(inputBoxes[i].resetBox:GetText()) or 0
            profile.spells[i].alwaysShow = inputBoxes[i].alwaysCheck:GetChecked()
            profile.spells[i].haste = inputBoxes[i].hasteCheck:GetChecked()

            -- Reset current stacks to max
            if profile.spells[i].stacks > 0 then
                currentStacks[i] = profile.spells[i].stacks
                chargeCooldowns[i] = {}
            else
                currentStacks[i] = 1
                chargeCooldowns[i] = {}
            end

            -- Update config window icons
            if inputBoxes[i].spellIcon then
                local spellTexture = C_Spell.GetSpellTexture(profile.spells[i].spellID)
                if spellTexture and profile.spells[i].spellID > 0 then
                    inputBoxes[i].spellIcon.texture:SetTexture(spellTexture)
                else
                    inputBoxes[i].spellIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
            end

            if inputBoxes[i].resetIcon then
                local resetTexture = C_Spell.GetSpellTexture(profile.spells[i].resetID)
                if resetTexture and profile.spells[i].resetID > 0 then
                    inputBoxes[i].resetIcon.texture:SetTexture(resetTexture)
                else
                    inputBoxes[i].resetIcon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
            end

            -- Update icon texture if icon exists
            if icons[i] then
                local texture = C_Spell.GetSpellTexture(profile.spells[i].spellID)
                if texture then
                    icons[i].texture:SetTexture(texture)
                end

                -- Update visibility based on Always Show
                if profile.spells[i].alwaysShow and profile.spells[i].spellID > 0 then
                    icons[i]:Show()
                elseif currentStacks[i] == 0 then
                    icons[i]:Show()
                else
                    icons[i]:Hide()
                end
            end
        end
        print("JarsCoolDown: Configuration saved!")
    end)
    saveButton:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, yOff)

    -- Lock/Unlock button
    local lockButton
    lockButton = CreateModernButton(content, profile.locked and "Unlock" or "Lock", 100, 28, function()
        profile.locked = not profile.locked
        lockButton:SetText(profile.locked and "Unlock" or "Lock")

        if iconContainer then
            if profile.locked then
                iconContainer:EnableMouse(false)
                iconContainer:SetMovable(false)
                iconContainer.background:SetColorTexture(0, 0, 0, 1)
            else
                iconContainer:EnableMouse(true)
                iconContainer:SetMovable(true)
                iconContainer.background:SetColorTexture(0.2, 0.5, 0.2, 1)
            end
        end
    end)
    lockButton:SetPoint("LEFT", saveButton, "RIGHT", 12, 0)

    -- Reset Position button
    local resetPosButton = CreateModernButton(content, "Reset Position", 120, 28, function()
        profile.position = nil
        if iconContainer then
            iconContainer:ClearAllPoints()
            iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        print("JarsCoolDown: Position reset to center")
    end)
    resetPosButton:SetPoint("LEFT", lockButton, "RIGHT", 12, 0)

    configFrame:Hide()
end

-- Create icons and handle events
f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

f:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "PLAYER_REGEN_DISABLED" then
        isInCombat = true
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        isInCombat = false
        return
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Spec changed, reload icons with new profile
        ReloadIcons()
        print("JarsCoolDown: Switched to " .. (select(2, GetSpecializationInfo(GetSpecialization() or 1))) .. " profile")
        return
    end
    
    local profile = GetCurrentProfile()
    
    if event == "PLAYER_ENTERING_WORLD" then
        if not configFrame then
            CreateConfigWindow()
        end
        
        if #icons == 0 then
            -- Get saved icon size
            local size = profile.iconSize or 64
            local spacing = size + 2
            local containerWidth = (spacing * 3) - 2
            local containerHeight = (spacing * 2) - 2
            local fontSize = math.max(12, math.floor(size * 0.75))
            
            -- Create icon container
            iconContainer = CreateFrame("Frame", nil, UIParent)
            iconContainer:SetSize(containerWidth, containerHeight)
            
            -- Restore saved position or center
            if profile.position and profile.position.point and profile.position.relativePoint then
                local success = pcall(function()
                    iconContainer:SetPoint(
                        profile.position.point,
                        UIParent,
                        profile.position.relativePoint,
                        profile.position.x,
                        profile.position.y
                    )
                end)
                if not success then
                    -- Invalid position, reset to center
                    profile.position = nil
                    iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            else
                iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
            
            -- Make draggable
            iconContainer:SetMovable(true)
            iconContainer:EnableMouse(not profile.locked)
            iconContainer:RegisterForDrag("LeftButton")
            iconContainer:SetScript("OnDragStart", function(self)
                if not profile.locked then
                    self:StartMoving()
                end
            end)
            iconContainer:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                -- Save position with anchor info
                local point, _, relativePoint, x, y = self:GetPoint()
                profile.position = {
                    point = point,
                    relativePoint = relativePoint,
                    x = x,
                    y = y
                }
            end)
            
            -- Add background
            iconContainer.background = iconContainer:CreateTexture(nil, "BACKGROUND")
            iconContainer.background:SetAllPoints()
            iconContainer.background:SetColorTexture(0, 0, 0, 1)
            iconContainer.background:SetAlpha(profile.bgOpacity or 0.8)
            
            -- Create 6 icons in 3x2 grid
            for i = 1, 6 do
                local icon = CreateFrame("Frame", nil, iconContainer)
                icon:SetSize(size, size)
                
                -- Position in 3x2 grid with 2px padding
                local row = math.floor((i - 1) / 3)
                local col = (i - 1) % 3
                icon:SetPoint("TOPLEFT", col * spacing, -row * spacing)
                
                -- Spell texture
                icon.texture = icon:CreateTexture(nil, "ARTWORK")
                icon.texture:SetAllPoints()
                icon.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                
                -- Cooldown text
                icon.text = icon:CreateFontString(nil, "OVERLAY")
                icon.text:SetPoint("CENTER")
                icon.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                icon.text:SetText("")
                
                -- Initialize stacks
                if profile.spells[i].stacks > 0 then
                    currentStacks[i] = profile.spells[i].stacks
                else
                    currentStacks[i] = 1
                end
                chargeCooldowns[i] = {}
                
                -- OnUpdate for countdown and stack display
                icon:SetScript("OnUpdate", function(self)
                    local maxStacks = profile.spells[i].stacks
                    local spell = profile.spells[i]
                    
                    -- Check if we should hide icons based on combat status
                    if profile.onlyInCombat and not isInCombat then
                        if iconContainer then
                            iconContainer:Hide()
                        end
                        return
                    else
                        if iconContainer and not iconContainer:IsShown() then
                            iconContainer:Show()
                        end
                    end
                    
                    -- Update cooldowns and restore stacks
                    if chargeCooldowns[i] and #chargeCooldowns[i] > 0 then
                        local now = GetTime()
                        local newCooldowns = {}
                        
                        for _, endTime in ipairs(chargeCooldowns[i]) do
                            if endTime > now then
                                table.insert(newCooldowns, endTime)
                            else
                                -- Cooldown expired, restore a stack
                                if maxStacks > 0 then
                                    currentStacks[i] = math.min(currentStacks[i] + 1, maxStacks)
                                else
                                    currentStacks[i] = 1
                                end
                            end
                        end
                        
                        chargeCooldowns[i] = newCooldowns
                    end
                    
                    -- Display logic
                    if currentStacks[i] == 0 then
                        -- No stacks available - show desaturated icon with shortest cooldown
                        self.texture:SetDesaturated(true)
                        
                        if #chargeCooldowns[i] > 0 then
                            local shortest = math.huge
                            for _, endTime in ipairs(chargeCooldowns[i]) do
                                local remaining = endTime - GetTime()
                                if remaining < shortest then
                                    shortest = remaining
                                end
                            end
                            
                            if shortest < math.huge and shortest > 0 then
                                self.text:SetText(string.format("%.1f", shortest))
                            else
                                self.text:SetText("")
                                -- Edge case: cooldown just expired
                                self.texture:SetDesaturated(false)
                            end
                        else
                            self.text:SetText("")
                            -- No cooldowns left, restore color
                            self.texture:SetDesaturated(false)
                        end
                        
                        self:Show()
                    elseif currentStacks[i] > 0 then
                        -- Stacks available - show in color with stack count
                        self.texture:SetDesaturated(false)
                        
                        if maxStacks > 0 then
                            self.text:SetText(tostring(currentStacks[i]))
                        else
                            self.text:SetText("")
                        end
                        
                        -- Show/hide based on Always Show
                        if spell.alwaysShow and spell.spellID > 0 then
                            self:Show()
                        else
                            self:Hide()
                        end
                    end
                end)
                
                -- Set initial texture and visibility
                local texture = C_Spell.GetSpellTexture(profile.spells[i].spellID)
                if texture then
                    icon.texture:SetTexture(texture)
                end
                
                if profile.spells[i].alwaysShow and profile.spells[i].spellID > 0 then
                    icon:Show()
                else
                    icon:Hide()
                end
                
                icons[i] = icon
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Check if this spell matches any configured spell
        for i = 1, 6 do
            local spell = profile.spells[i]
            local maxStacks = spell.stacks > 0 and spell.stacks or 1
            
            -- Check if it's a main spell cast
            if spell.spellID == spellID and spell.cooldown > 0 then
                -- Subtract a stack
                if currentStacks[i] > 0 then
                    currentStacks[i] = currentStacks[i] - 1
                end
                
                -- Add cooldown timer sequentially (not parallel)
                local startTime = GetTime()
                
                -- If there are existing cooldowns, queue after the last one
                if #chargeCooldowns[i] > 0 then
                    local latestEnd = 0
                    for _, endTime in ipairs(chargeCooldowns[i]) do
                        if endTime > latestEnd then
                            latestEnd = endTime
                        end
                    end
                    startTime = latestEnd
                end
                
                -- Apply haste reduction if checkbox is enabled
                local adjustedCooldown = spell.cooldown
                if spell.haste then
                    local hastePercent = UnitSpellHaste("player")
                    adjustedCooldown = spell.cooldown / (1 + (hastePercent / 100))
                end
                
                table.insert(chargeCooldowns[i], startTime + adjustedCooldown)
                
                if icons[i] then
                    icons[i]:Show()
                end
            end
            
            -- Check if it's a reset spell cast
            if spell.resetID == spellID and spell.resetID > 0 then
                -- Clear all cooldowns and restore full stacks
                chargeCooldowns[i] = {}
                currentStacks[i] = maxStacks
                
                if icons[i] then
                    icons[i].texture:SetDesaturated(false)
                    
                    -- Show/hide based on Always Show
                    if spell.alwaysShow and spell.spellID > 0 then
                        icons[i]:Show()
                    else
                        icons[i]:Hide()
                    end
                end
            end
        end
    end
end)

-- Slash command
SLASH_JCD1 = "/jcd"
SLASH_JCD2 = "/jarscooldown"
SlashCmdList["JCD"] = function(msg)
    msg = msg:lower():trim()
    local profile = GetCurrentProfile()
    
    if msg == "reset" then
        -- Force reset position
        profile.position = nil
        if iconContainer then
            iconContainer:ClearAllPoints()
            iconContainer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            iconContainer:Show()
        end
        print("JarsCoolDown: Position reset and frame shown")
    elseif msg == "show" then
        -- Force show the icon container
        if iconContainer then
            iconContainer:Show()
            print("JarsCoolDown: Frame shown")
        else
            print("JarsCoolDown: Frame not created yet")
        end
    else
        -- Toggle config window
        if configFrame then
            if configFrame:IsShown() then
                configFrame:Hide()
            else
                configFrame:Show()
            end
        end
    end
end

