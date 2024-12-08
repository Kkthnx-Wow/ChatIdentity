local _, namespace = ...

local string_format = string.format
local string_lower = string.lower
local tostring = tostring

local GetGuildRosterInfo = GetGuildRosterInfo
local GetNumGuildMembers = GetNumGuildMembers
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local UnitClass = UnitClass
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitRace = UnitRace
local UnitSex = UnitSex

-- Static table to store member data (race, gender, class, and level)
local memberData = {}
local debugMode = true
local lastGuildRosterUpdate = 0

-- Create localized class mappings
local localizedClassMap = {}

if namespace:IsRetail() then
	-- Retail: Use LocalizedClassList
	local maleClassList = LocalizedClassList(false) -- Male class names
	local femaleClassList = LocalizedClassList(true) -- Female class names

	-- Map male class names to classFile
	for classFile, localizedName in pairs(maleClassList) do
		localizedClassMap[localizedName] = classFile
	end

	-- Map female class names to classFile
	for classFile, localizedName in pairs(femaleClassList) do
		localizedClassMap[localizedName] = classFile
	end
else
	-- Classic: Use FillLocalizedClassList
	local maleClassList = {}
	local femaleClassList = {}

	-- Populate male and female class lists
	FillLocalizedClassList(maleClassList, false) -- Male class names
	FillLocalizedClassList(femaleClassList, true) -- Female class names

	-- Map male class names to classFile
	for classFile, localizedName in pairs(maleClassList) do
		localizedClassMap[localizedName] = classFile
	end

	-- Map female class names to classFile
	for classFile, localizedName in pairs(femaleClassList) do
		localizedClassMap[localizedName] = classFile
	end
end

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
	["highmountain tauren"] = "highmountain",
	["lightforged draenei"] = "lightforged",
	["zandalari troll"] = "zandalari",
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

	DebugPrint("Raw race input: " .. race)

	local sanitizedRace = raceAtlasMap[string_lower(race)] or string_lower(race):gsub("[%s%-']", "")
	DebugPrint("Sanitized race: " .. sanitizedRace)

	local genderString = (gender == 2) and "male" or (gender == 3) and "female"
	local atlasName = "raceicon-" .. sanitizedRace .. "-" .. genderString
	DebugPrint("Generated atlas name: " .. atlasName)

	local iconSize = GetOption("iconSize") or 18
	if not C_Texture.GetAtlasInfo(atlasName) then
		DebugPrint("Atlas not found for: " .. atlasName .. ", using fallback.")
		return "|TInterface\\Icons\\INV_Misc_QuestionMark:" .. iconSize .. "|t"
	end

	DebugPrint("Atlas found: " .. atlasName)
	return CreateAtlasMarkup(atlasName, iconSize, iconSize)
end

-- Function to dynamically generate class icons
local function GetClassIcon(classFilename)
	if not GetOption("enableClassIcon") then
		DebugPrint("Class icons are disabled in options.")
		return nil
	end

	if not classFilename or classFilename == "" then
		DebugPrint("Missing or invalid class filename for icon generation.")
		return nil
	end

	local normalizedClass = localizedClassMap[classFilename] or string.upper(classFilename)
	DebugPrint("Normalized class: " .. tostring(normalizedClass))

	local iconSize = GetOption("iconSize") or 18
	local texturePath = string.format("Interface\\Icons\\ClassIcon_%s", normalizedClass)
	DebugPrint("Attempting to use texture: " .. texturePath)

	return string.format("|T%s:%d|t", texturePath, iconSize)
end

-- Generate difficulty color for levels
local function GetLevelColor(level)
	if not level or level < 1 then
		return "|cff808080"
	end
	local color = GetQuestDifficultyColor(level)
	return string_format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end

-- Generate level string with difficulty color
local function GetLevelString(playerLevel, targetLevel)
	DebugPrint("GetLevelString: Entered function")
	local showLevel = GetOption("showLevel")
	if not showLevel then
		DebugPrint("GetLevelString: showLevel is disabled, returning nil")
		return nil
	end

	local onlyShowLevelDifference = GetOption("onlyShowLevelDifference")
	DebugPrint("GetLevelString: onlyShowLevelDifference is " .. tostring(onlyShowLevelDifference))

	if onlyShowLevelDifference and playerLevel == targetLevel then
		DebugPrint("GetLevelString: Player and target level are the same, skipping level display")
		-- Fallback to display level regardless when showLevel is true
		return GetLevelColor(targetLevel) .. "[" .. targetLevel .. "]|r"
	end

	local levelString = GetLevelColor(targetLevel) .. "[" .. targetLevel .. "]|r"
	DebugPrint("GetLevelString: Generated level string: " .. levelString)
	return levelString
end

-- Utility function to split strings
local function SplitString(input, delimiter)
	if not input or not delimiter then
		DebugPrint("Invalid input or delimiter for SplitString")
		return {}
	end

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
	if not sender then
		DebugPrint("DetectPlayerData skipped: Sender is nil.")
		return
	end

	namespace:Defer(function()
		local playerName = Ambiguate(sender, "short")
		if not playerName or playerName == "" then
			DebugPrint("DetectPlayerData skipped: Invalid playerName after Ambiguate.")
			return
		end

		if memberData[playerName] then
			DebugPrint("Skipping detection: Data already exists for " .. playerName)
			return
		end

		local unitIds = { "player", "party1", "party2", "party3", "party4", "target", "focus", "mouseover" }
		for _, unitId in ipairs(unitIds) do
			if UnitExists(unitId) and UnitName(unitId) == playerName then
				local race = UnitRace(unitId)
				local _, classFilename = UnitClass(unitId) -- Get locale-independent class name
				local level = UnitLevel(unitId)
				local sex = UnitSex(unitId)

				if race and sex and classFilename and level then
					memberData[playerName] = {
						race = race,
						class = string.upper(classFilename), -- Always use upper-case classFilename
						level = level,
						sex = sex,
					}
					DebugPrint("Detected player data: " .. playerName .. " - Race: " .. race .. ", Class: " .. string.upper(classFilename) .. ", Level: " .. level)
				else
					DebugPrint("Incomplete player data for " .. playerName .. ". Race: " .. tostring(race) .. ", Class: " .. tostring(classFilename) .. ", Level: " .. tostring(level) .. ", Sex: " .. tostring(sex))
				end
				return
			end
		end

		DebugPrint("No unit data found for: " .. playerName)
	end)
end

-- Add race icon, class icon, and level to chat messages
local function AddRaceIconToChat(_, _, message, sender, ...)
	if not sender then
		DebugPrint("AddRaceIconToChat: Sender is nil, skipping.")
		return false, message, sender, ...
	end

	DebugPrint("AddRaceIconToChat: Processing message from sender: " .. tostring(sender))

	local playerName = Ambiguate(sender, "short")
	if not playerName or playerName == "" then
		DebugPrint("AddRaceIconToChat: Invalid playerName after Ambiguate, skipping.")
		return false, message, sender, ...
	end

	local playerData = memberData[playerName]
	if not playerData then
		DebugPrint("AddRaceIconToChat: No player data found for sender: " .. sender)
		return false, message, sender, ...
	end

	DebugPrint(string.format("AddRaceIconToChat: Player data found - Race: %s, Class: %s, Level: %s", playerData.race or "Unknown", playerData.class or "Unknown", playerData.level or "Unknown"))

	-- Generate icons and level string
	local raceIcon = GetRaceIcon(playerData.race, playerData.sex)
	local classIcon = GetClassIcon(playerData.class)
	local playerLevel = UnitLevel("player") -- Use current player's level to compare
	local levelString = GetLevelString(playerLevel, playerData.level)

	-- Debugging the generated icons and level string
	DebugPrint(string.format("AddRaceIconToChat: Generated icons - Race Icon: %s, Class Icon: %s, Level String: %s", raceIcon or "None", classIcon or "None", levelString or "None"))

	-- Build the message prefix according to the display order
	local prefixParts = {}
	local displayOrder = SplitString(GetOption("displayOrder"), ",")
	DebugPrint("AddRaceIconToChat: Display order: " .. table.concat(displayOrder, ", "))

	for _, element in ipairs(displayOrder) do
		if element == "race" and raceIcon then
			table.insert(prefixParts, raceIcon)
		elseif element == "class" and classIcon then
			table.insert(prefixParts, classIcon)
		elseif element == "level" then
			if levelString then
				DebugPrint("AddRaceIconToChat: Adding level string to prefix: " .. levelString)
				table.insert(prefixParts, levelString)
			else
				DebugPrint("AddRaceIconToChat: Level string is nil, skipping.")
			end
		end
	end

	-- Combine prefix and original message
	local prefix = table.concat(prefixParts, " ")
	local modifiedMessage = prefix .. " " .. message

	DebugPrint("AddRaceIconToChat: Final modified message: " .. modifiedMessage)
	return false, modifiedMessage, sender, ...
end

namespace:RegisterEvent("ADDON_LOADED", function(_, addonName)
	if addonName == "ChatIdentity" then
		DebugPrint("ADDON_LOADED fired for ChatIdentity. Initializing addon.")
		InitializePlayerData()

		if IsInGuild() then
			DebugPrint("Player is in a guild. Requesting guild roster update.")
			C_GuildInfo.GuildRoster()
		else
			DebugPrint("Player is not in a guild. Skipping guild roster request.")
		end

		if GetOption and GetOption("showWelcomeMessage") then
			local playerName = UnitName("player")
			local playerClass, classFileName = UnitClass("player")
			local playerRace = UnitRace("player")
			local playerSex = UnitSex("player")
			local raceIcon = GetRaceIcon(playerRace, playerSex) or ""
			local classIcon = GetClassIcon(playerClass) or ""
			local classColor = RAID_CLASS_COLORS[classFileName]
			local classColorCode = string.format("|cff%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
			local version = C_AddOns.GetAddOnMetadata("ChatIdentity", "Version") or "Unknown Version"
			local versionColor = "|cffffd700"

			namespace:Print(string.format("%sv%s|r loaded! Welcome, %s%s|r %s %s.\nType %s/chatidentity%s or %s/ci%s for options.", versionColor, version, classColorCode, playerName, raceIcon, classIcon, "|cff00ff00", "|r", "|cff00ff00", "|r"))
		else
			DebugPrint("Welcome message is disabled.")
		end

		DebugPrint("Localized class map initialized:")
		for localizedName, classFile in pairs(localizedClassMap) do
			DebugPrint(localizedName .. " -> " .. classFile)
		end

		-- Unregister ADDON_LOADED to avoid unnecessary calls
		namespace:UnregisterEvent("ADDON_LOADED", namespace.ADDON_LOADED)
		DebugPrint("ADDON_LOADED event unregistered.")
	end
end)

namespace:RegisterEvent("CHAT_MSG_GUILD", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_PARTY", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_PARTY_LEADER", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_INSTANCE_CHAT", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)

namespace:RegisterEvent("GUILD_ROSTER_UPDATE", function()
	namespace:Defer(function()
		if not IsInGuild() then
			DebugPrint("Player is not in a guild. Exiting GUILD_ROSTER_UPDATE handler.")
			return
		end

		local now = GetTime()
		if now - lastGuildRosterUpdate >= 10 then
			C_GuildInfo.GuildRoster()
			lastGuildRosterUpdate = now

			local numTotalGuildMembers, numOnlineGuildMembers = GetNumGuildMembers()
			DebugPrint(string_format("Guild Roster: Total Members = %d, Online Members = %d", numTotalGuildMembers, numOnlineGuildMembers))

			if numOnlineGuildMembers == 1 then
				local firstOnlineMemberName = Ambiguate(GetGuildRosterInfo(1), "short") -- Assuming the first member is the player
				if firstOnlineMemberName == UnitName("player") then
					DebugPrint("Player is the only guild member online. Exiting GUILD_ROSTER_UPDATE handler.")
					return
				end
			end

			for i = 1, numTotalGuildMembers do
				local fullName, _, _, level, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
				local playerName = Ambiguate(fullName, "short") -- Strip realm name

				if guid then
					local localizedClass, _, localizedRace, _, sex = GetPlayerInfoByGUID(guid)
					if localizedRace and sex then
						memberData[playerName] = {
							race = localizedRace,
							class = localizedClass,
							level = level,
							sex = sex,
						}
						-- DebugPrint(string_format("Guild member: %s - Race: %s - Class: %s - Level: %s - Gender: %s", playerName, localizedRace, localizedClass, level, (sex == 2 and "Male" or "Female")))
					else
						DebugPrint("Failed to retrieve race or gender for GUID: " .. guid)
					end
				else
					DebugPrint("Missing GUID for guild member: " .. tostring(playerName))
				end
			end
		end
	end)
end)

namespace:RegisterEvent("UNIT_LEVEL", function(_, unit)
	if unit == "player" then
		DebugPrint("UNIT_LEVEL ignored for player: " .. tostring(UnitName(unit)))
		return
	end

	if not UnitInParty(unit) then
		DebugPrint("UNIT_LEVEL ignored for unit not in party: " .. tostring(UnitName(unit)))
		return
	end

	namespace:Defer(function()
		local name = UnitName(unit)
		local level = UnitLevel(unit)

		if name and level then
			DebugPrint("UNIT_LEVEL fired for party member: " .. name .. ", Level: " .. level)
			if memberData[name] and memberData[name].level ~= level then
				memberData[name].level = level
				DebugPrint("Updated level for " .. name .. ": " .. level)
			else
				DebugPrint("No changes required for " .. name)
			end
		else
			DebugPrint("UNIT_LEVEL fired but no valid name or level for unit.")
		end
	end)
end)

namespace:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
	DebugPrint(string.format("PLAYER_LEVEL_UP fired! New Level: %d", level))
	local playerName = UnitName("player")
	if memberData[playerName] then
		memberData[playerName].level = level
		DebugPrint("Updated player's level: " .. playerName .. " to Level: " .. level)
	else
		DebugPrint("Player data not found in memberData; initializing.")
		memberData[playerName] = {
			race = UnitRace("player"),
			class = UnitClass("player"),
			level = level,
			sex = UnitSex("player"),
		}
	end

	-- Ensure all updates propagate immediately
	DebugPrint("Force-syncing level in memberData with UnitLevel('player')")
	memberData[playerName].level = UnitLevel("player")
end)

-- Handle PLAYER_LEVEL_CHANGED
namespace:RegisterEvent("PLAYER_LEVEL_CHANGED", function(_, oldLevel, newLevel)
	local playerName = UnitName("player")
	if memberData[playerName] then
		if memberData[playerName].level ~= newLevel then
			memberData[playerName].level = newLevel
			DebugPrint(string.format("PLAYER_LEVEL_CHANGED: Updated %s's level from %d to %d", playerName, oldLevel, newLevel))
		else
			DebugPrint("PLAYER_LEVEL_CHANGED: No change needed for " .. playerName)
		end
	else
		DebugPrint("PLAYER_LEVEL_CHANGED: Initializing player data.")
		memberData[playerName] = {
			race = UnitRace("player"),
			class = UnitClass("player"),
			level = newLevel,
			sex = UnitSex("player"),
		}
	end

	-- Force consistency with current `UnitLevel("player")`
	memberData[playerName].level = UnitLevel("player")
end)

namespace:RegisterEvent("GROUP_ROSTER_UPDATE", function()
	namespace:Defer(function()
		if not IsInGroup() or IsInRaid() then
			DebugPrint("Player is either not in a group or is in a raid. Exiting GROUP_ROSTER_UPDATE handler.")
			return
		end

		DebugPrint("Group roster updated")
		local numGroupMembers = GetNumGroupMembers()
		for i = 1, numGroupMembers do
			local unit = "party" .. i
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
end)

ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", AddRaceIconToChat)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", AddRaceIconToChat)

namespace:RegisterEvent("CHAT_MSG_SAY", function(_, ...)
	local _, sender = ...
	DetectPlayerData(Ambiguate(sender, "short"))
end)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", AddRaceIconToChat)
