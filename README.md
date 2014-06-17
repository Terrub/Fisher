Fisher
======

Rogue Poison charges in bar form

The addon displays two (linked but movable as a whole) coloured bars that will attempt to show you
an indication of how many charges you have left on your rogue poisons.

The current API does not allow for easy access to the maximum amount of charges on a given poison so;
right now the maximum is estimated. Whenever a new poison is applied or weapons are swapped, the
current amount of charges is considered the relative maximum. The green bar shrinks untill
the poison wears off or the charges are depleted in which case a red bar will display indicating the
need for reapplying.

-- SLASH COMMANDS --
for options type /fisher

-- INSTALLATION --

1. Download the files: Fisher.lua and Fisher.toc and remember the location. (Desktop will work)
2. Create a new folder called "Fisher" inside the /Interface/AddOns/ folder of your client.
3. Put all the files from step 1 inside the /Interface/AddOns/Fisher folder
4. Load up the client and check for the addon.
