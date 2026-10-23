# Dia Router

A tiny stand-in default browser for macOS that opens each link in the right [Dia](https://www.diabrowser.com) profile, like Arc's Air Traffic Control.

macOS sends every link you click in other apps (Slack, Mail, Teams and so on) to Dia Router. It checks the link against your rules and uses Dia's AppleScript support to open it in a new tab in the matching profile. If routing fails for any reason, the link opens in Dia normally, so you never lose a link.

## Install

```sh
./install.sh
```

This builds the app, installs it to `~/Applications/Dia Router.app`, and creates `~/.config/dia-router/rules.json` from `rules.example.json` if you don't have one yet. Edit that file to match your own profiles and domains.

Your rules live in `~/.config`, outside this repo, so they stay private. `rules.example.json` is only a template, and running `install.sh` again never overwrites your rules.

Then set it as your default browser in **System Settings → Desktop & Dock → Default web browser → Dia Router**.

The first routed link triggers a macOS prompt asking to let Dia Router control Dia. Allow it. You can review this in **System Settings → Privacy & Security → Automation**.

## Rules

`~/.config/dia-router/rules.json`:

```json
{
  "default": "Personal",
  "rules": [
    { "profile": "Work", "match": ["mycompany.com", "mycompany.atlassian.net", "github.com/mycompany"] },
    { "profile": "Client", "match": ["client-example.org"] }
  ]
}
```

- `profile` is the profile name exactly as Dia shows it.
- A `match` pattern is a domain, optionally followed by a path prefix:
  - `mycompany.com` matches `mycompany.com` and every subdomain, such as `docs.mycompany.com`. `*.mycompany.com` means the same.
  - `github.com/mycompany` matches GitHub URLs whose path starts with `/mycompany`.
- Rules are checked in order and the first match wins.
- Links wrapped by Microsoft Safe Links (from Teams or Outlook) are matched by the real link inside the wrapper. The wrapped link is still what opens, so Microsoft's safety check still runs.
- `default` is used when nothing matches. Leave it out to open unmatched links in whichever profile is active in Dia.

The file is read on every link, so changes apply immediately. No rebuild needed.

## Logs

Every routing decision and failure is written to `~/Library/Logs/DiaRouter.log`.

## Limitations

- Only links opened from other apps are routed. Links clicked inside Dia stay in the current profile.
- The app is ad-hoc signed, so every rebuild counts as a new app to macOS. After running `install.sh` again, expect the Automation prompt once more. Editing rules doesn't cause this.
- It relies on Dia's AppleScript dictionary (profiles, tabs, `focus`). A Dia update could change that.
