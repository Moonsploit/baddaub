### If you arent keyrolled, use regular [daub](https://github.com/Moonsploit/daub-shim) instead.
# baddaub - keyrolled update blocking
### What is this?
baddaub is daub injected into badrecovery unverified, allowing for update blocking on keyrolled kernver 6 ChromeOS devices. baddaub is a fork of [badbr0ker](https://github.com/crosbreaker/badbr0ker)
### If you would like the script to do everything for you:
```bash
git clone https://github.com/Moonsploit/baddaub
cd baddaub
sudo bash buildfull_baddaub.sh <board>
```
### If you would like to use a local recovery image:
```bash
git clone https://github.com/Moonsploit/baddaub
cd badsh1mmer
sudo ./build_badrecovery.sh -i image.bin -t unverified
```
### How do I flash it to a usb drive or sd card?
Download a prebuilt from [dl.snerill.org/baddaub](https://dl.snerill.org/BadDaub), or build an image yourself with the above commands.  Flash it using the [Chromebook Recovery Utility](https://chromewebstore.google.com/detail/chromebook-recovery-utili/pocpnlppkickgojjlmhdmidojbmbodfm), or anything else that flashes images to USB drives and sd cards, such as [BalenaEtcher](https://etcher.balena.io/), [dd](https://en.wikipedia.org/wiki/Dd_(Unix)) or [rufus](https://rufus.ie/en/)
### I have flashed a usb drive or sd card, what now?
Complete sh1ttyoobe, sh1ttyexec, or any oher method for booting unverified recovery images then enter developer mode and recover to your usb, choose to unenroll or reenroll, then reboot and disable developer mode. When you setup it will be unenrolled.
### Credits:

[BinBashBanana](https://github.com/binbashbanana) - badrecovery

[crosbreaker](https://github.com/crosbreaker) - badsh1mmer

[Zeglol](https://github.com/ZeglolTheThirtySixth) - daub
