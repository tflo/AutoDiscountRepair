# Auto Discount Repair

## Preliminary

This is an early release. In a different context, this would be an alpha or beta version, but since Blizzard doesn’t care about unfinished work in their code either, let’s just start out with it as regular version :)

## What the addon does

The repair discount you can get at specific merchant depends on the merchant’s faction’s reaction towards your toon (0–20% discount). Every time you’re at a repair merchant, the addon checks if you get the max repair discount (20%). If Yes, the addon will auto-repair for you. If not, you’ll get a detailed message in the chat console about the repair price and the actual discount, so you can decide whether to repair or not.

That’s it. No bells and no whistles, for the moment. Some may come (see Future features).

Oh, you can enter `/adr` into the chat console to display your current standardized (0% discount) repair costs at any time.

Additional features:

- Periodic message when your current repair costs (inventory + bags) increase.

## Interface

The addon uses the chat console as user interface.

The main command is `/adr`. If no arguments are provided, this will print your current repair costs (before discount).

The most important argument is `help` (or `h`). The command `/adr help` or `/adr h` will show you all available arguments, and other information you might need to know.

Besides that, the `/adr` command understands these arguments; most of them are toggles (true/false):

- `guild` : Prefer guild money for auto repairs [toggle; default: false]
- `guildonly` : Use exclusively guild money for auto repairs [toggle; default: false]
- `0%||5%||10%||15%||20%||max` : Discount threshold; `max` = `20%` [percent; default: 20%]
- `summary` : Show summary at merchant [toggle; default: true]
- `costs` : Show current repair costs when they increased [toggle; default: true]. This shows your current repair costs in the chat after your gear has suffered durability loss.
- `<number>` : Increment for showing the repair costs [amount in Gold;  default: 10]
- `help` or `h` : Shows the Help text, with a list of all arguments and the current settings.

The guild-money settings are saved per guild. If your char is not in a guild, any guild settings are irrelevant for this char. All other settings are account-wide.

After every command, the addon prints the current state of the setting you’ve just changed.


## Future features (aka currently missing features, ToDo):

- Maybe: LDB display and button (this will take a while)

