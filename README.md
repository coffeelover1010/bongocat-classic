# BongoCat Classic

A Bongo Cat animation for World of Warcraft Classic. It includes cats for chat, general player actions, and player spell casts; the spell cat performs a short sequence over the default cast-bar spell icon. The add-on uses the MIT-licensed Kitgore Bongo Cat icon artwork in idle, left-tap, and right-tap states.

## Install for testing

1. Copy the `BongoCatClassic` folder into your Classic client's AddOns directory, for example:
   `World of Warcraft\_classic_\Interface\AddOns\BongoCatClassic` or
   `World of Warcraft\_classic_era_\Interface\AddOns\BongoCatClassic`
2. Start the game and enable **BongoCat Classic** on the AddOns screen. If the client says it is out of date, enable **Load out of date AddOns** for this first test.
3. Log in. The medium chat cat and action cat appear in their default positions. Open chat and type to animate the chat cat.

## Commands

- `/bc` — show help.
- `/bc config` — toggle either cat, optionally limit the chat cat to when its input is open, cycle compact T-shirt sizes (XS–XL), open native colour pickers for fill and outline, choose from Background through On top UI layers, lock its drag position, open the action-trigger list to select triggers individually (which collapses other settings), adjust the shared inactivity fade settings, and set the global action sequence length and tap interval.
- `/bc show`, `/bc hide`, `/bc toggle`
- `/bc reset` — restore the placement defaults.
- `/bc test` — play a short test animation.

## Test notes

Only one cat is visible at a time: the cat associated with the most recent real chat or player activity. The draggable chat cat is constrained to the complete Blizzard chat window plus a 20% margin on every side and listens only for changes to its active edit box; it does not read or store what you type. The draggable action cat responds to action-bar use, spell casts/channels, combat events, movement/turning, target changes, equipment changes, and bag updates. Each global action starts an alternating five-tap sequence by default; you can configure a random minimum–maximum tap range, with a short pacing gate so rapid input remains readable. Both start on the top UI layer with a warm cream fill and soft-black outline, and fade after five seconds of inactivity by default; locking either cat makes it click-through. Please report the exact Classic client version and any error message if an animation does not fire.

Each T-shirt size uses a precomputed TGA texture atlas created with Lanczos resampling, rather than relying entirely on live texture downscaling.

## Credits

Bongo Cat icon artwork from [kitgore/BongoCat](https://github.com/kitgore/BongoCat), used under MIT. Bongo Cat character/art concept by [@StrayRogue](https://x.com/StrayRogue). Original Bongo Cat video concept by @DitzyFlama. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
