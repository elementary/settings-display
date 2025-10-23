# Display Settings
[![Packaging status](https://repology.org/badge/tiny-repos/switchboard-plug-display.svg)](https://repology.org/metapackage/switchboard-plug-display)
[![Translation status](https://l10n.elementaryos.org/widget/settings/display/svg-badge.svg)](https://l10n.elementaryos.org/engage/settings/)

Extension for [System Settings](https://github.com/elementary/switchboard) to manage multiple monitor setups.

![screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

* libadwaita-1-dev
* libgranite-7-dev
* libgtk-4-dev
* libswitchboard-3-dev
* meson
* valac

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    ninja install

## Headless tests (no GUI required)

This repository now includes a small, headless test suite that exercises the core layout logic (overlap resolution, edge adjacency, and origin normalization) without requiring GTK or a running compositor. This helps validate behavior even on single‑monitor or headless environments.

To run tests after configuring the build directory:

    meson test -C build --print-errorlogs

You should see the `layout_logic` test pass. These tests simulate 3+ displays, overlap scenarios, and ensure the layout can be normalized and stays connected without crashes.
