# Auto Discount Repair

Automatically repair your gear – where it’s cheap.

## Preliminary

As of 14 Sep 2025 and version 0.7.0, this addon is still in an early stage. It’s likely that we will have to squish a few more bugs ;) You can help by reporting bugs (or suggestions) to the [GitHub Issues](https://github.com/tflo/AutoDiscountRepair/issues) of the repo! (Please do not post issues/suggestions to the CurseForge comments.)

___If you’re having trouble reading this description on CurseForge, you might want to try switching to the [REPO PAGE](https://github.com/tflo/AutoDiscountRepair#auto-discount-repair). You’ll find the exact same text there, but it’s much easier to read and free from CurseForge’s rendering errors.___

## What the addon does

There are many addons with auto-repair functionality, but we try to handle it smart.

In Modern WoW, you can get a discount when repairing gear at a repair merchant. This faction discount applies if the merchant belongs to a reputation faction and your standing with that faction is above Neutral. The discount percentage varies based on your standing: 5%, 10%, 15%, or 20%. This can be substantial over time or with a steep repair bill. 

Every time you interact with a repair merchant, the addon checks if you get your configured minimum discount (default is 20%, the max.). If Yes, the addon will auto-repair for you. If not, you’ll get a message in the chat console about the actual discount and repair price, so you can decide whether to repair manually or not.

That’s it. No bells and no whistles.

Some extras though:

- Periodic message when your current repair costs (inventory + bags) increase by a configurable threshold (for example every 5 Gold).
- Enter `/adr` into the chat console to display your current standardized (0% discount) repair costs at any time, separately for inventory and bags, if gear in both locations is damaged.
- Two different settings for paying with guild funds.
- Configurable discount threshold.
- See the detailed explanations for the settings in the “Interface” section.

## Interface

__The addon uses the chat console as user interface.__

The __slash command is `/adr`.__ If no arguments are provided, this will print your current repair costs (before discount).

The most important argument is `help` (or `h`): The command `/adr help` or `/adr h` will show you all available arguments (settings), your current settings, and other information you might need to know.

__The `/adr` command understands the following arguments (settings);__ most of them are toggles (true/false):

- `guild` : Prefer guild funds for auto-repairs [toggle; default: false].
- `guildonly` : Use _exclusively_ guild funds for auto-repairs [toggle; default: false]. If enabled, this implies “Prefer guild funds”.
- `0%||5%||10%||15%||20%||max` : Minimum repair discount threshold; `max` = `20%` [percent; default: 20%].
- `summary` : Print summary at repair merchant [toggle; default: true].
- `costs` : Print the current repair costs when they increase [toggle; default: true]. This prints your current repair costs to the chat after your gear has suffered durability loss.
- `<number>` : Minimum cost increase to print a new repair costs message [difference in Gold;  default: 5]. This requires the `costs` option to be enabled.
- `sound` : Play a little sound whenever the increased repair costs are printed [toggle; default: true]. This requires the `costs` option to be enabled. (Actually you get different sounds, depending on how much the costs have increased.)
- `help` or `h` : Shows the Help text, with a list of all arguments and the current settings.

All settings are account-wide, except for the guild-related settings. These are per guild.

After every command, the addon prints the current state of the setting you’ve just changed.

Some __notes__ on the __guild-related settings:__

- If your char is not in a guild, any previous guild settings are irrelevant for this char (since guild settings are saved per guild). The char will always pay with personal funds.
- With `guild` activated, the addon will try to pay with guild funds. However, if this fails (e.g. not enough guild repair funds available to you, no permissions, or whatever), the bill, partially or entirely, will be paid with the char’s money.
- With `guildonly` activated, the addon will exclusively try to pay with guild funds. If this fails for whatever reason, it will not fall back to the char’s funds. This may result in incomplete repairs, so it’s probably better to leave this option disabled (which is the default).
    - The addon recalculates the repair costs immediately after the repair action, so, when the repair failed or was incomplete, you should get a notice. But this doesn’t work 100% reliably (WiP).
- If `guild` is disabled (false) and you enable `guildonly`, it will naturally imply that `guild` is enabled.

A __note__ on the __“Minimum cost increase to print a new message”:__

- For this, simply enter the desired increase threshold in Gold, e.g. `/adr 10`.
- “Increase” means the difference to the last repair costs that have been printed.
- If you want to get informed for every tiny increase, you can also anter amounts like `0.5` (= 50 Silver).
- If you use `0` (zero Gold), you will get the message each time the addon recalculates the costs, no matter if they increased or not.
- The addon prints your repair costs automatically after login/reload.

__Have fun with the addon!__

---

Feel free to post suggestions or issues in the [GitHub Issues](https://github.com/tflo/AutoDiscountRepair/issues) of the repo!
__Please do not post issues or suggestions in the comments on Curseforge.__

---

__Other addons by me:__

- [___PetWalker___](https://www.curseforge.com/wow/addons/petwalker): Never lose your pet again (…or randomly summon a new one).
- [___Auto Quest Tracker Mk III___](https://www.curseforge.com/wow/addons/auto-quest-tracker-mk-iii): Continuation of the one and only original. Up to date and tons of new features.
- [___Move 'em All___](https://www.curseforge.com/wow/addons/move-em-all): Mass move items/stacks from your bags to wherever. Works also fine with most bag addons.
- [___Auto-Confirm Equip___](https://www.curseforge.com/wow/addons/auto-confirm-equip): Less (or no) confirmation prompts for BoE gear.
- [___Action Bar Button Growth Direction___](https://www.curseforge.com/wow/addons/action-bar-button-growth-direction): Fix the button growth direction of multi-row action bars to what is was before Dragonflight (top --> bottom).
- [___EditBox Font Improver___](https://www.curseforge.com/wow/addons/editbox-font-improver): Better fonts for your macro/script edit boxes.

__WeakAuras:__

- [___Stats Mini___](https://wago.io/S4023p3Im): A *very* compact but beautiful and feature-loaded stats display: primary/secondary stats, *all* defensive stats (also against target), GCD, speed (rating/base/actual/Skyriding), iLevel (equipped/overall/difference), char level +progress.


