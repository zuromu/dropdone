# Security Policy

## Supported versions

Only the latest release gets fixes.

## Reporting a problem

Please do not open a public issue for a security problem.

Use GitHub's private reporting instead: go to the **Security** tab of this repository and click **Report a vulnerability**. I will reply as soon as I can and tell you what happens next.

## What the app touches

Dropdone reads and writes one file, `~/Library/Application Support/Dropdone/items.json`. If that file cannot be read, it is moved to `items.json.bak` in the same folder so the old list is not overwritten. Turning on Open at login adds Dropdone to the system's login items. It does not use the network.
