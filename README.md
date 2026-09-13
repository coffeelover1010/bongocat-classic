# BongoCat Classic

A Bongo Cat animation for World of Warcraft Classic. The classic cat alternates its paws while you type in a chat edit box, using an original, simplified outline sprite in idle, left-tap, and right-tap states.

## Install for testing

1. Copy the `BongoCatClassic` folder into your Classic client's AddOns directory, for example:
   `World of Warcraft\_classic_\Interface\AddOns\BongoCatClassic` or
   `World of Warcraft\_classic_era_\Interface\AddOns\BongoCatClassic`
2. Start the game and enable **BongoCat Classic** on the AddOns screen. If the client says it is out of date, enable **Load out of date AddOns** for this first test.
3. Log in. The cat appears above the bottom centre of the UI. Open chat and type to animate it.

## Commands

- `/bc` — show help.
- `/bc show`, `/bc hide`, `/bc toggle`
- `/bc unlock` — drag the cat with the left mouse button; `/bc lock` prevents dragging.
- `/bc scale 0.5` through `/bc scale 2`
- `/bc reset` — restore the default location and options.
- `/bc test` — play a short test animation.

## Test notes

This first version is deliberately small and client-safe. It listens for changes to the active Blizzard chat box; it does not read or store what you type. Please report the exact Classic client version and any error message if the typing animation does not fire.

## Credits

Bongo Cat character/art concept by [@StrayRogue](https://x.com/StrayRogue). Original Bongo Cat video concept by @DitzyFlama. The shipped outline artwork is original to this add-on and its editable SVG source is included in `BongoCatClassic/ArtSource/`. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
