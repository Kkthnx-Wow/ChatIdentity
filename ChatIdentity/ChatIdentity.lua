local _, namespace = ...

-- Static table to store member data (race, gender, class, and level)
local memberData = {}
local debugMode = false
local lastGuildRosterUpdate = 0

-- Access settings dynamically
local function GetOption(optionKey)
	return namespace:GetOption(optionKey)
end

-- Debugging function
local function DebugPrint(msg)
	if debugMode then
		namespace:Print(msg)
	end
end

-- Mapping for special race names
local raceAtlasMap = {
	["zandalaritroll"] = "zandalari",
}

-- Function to dynamically generate race icons using Atlas
local function GetRaceIcon(race, gender)
	if not GetOption("enableRaceIcon") then
		return nil
	end
	if not race or not gender then
		DebugPrint("Missing race or gender for atlas icon generation")
		return nil
	end

	local sanitizedRace = raceAtlasMap[string.lower(race)] or string.gsub(string.lower(race), "%s+", "")
	local genderString = (gender == 2) and "male" or (gender == 3) and "female"
	local atlasName = "raceicon-" .. sanitizedRace .. "-" .. genderString

	local iconSize = GetOption("iconSize") or 18

	if not C_Texture.GetAtlasInfo(atlasName) then
		DebugPrint("Atlas not found for: " .. atlasName .. ", using fallback.")
		return "|TInterface\\Icons\\INV_Misc_QuestionMark:" .. iconSize .. "|t"
	end

	return CreateAtlasMarkup(atlasName, iconSize, iconSize)
end

-- Function to dynamically generate class icons
local function GetClassIcon(class)
	if not GetOption("enableClassIcon") then
		return nil
	end
	local sanitizedClass = string.gsub(string.lower(class), "%s+", "")
	local iconSize = GetOption("iconSize") or 18
	return "|TInterface\\Icons\\ClassIcon_" .. sanitizedClass .. ":" .. iconSize .. "|t"
end

-- Generate difficulty color for levels
local function GetLevelColor(level)
	local color = GetQuestDifficultyColor(level)
	return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

-- Generate level string with difficulty color
local function GetLevelString(playerLevel, targetLevel)
	if not GetOption("showLevel") then
		return nil
	end
	if GetOption("onlyShowLevelDifference") and playerLevel == targetLevel then
		return nil
	end
	return GetLevelColor(targetLevel) .. "[" .. targetLevel .. "]|r"
end

-- Utility function to split strings
local function SplitString(input, delimiter)
	local result = {}
	for match in (input .. delimiter):gmatch("(.-)" .. delimiter) do
		table.insert(result, match)
	end
	return result
end

-- Initialize player's own data on login
local function InitializePlayerData()
	local playerRace = UnitRace("player")
	local playerClass = UnitClass("player")
	local playerLevel = UnitLevel("player")
	local playerSex = UnitSex("player")
	local playerName = UnitName("player")

	if playerRace and playerSex and playerClass and playerLevel and playerName then
		memberData[playerName] = { race = playerRace, class = playerClass, level = playerLevel, sex = playerSex }
		DebugPrint("Player data initialized: " .. playerName .. " - " .. playerRace .. " - " .. playerClass .. " - Level " .. playerLevel)
	end
end

-- Detect race, gender, class, and level from visible units
local function DetectPlayerData(sender)
	if not sender or memberData[sender] then
		return
	end

	local unitIds = { "player", "party1", "party2", "party3", "party4", "target", "focus", "mouseover" }
	for _, unitId in ipairs(unitIds) do
		if UnitExists(unitId) and UnitName(unitId) == sender then
			local race = UnitRace(unitId)
			local class = UnitClass(unitId)
			local level = UnitLevel(unitId)
			local sex = UnitSex(unitId)

			if race and sex and class and level then
				memberData[sender] = { race = race, class = class, level = level, sex = sex }
				DebugPrint("Detected " .. sender .. "'s race, gender, class, and level: " .. race .. " - " .. class .. " - Level " .. level)
				return
			end
		end
	end
end

-- Add race icon, class icon, and level to chat messages
local function AddRaceIconToChat(_, _, message, sender, ...)
	local playerName = Ambiguate(sender, "short")
	local playerData = memberData[playerName]

	if playerData then
		local raceIcon = GetRaceIcon(playerData.race, playerData.sex)
		local classIcon = GetClassIcon(playerData.class)
		local levelString = GetLevelString(UnitLevel("player"), playerData.level)

		local prefix = ""
		local order = SplitString(GetOption("displayOrder"), ",")
		for _, element in ipairs(order) do
			if element == "race" and raceIcon then
				prefix = prefix .. raceIcon .. " "
			elseif element == "class" and classIcon then
				prefix = prefix .. classIcon .. " "
			elseif element == "level" and levelString then
				prefix = prefix .. levelString .. " "
			end
		end

		local modifiedMessage = prefix .. message
		return false, modifiedMessage, sender, ...
	else
		DebugPrint("No data found for " .. playerName)
	end

	return false, message, sender, ...
end

namespace:RegisterEvent("PLAYER_LOGIN", function()
	InitializePlayerData()
end)

namespace:RegisterEvent("CHAT_MSG_GUILD", function(event, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_PARTY", function(event, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_PARTY_LEADER", function(event, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_INSTANCE_CHAT", function(event, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", function(event, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("GUILD_ROSTER_UPDATE", function()
	local now = GetTime()
	if now - lastGuildRosterUpdate >= 10 then
		C_GuildInfo.GuildRoster()
		lastGuildRosterUpdate = now
		DebugPrint("Guild roster updated.")
	end
end)

namespace:RegisterEvent("UNIT_LEVEL", function(event, unit)
	if UnitInParty(unit) or UnitInRaid(unit) then
		local name = UnitName(unit)
		local level = UnitLevel(unit)
		if memberData[name] and memberData[name].level ~= level then
			memberData[name].level = level
			DebugPrint("Updated level for " .. name .. ": " .. level)
		end
	end
end)

namespace:RegisterEvent("GROUP_ROSTER_UPDATE", function()
	DebugPrint("Group roster updated")
	local numGroupMembers = GetNumGroupMembers()
	for i = 1, numGroupMembers do
		local unit = IsInRaid() and "raid" .. i or "party" .. i
		if UnitExists(unit) then
			local name = UnitName(unit)
			local race = UnitRace(unit)
			local class = UnitClass(unit)
			local level = UnitLevel(unit)
			local sex = UnitSex(unit)

			if name and race and class and level and sex then
				memberData[name] = { race = race, class = class, level = level, sex = sex }
				DebugPrint("Updated data for group member: " .. name)
			end
		end
	end
end)

ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", AddRaceIconToChat)
