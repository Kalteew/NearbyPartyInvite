# NearbyPartyInvite

**NearbyPartyInvite** is a lightweight World of Warcraft addon for Mists of Pandaria Classic that helps you quickly invite nearby friendly players to your party.

---

## Features

- Automatically detects nearby players of your faction through combat, targeting, or mouseover and prompts an invitation
- Toggle auto-invite via the minimap button or `/npi` slash commands
- Optional custom whisper message after sending an invite
- Low memory usage

---

## Usage

Enable auto-invite mode with the minimap button or `/npi toggle`. When active, the addon listens for friendly players you encounter and offers to invite them. Use `/npi status` to check the current state, `/npi message <text>` to set a custom whisper, and right-click the minimap button to adjust options like scanning on mouseover or target changes.

---

## Data Storage

- Uses per-account saved variables (`NPI_Settings`)
- Stores auto-invite preferences and whisper message
- Updates automatically during normal gameplay

---

## Limitations

- Only invites players from your faction
- Requires available party slots (maximum five players)
- Players must be encountered through combat, mouseover, or target changes to be detected

---

## Support

Found a bug or have a suggestion?  
Open an issue here: [GitHub - Kalteew/NearbyPartyInvite](https://github.com/Kalteew/NearbyPartyInvite)

---

## License

This addon is open-source under the MIT License.

---

Thank you for using NearbyPartyInvite!

