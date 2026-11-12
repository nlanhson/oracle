# Secure Boot

Your disk is encrypted, and it unlocks by itself at power-on because the laptop's security chip (the TPM)
holds the key. Today the chip hands that key to anything that starts on the laptop while Secure Boot is
off. So someone with a USB stick could start their own system on your laptop and read the disk.

`oracle secureboot setup` closes that gap. It is optional and you can undo it.

## What it does

- It makes **your own Secure Boot keys** and puts them in the laptop's firmware, next to Microsoft's. The
  laptop's own parts (graphics, network) are signed by Microsoft, so those keys stay.
- It **signs the boot menu** (Limine) with your key. With Secure Boot on, the firmware only starts a boot
  loader signed by you or by Microsoft.
- It **locks the boot menu's settings into the signed boot menu.** Limine then refuses any kernel or
  snapshot file that was changed, and nobody can edit the boot line.
- It tells the security chip to hand out the disk key **only when Secure Boot is on, with your keys, and
  your signed boot menu started.** A USB stick, another system, or Secure Boot switched off: no key, the
  laptop asks for the disk password.
- `oracle update`, new kernels, snapshots in the boot menu and `oracle rollback` keep working. They sign
  and lock by themselves, and the disk still unlocks by itself after a power cut.

## Switch it on (once, at the laptop)

Have the charger in and your recovery key at hand (the one you wrote down at install). It takes about 15 minutes.

1. Type `oracle secureboot setup`. The first time it only gets ready and tells you to open the firmware.
2. Restart. Press `F2` while the ASUS logo shows. This opens the firmware setup (the BIOS).
3. Press `F7` for **Advanced Mode**, open the **Security** tab (on some models **Boot**), then
   **Secure Boot** → **Key Management**. Pick **Clear Secure Boot keys** (some firmware says **Delete all
   keys** or **Reset to Setup Mode**). You are in the right state when it says **Setup Mode**, or
   **Platform Key: Not installed**.
4. Press `F10` to save and restart. Oracle starts by itself, no password.
5. Type `oracle secureboot setup` again. This time it makes your keys, signs and locks the boot menu, and
   puts the keys in the firmware. Read what it prints at the end.
6. Restart, press `F2` again, go back to **Secure Boot** and set it to **Enabled**. Do not pick "restore
   factory keys" or "default keys": that removes yours. Press `F10`.
7. Oracle starts by itself, no password. That first start ties the disk key to Secure Boot.
8. Type `oracle secureboot verify`. Every line should say `ok`.

The names in the firmware differ a bit between models and firmware versions. Look for the words
**Secure Boot**, **Key Management** and **Setup Mode**.

## Check it

- `oracle secureboot`: on or off, in plain words, and what is next.
- `oracle secureboot verify`: checks every part (firmware, keys, signed boot menu, locked settings, every
  boot file, the disk key) and says what to do if one is wrong.
- `oracle doctor` has a **Secure Boot** line too.

## Undo it

1. Type `oracle secureboot undo`. The boot menu goes back to unlocked and the disk key gets ready for the switch.
2. Restart, press `F2`, set **Secure Boot** to **Disabled**, press `F10`.
3. Oracle starts by itself, no password, and puts the disk key back as it was before setup.
4. Type `oracle secureboot` to see it is off.

Your keys can stay in the firmware. **Restore factory keys** there is fine too.

## If the laptop asks for the disk password

It means the security chip saw something different from last time: Secure Boot switched off, keys changed,
or a firmware (BIOS) update. Nothing is lost.

1. Type your password, or the recovery key.
2. Log in and type `oracle secureboot setup`. It ties the disk key to how the laptop starts now (it may ask
   for the disk password once more).
3. If Secure Boot was switched off on purpose, type `oracle secureboot undo` instead.

**Before a BIOS update** from ASUS (MyASUS, EZ Flash or `oracle update`): some updates reset the Secure Boot
keys. `oracle update` gets the disk key ready for the next start by itself when it installs firmware. If the
laptop does not start after a BIOS update ("Secure Boot violation"), open the firmware (`F2`), set Secure Boot
to **Disabled**, start Oracle, then run `oracle secureboot setup` again.

**If Oracle does not start at all:** open the firmware (`F2`) and set Secure Boot to **Disabled**. Oracle
starts with the disk password or the recovery key. Then `oracle secureboot verify` tells you what broke.
