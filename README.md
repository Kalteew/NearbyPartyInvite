# NearbyPartyInvite

NearbyPartyInvite is a lightweight World of Warcraft addon for Mists of Pandaria Classic that helps you quickly invite nearby friendly players engaged in the same combat activities.

## Installation
1. Download or clone this repository.
2. Copy the `NearbyPartyInvite` folder into your World of Warcraft `Interface/AddOns` directory for MoP Classic.
3. Restart the game or type `/reload` in-game.

## Usage
- Click the minimap button or type `/npi toggle` to enable or disable auto-invite mode.
- Right-click the minimap button to open the addon settings.
- Use `/npi status` to check whether auto-invite mode is currently enabled.
- Enable a custom whisper in the addon options or set it with `/npi message <text>`. The message will be sent as `NearbyPartyInvite: <text>` when inviting a player via the popup.


## Releasing

This project uses [BigWigsMods/packager](https://github.com/BigWigsMods/packager) to build and publish releases to CurseForge. Pushing a Git tag will trigger the workflow defined in `.github/workflows/curseforge.yml`.

Set the `CF_API_KEY` and `CF_PROJECT_ID` repository secrets to enable uploads to your CurseForge project.
