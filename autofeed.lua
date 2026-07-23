local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Event = game:GetService("ReplicatedStorage").Remotes.Server

local groups = {}
local nameList = {}

local function buildLabel(name)
    return string.format("%s  (x%d)", name, groups[name].count)
end

local function labelToName(label)
    return (label:gsub("%s*%(x%d+%)$", ""))
end

local function getAllLabels()
    local labels = {}
    for _, name in ipairs(nameList) do
        table.insert(labels, buildLabel(name))
    end
    return labels
end

local function filterLabels(keyword)
    keyword = keyword:lower()
    local labels = {}
    for _, name in ipairs(nameList) do
        if keyword == "" or name:lower():find(keyword, 1, true) then
            table.insert(labels, buildLabel(name))
        end
    end
    return labels
end

-- ============================
-- FETCH UNITS DATA FROM SERVER
-- ============================
local function loadUnitsData()
    local units = Event:InvokeServer("Data", "Units")

    groups = {}
    nameList = {}

    for _, u in ipairs(units) do
        local name = u.Name
        if not groups[name] then
            groups[name] = { count = 0, list = {} }
            table.insert(nameList, name)
        end
        groups[name].count = groups[name].count + 1
        table.insert(groups[name].list, u)
    end

    table.sort(nameList, function(a, b) return groups[a].count > groups[b].count end)
end

loadUnitsData()

-- ============================
-- FEED FUNCTION
-- ============================
local function feedByNames(targetName, fodderNames)
    local targetGroup = groups[targetName]
    if not targetGroup or #targetGroup.list == 0 then
        Rayfield:Notify({ Title = "Error", Content = "Target unit not found", Duration = 3 })
        return false
    end

    local targetUnit = targetGroup.list[1]

    local jsonTarget = string.format(
        '{"ID":%d,"Level":%d,"Name":"%s"}',
        targetUnit.ID, targetUnit.Level, targetUnit.Name
    )

    local fodderIDs = {}
    for _, fname in ipairs(fodderNames) do
        local g = groups[fname]
        if g then
            for i, u in ipairs(g.list) do
                if not (fname == targetName and i == 1) then
                    table.insert(fodderIDs, u.ID)
                end
            end
        end
    end

    if #fodderIDs == 0 then
        Rayfield:Notify({ Title = "Error", Content = "Fodder list is empty", Duration = 3 })
        return false
    end

    local success, result = pcall(function()
        return Event:InvokeServer("Trash", fodderIDs, jsonTarget, true)
    end)

    if success then
        Rayfield:Notify({
            Title = "Feed Successful",
            Content = string.format("Fed %d unit(s) into %s", #fodderIDs, targetUnit.Name),
            Duration = 4,
        })
        return true
    else
        Rayfield:Notify({
            Title = "Feed Failed",
            Content = tostring(result),
            Duration = 5,
        })
        return false
    end
end

local Window = Rayfield:CreateWindow({
    Name = "Unit Manager",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = { Enabled = false },
})

local FeedTab = Window:CreateTab("Feed Unit", 4483362458)

local selectedTargetName = nil
local selectedFodderNames = {}

local TargetDropdown = FeedTab:CreateDropdown({
    Name = "Select Main Unit (receives EXP)",
    Options = getAllLabels(),
    CurrentOption = { },
    MultipleOptions = false,
    Flag = "TargetUnitDropdown",
    Callback = function(option)
        pcall(function()
            if type(option) == "table" and type(option[1]) == "string" then
                selectedTargetName = labelToName(option[1])
            end
        end)
    end,
})

FeedTab:CreateInput({
    Name = "Search Main Unit",
    PlaceholderText = "Type a name to filter...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        TargetDropdown:Refresh(filterLabels(text), false)
    end,
})

local FodderDropdown = FeedTab:CreateDropdown({
    Name = "Select Fodder Units (feeds all duplicates of the chosen name)",
    Options = getAllLabels(),
    CurrentOption = { },
    MultipleOptions = true,
    Flag = "FodderUnitDropdown",
    Callback = function(options)
        local names = {}

        pcall(function()
            if type(options) == "table" then
                if options[1] ~= nil then
                    for _, label in ipairs(options) do
                        if type(label) == "string" then
                            table.insert(names, labelToName(label))
                        end
                    end
                else
                    for label, isSelected in pairs(options) do
                        if isSelected and type(label) == "string" then
                            table.insert(names, labelToName(label))
                        end
                    end
                end
            end
        end)

        selectedFodderNames = names
    end,
})

FeedTab:CreateInput({
    Name = "Search Fodder Unit",
    PlaceholderText = "Type a name to filter...",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        FodderDropdown:Refresh(filterLabels(text), false)
    end,
})

-- ============================
-- RESET / REFRESH BOTH DROPDOWNS AFTER FEED
-- ============================
local function refreshDropdowns()
    loadUnitsData()
    TargetDropdown:Refresh(getAllLabels(), true)
    FodderDropdown:Refresh(getAllLabels(), true)

    selectedTargetName = nil
    selectedFodderNames = {}
end

FeedTab:CreateButton({
    Name = "FEED NOW",
    Callback = function()
        if not selectedTargetName then
            Rayfield:Notify({ Title = "Error", Content = "No main unit selected", Duration = 3 })
            return
        end
        if #selectedFodderNames == 0 then
            Rayfield:Notify({ Title = "Error", Content = "No fodder units selected", Duration = 3 })
            return
        end

        local ok = feedByNames(selectedTargetName, selectedFodderNames)

        if ok then
            task.wait(1) -- wait for server to process
            refreshDropdowns()
        end
    end,
})

FeedTab:CreateButton({
    Name = "Refresh List Manually",
    Callback = function()
        refreshDropdowns()
        Rayfield:Notify({ Title = "Refreshed", Content = "Unit list has been updated", Duration = 3 })
    end,
})
