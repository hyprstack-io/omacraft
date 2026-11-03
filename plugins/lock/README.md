# omacraft.lock

Omarchy's lock screen with a look you can change from OmaCraft's Lock & Logon page.

- `Service.qml` and `FingerprintModel.js` are Omarchy's `omarchy.lock`. PAM, the session lock and the fingerprint reader are unchanged. The added lines are marked `omacraft:`: the look's file, a picture picked from a folder, the transition before release, and the blank delay.
- `LockView.qml` passes the theme and translations to `LockScene.qml`, which draws everything and has no ties to the shell. OmaCraft's preview and the login theme draw the same file.
- `LockDefaults.js` is every setting and its limits. Everything read goes through `clean()`.
- Settings are in `~/.config/omarchy/omacraft-lock.json` and apply without a shell restart. It holds looks only.

When Omarchy updates its lock, compare the service with `diff /usr/share/omarchy/shell/plugins/lock/Service.qml plugins/lock/Service.qml`.
