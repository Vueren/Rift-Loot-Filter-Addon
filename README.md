# NOTE! THIS ADDON IS IN BETA DEVELOPMENT

## Loot Filter

You want to delete useless items? Great, me too.

I wrote an addon that'll allow you to select them, and then automatically delete them whenever they end up back in your inventory.

Each Loot Filter is *PER CHARACTER*.

## AGAIN! BEEETAAAAAA

Type /lf to open the Loot Filter!

Select an item by left clicking it. See all identical items in other slots in the inventory gain a yellow border.

Use the Display Only Selected Items checkbox to see what should be getting deleted if you enable the deletion functionality.

Once you are feeling brave and confident, checking Automatically Delete Selected Items will give you a confirmation box with the number of selected items that are being deleted.

Once you are *extremely* certain about things... Start! Watch the names of the items that are deleted show up in your General chat tab. See the emptied slots in your Inventory.

Uncheck the Automatically Delete Selected Items box if you do not want to automatically delete items anymore, or if you want to add more items to the automatic deletion.

## BEEEEEEEEEEEETTTTTTTAAAAAAAAAAAAAAAAA

Open the View Selected window to Deselect an item that you no longer want to automatically delete.

Alternatively, uncheck Automatically Delete Selected Items, get the item again, and Deselect the item if you want to stop deleting that item.

*Alternatively* (nuclear option), use /lfnull to reset *ALL* of the addon's settings for your character. Note that you cannot bring the settings for the selected items back - you will need to select them again using the addon as you obtain them.

## New as of BEEEEEEETAAAA v0.9

Remember to /reloadui to save your settings in case Rift crashes.

Auto Select Grey Items is here! Use the chat command '/lf toggle grey' to enable it. There are other toggle options available through chat commands. Type '/lf help' or '/lf settings' to view them. This will become its own configuration window in a future version.

It is possible to Lock an item by right clicking the item in the addon. Locking an item will prevent it from being Selected. This is useful if you have items in another bag that you do not want to delete, and you do not want to worry about accidentally getting again and Selecting. You should Lock all items that you never want to auto delete.

It is possible to Select all items in a bag (except for Locked items) by right clicking the bag in the addon.

There is a testing mode for the addon! Use '/lf toggle prevent' to enable it and see chat messages of *simulated* deletions. Note that, because the addon does *NOT* delete items when Deletion Prevention is enabled, you will see the chat messages again and again whenever the auto deletion functionality runs. This *could* get a little noisy, but it's all in the name of science and testing out the addon without losing any items. Alternatively, use '/lf toggle chat' to disable the auto deletion chat messages.

There is now a rarity indicator (in addition to the new text colors!) on each item in the addon window. This can appear a bit ugly, so feel free to toggle off the indicator using '/lf toggle rarity'. In the future, I will be adding the in-game item borders to all items.

There is a backend statistic for the total # of items ever deleted on the character. I will be displaying this somewhere in a future version.

## Did we mention that this is an beta addon?

The primary reason this addon is in beta is that it *needs testing*. As the addon developer, I cannot be 100% certain that there isn't an Error State, or that there isn't an item that is deleted somewhere that shouldn't be.

As the addon developer, I *am*, however, reasonably confident enough in my code to put it into Beta, instead of Alpha.

Please send any and all error messages my way via my Discord at Vueren#9253. If you are in the Heroes of Telara Discord, you should be able to DM me directly. I do not accept friend requests.
