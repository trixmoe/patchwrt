# PatchWrt

Framework to maintain patched OpenWrt trees for multiple (custom) targets, alongside building tools (incl. for macOS).

## Usage

Run `make help` for instructions and a list of targets, `make` for a list of targets.

## macOS

Doing OpenWrt development from macOS is typically tricky, but doable.

PatchWrt makes it considerably easier through use of containers with mounts and cache volumes to make it easier to work from macOS, while also making building quicker. Any changes done within the container will be visible on the macOS host, while not mounting the whole openwrt checkout.

It is recommended to use VSCode's remote development feature to run VSCode within the container, this makes development in a container considerably easier.
Note that your IDE might have a similar feature or addon, and if you use an editor, you can probably figure it out.

## Credits

Inspired by [gluon](https://github.com/freifunk-gluon/gluon)'s approach, but more minimal and *should* work with `/bin/sh`.
