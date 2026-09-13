# BongoCat Classic

A Bongo Cat animation for World of Warcraft Classic. The add-on uses the MIT-licensed Kitgore Bongo Cat icon artwork in idle, left-tap, and right-tap states.

## Install for testing

1. Copy the `BongoCatClassic` folder into your Classic client's AddOns directory, for example:
   `World of Warcraft\_classic_\Interface\AddOns\BongoCatClassic` or
   `World of Warcraft\_classic_era_\Interface\AddOns\BongoCatClassic`
2. Start the game and enable **BongoCat Classic** on the AddOns screen. If the client says it is out of date, enable **Load out of date AddOns** for this first test.
3. Log in. The medium chat cat, action-bar cat, and small corner cats appear in their default positions. Open chat and type to animate the chat cat.

## Commands

- `/bc` — show help.
- `/bc config` — configure placements, visibility, size, and minor horizontal/vertical offsets.
- `/bc show`, `/bc hide`, `/bc toggle`
- `/bc reset` — restore the placement defaults.
- `/bc test` — play a short test animation.

## Test notes

The chat cat listens only for changes to the active Blizzard chat box; it does not read or store what you type. Action-bar and corner cats respond to player movement, target changes, and completed spell casts, with a short pacing gate so rapid input remains readable. Please report the exact Classic client version and any error message if an animation does not fire.

## Credits

Bongo Cat icon artwork from [kitgore/BongoCat](https://github.com/kitgore/BongoCat), used under MIT. Bongo Cat character/art concept by [@StrayRogue](https://x.com/StrayRogue). Original Bongo Cat video concept by @DitzyFlama. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
