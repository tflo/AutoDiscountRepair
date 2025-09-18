To see all commits, including all alpha changes, [*go here*](https://github.com/tflo/AutoDiscountRepair/commits/master/).

---

## Releases


#### 1.0.1 (2025-09-18)

- Sanitize custom discount input to nominal values (cosmetic). 

#### 1.0.0 (2025-09-18)

- This update brings you what you’ve been waiting for: more random messages at the merchant when there’s nothing to repair :-)
- Changed Shift modifier to prevent auto-repair but still printing the discount calculation.
- Added Shift-Ctrl modifier to completely ignore the merchant interaction event.
- Added `repair` as command argument to toggle auto-repair:
    - Allows you to disable auto-repair w/o unloading the addon.
    - If disabled, it gets auto-enabled at next login (not reload).
    - Argument not exposed in normal help or description, since probably no one needs this.
    - You can achieve the same effect by holding down Shift when opening the merchant.
- Added `Help` and `H` arguments. This is the extended version of `help` and `h` and lists also the `dm` (debug mode) and `repair` (see above) arguments.
- Refactored all messages, moved all strings to init, changed some.
- Less complaining and better sanitizing of weird command input.
- Improved the no-guild-info-retrieved warnings.
- Various minor changes, major cleanup.

#### 0.7.2 (2025-09-15)

- More tolerance for discount validation.
- Debug tweaks.

#### 0.7.1 (2025-09-15)

- The message when there is nothing to repair is now random.
- Minor tweaks.
- Readme/description updated.

#### 0.7.0 (2025-09-14)

- The player now gets fat red warnings if the attempts to fetch guild info fail (after login).
    - Important because retrieving the guild name is crucial for applying the correct guild-related settings (paying with guild funds).
- Longer delays after login before fetching guild info.
- Longer delays between the retries to fetch guild info.
- Code optimizations, better comments and debug.

#### 0.6.4 (2025-09-13)

- Fixed bug when toggling the `guild` setting.
- Refactored slash cmd.

#### 0.6.3 (2025-09-12)

- Refactored init and events.
- Reformatting.

#### 0.6.2 (2025-09-12)

- Slight change to the DB structure.

#### 0.6.1 (2025-09-12)

- Updated toc/docs.

#### 0.6.0 (2025-09-12)

- Initial release for CF.

