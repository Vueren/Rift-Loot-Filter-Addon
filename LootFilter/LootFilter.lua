-- Prints all the commands that can be used
local function printCommands()
    print("Loot Filter:")
    print("- /lf select <rift|scroll|grey|dimension|non70>")
    print("- /lf help - gives details on filters.")
    print("- /lf clear - clears selected items.")
    print("- /lf delete - deletes selected items.")
end

-- Prints all the filters that can be used
local function printHelp()
    print("- rift: Rift consumables can be seen in the /Consumables/Rift Consumable tab of the AH.")
    print("- scroll: Scrolls can be seen in the /Consumables/Scroll tab of the AH.")
    print("- grey: Grey items have rarity of grey. As these items can often add up to sell for a lot of plat on the Rift Store, it is recommended to not use this filter.")
    print("- dimension: Dimension items do not include Dimension Keys nor Kits and Bundles.")
    print("- non70: Non 70 items include all weapons, armor, and essences that are not Lv70.")
end

-- Formats a single number into its Platinum, Gold, Silver value.
-- Example: 80801 = 8p8g1s
local function formatSilver(silver)
    if(silver < 100) then
        return tostring(silver) .. 's'
    elseif(silver < 10000) then
        g = math.floor(silver / 100)
        s = silver - (g * 100)
        return tostring(g) .. 'g' .. tostring(s) .. 's'
    elseif(silver >= 10000) then
        p = math.floor(silver / 10000)
        gold = (silver - (p * 10000))
        g = math.floor(gold / 100)
        s = gold - (g * 100)
        return tostring(p) .. 'p' .. tostring(g) .. 'g' .. tostring(s) .. 's'
    end
end

local function startswith(str, start)
    return str:sub(1, #start) == start
end

local lootFilterItems = {}

local function addFilteredInventoryItems(filter)
    for ikey,ival in pairs(Inspect.Item.List()) do
        -- Only applies to items in your inventory, NOT the banks / etc.
        -- Does not apply to empty inventory slots.
        if(ival ~= false and Utility.Item.Slot.Parse(ikey) == 'inventory') then 
            idetail = Inspect.Item.Detail(ikey) -- Get the current item details.
            if(
                idetail.bound == nil -- All items destroyed must be tradable.
                and (
                (filter == 'rift' -- /lf select rift
                    and idetail.category == 'consumable consumable' ) -- Gets consumable items. May pick up items you don't want destroyed, CHECK TO MAKE SURE!!! (Example: Crafting Rifts. These are not tradable, and so will NOT be destroyed, but it's good to make sure!!!)
                or (filter == 'scroll' -- /lf select scroll
                        and idetail.category == 'consumable scroll') -- Gets scrolls. Just remember to check the items found in case Rift decides to call something *REALLY STUPID* a scroll.
                or ((filter == 'grey' or filter == 'gray') -- /lf select grey or /lf select gray
                        and idetail.rarity == 'sellable') -- "sellable" is the grey tier in the API.
                or (filter == 'dimension' -- /lf select dimension
                        and startswith(idetail.category, 'dimension') -- Lots of possible dimension categories, capture all of them
                        and idetail.category ~= 'dimension key' -- Except keys. Add a -- to the start of this line to include keys.
                        and idetail.category ~= 'dimension container' -- Except containers. Add a -- to the start of this line to include containers.
                    )
                or (filter == 'non70' -- /lf select non70
                        and (startswith(idetail.category, 'weapon') -- Selects weapons
                            or startswith(idetail.category, 'armor') -- Selects armor
                            or startswith(idetail.category, 'planar')) -- Selects essences
                        and idetail.requiredLevel ~= 70) -- Makes sure they're all *NOT* Lv70
                )
            ) then
                print("Item Selected: " .. 
                    idetail.name .. -- Show name
                    (idetail.stack and " x " .. idetail.stack .. -- Show stack count if item is stackable
                        (idetail.sell and ' (' .. formatSilver(idetail.sell * idetail.stack) .. ')' or "") -- Show price for selling stack if item can be sold if item is stackable
                        or (idetail.sell and ' (' .. formatSilver(idetail.sell) .. ')' or "") -- Show price for selling if item can be sold if item is not stackable
                    ) -- End stacking and pricing logic
                    ) -- End print
                -- Add item to filtered items list
                table.insert(lootFilterItems, idetail.id)
            end
        end
    end
end

local function slashHandler(params)
    local args = string.split(string.trim(params), "%s+", true)
    local arg1, arg2 = unpack(args)
    if(#args <= 0) then
        printHelp()
    elseif(#args == 1 and arg1 ~= nil) then
        if(string.lower(arg1) == "delete") then
            -- delete items selected by selectItems
            if(#lootFilterItems ~= 0) then
                for k,item in pairs(lootFilterItems) do
                    Command.Item.Destroy(item)
                end
                print('All items deleted. Please note that, as we tell you what items are being selected as you apply filters, we are not responsible for any item loss.')
                -- clears selected items from Addon after deletion.
                lootFilterItems = {}
            else
                print("WARNING: No items selected with /lf select _! Use /lf help to see selection options. No actions performed.")
            end
        elseif(string.lower(arg1) == "clear") then
            -- clears selected items
            lootFilterItems = {}
            print("All items selected removed from the list of items to delete.")
        elseif(string.lower(arg1) == "help") then
            printHelp()
        else
            print("ERROR: Command not found!")
            printCommands()
        end
    elseif(#args == 2 and arg1 ~= nil and arg2 ~= nil) then
        if(string.lower(arg1) == "select") then
            -- select items
            addFilteredInventoryItems(string.lower(arg2))
        else
            print("ERROR: Command not found!")
            printCommands()
        end
    else
        print("ERROR: Command not found!")
        printCommands()
    end
end

table.insert(Command.Slash.Register("lf"), {function (params)
        slashHandler(params)
    end,
    "LootFilter", -- Addon name
    "Loot Filter Slash Commands" -- Just random text so something knows who the heck you are and why
})
