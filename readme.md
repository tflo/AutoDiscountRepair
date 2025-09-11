# Auto Discount Repair

## Preliminary

This is an early release. In a different context, this would be an alpha or beta version, but since Blizzard doesn’t care about unfinished work and bugs in their release code either, let’s just start out with it as regular version :)

## What the addon does

The repair discount you can get at a specific merchant depends on the merchant’s faction’s reaction towards your toon (0–20% discount). Every time you’re at a repair merchant, the addon checks if you get the desired discount (default is 20%, the max.). If Yes, the addon will auto-repair for you. If not, you’ll get a detailed message in the chat console about the repair price and the actual discount, so you can decide whether to repair manually or not.

That’s it. No bells and no whistles.

Some extras though:

- Periodic message when your current repair costs (inventory + bags) increase by a settable threshold.
- Enter `/adr` into the chat console to display your current standardized (0% discount) repair costs at any time, separately for inventory and bags, if gear in both locations is damaged.
- Two different settings for paying with guild funds.
- Settable discount threshold.
- See the detailed explanations for the settings in the “Interface” section.

## Interface

The addon uses the chat console as user interface.

The main command is `/adr`. If no arguments are provided, this will print your current repair costs (before discount).

The most important argument is `help` (or `h`). The command `/adr help` or `/adr h` will show you all available arguments (settings), your current settings, and other information you might need to know.

The `/adr` command understands the following arguments (settings); most of them are toggles (true/false):

- `guild` : Prefer guild funds for auto-repairs [toggle; default: false].
- `guildonly` : Use _exclusively_ guild funds for auto-repairs [toggle; default: false]. If enabled, this implies “Prefer guild funds”.
- `0%||5%||10%||15%||20%||max` : Discount threshold; `max` = `20%` [percent; default: 20%].
- `summary` : Print summary at repair merchant [toggle; default: true].
- `costs` : Print the current repair costs when they increase [toggle; default: true]. This prints your current repair costs to the chat after your gear has suffered durability loss.
- `<number>` : Minimum cost increase to print a new message [difference in Gold;  default: 5]. This requires the `costs` option to be enabled.
- `sound` : Play a little sound whenever the increased repair costs are printed [toggle; default: true]. This requires the `costs` option to be enabled.
- `help` or `h` : Shows the Help text, with a list of all arguments and the current settings.

All settings are account-wide, except for the guild-related settings. These are per guild.

After every command, the addon prints the current state of the setting you’ve just changed.

Some notes on the guild-related settings:

- If your char is not in a guild, any guild settings are irrelevant for this char. The char will always pay with personal funds.
- With `guild` activated, the addon will try to pay with guild funds. However, if this fails (e.g. not enough guild repair funds available to you, no permissions, or whatever), the bill, partially or entirely, will be payed with the char’s money.
- With `guildonly` activated, the addon will exclusively try to pay with guild funds. If this fails for whatever reason, it will not fall back to the char’s funds. This may result in incomplete repairs, so it’s probably better to leave this option disabled (which is the default).
    - The addon recalculates the repair costs immediately after the repair action, so, when the repair failed or was incomplete, you should get a notice. But this doesn’t work 100% reliably (WiP).
- If `guild` is disabled (false) and you enable `guildonly`, this will naturally override the `guild` setting.

A note on the “Required increment for printing the repair costs”:

- For this, simply enter the desired increment threshold in Gold, e.g. `/adr 20`.
- Increment means the difference to the last repair costs that have been printed.
- If you want to get informed for every tiny increment, you can also anter amounts like `0.5` (= 50 Silver).
- If you use `0` (zero Gold), you will get the message each time the addon recalculates the costs, no matter if they increased or not.
- The addon prints your repair costs automatically after login/reload.

