# App Store distribution — an additional permission

Kallo is free software under the **GNU General Public License, version 3 or
later**: see [`LICENSE`](LICENSE). The copyright holders grant the following
additional permission under section 7 of the GNU GPL version 3.

## The permission

As an exception to the terms of the GNU GPL version 3, you have permission to
convey ("distribute") Kallo, and works based on Kallo, through the **Apple App
Store**, **Apple TestFlight**, **Google Play**, the **Microsoft Store**, and
comparable application stores or distribution channels, and to accept the
standard terms those stores impose on applications distributed through them,
notwithstanding any term of the GNU GPL version 3 that would otherwise conflict
with that distribution — including, without limitation:

- restrictions on redistribution or further conveyance of the copy a store
  delivers;
- limits on the number of devices or accounts on which it may be installed or
  used;
- a requirement that recipients accept the store operator's terms of service;
- technical measures (DRM) that control the installation or execution of the
  copy; and
- the Installation Information requirement of section 6, for a build that can
  only be installed through a store that signs it.

This permission applies **only to conveyance through such a store**. It does not
change what the GPLv3 asks of any other distribution: outside the stores, Kallo
is distributed under the GPLv3 exactly as [`LICENSE`](LICENSE) says, and the
complete Corresponding Source for every released binary is this repository, at
the tag of the release.

It is an additional permission, not an additional restriction. It grants a
permission the GPLv3 would not otherwise give; it never takes away a right the
GPLv3 gives you, and under section 7 you may remove it from a copy you convey.

## The measurements are CC BY-SA 4.0, not the GPL

The code is GPL-3.0-or-later. The measurement data — the `.kalofilm` and
`.kalopaper` files, the digitised curves, the figures and the prose around them,
and the stock tables and `assets/film_strip.json` generated from them — is
licensed **CC BY-SA 4.0** (see [`data/films/LICENSE`](data/films/LICENSE)). It
is not code and the GPL does not apply to it.

As the licensor of that data, the copyright holders also permit conveying the
application, including the data generated into it at build time and the
`film_strip.json` asset, through the stores named above on the terms of this
page; the data itself stays available under CC BY-SA 4.0 in this repository, at
the same tag as the build.

## Why this exists

The Free Software Foundation's position is that the Apple App Store's terms
conflict with the GPL: the store adds usage restrictions and DRM that the GPL
does not let an ordinary distributor impose on recipients. This additional
permission is the copyright holders' permission for those terms, so that the
official builds can be offered in the stores while the project stays free
software under the GPL. Nothing in the app's dependency graph is copyleft except
this project's own code — the Rust and Flutter dependencies are permissive and
the bundled fonts are under the SIL OFL — so this permission covers everything
GPL that a build contains.

This page is a licence, not legal advice. If you rely on it for a store
submission of your own build, read the GPLv3 and get advice.

## Contributions

By submitting a contribution to this repository you agree to license it under
GPL-3.0-or-later **including this additional permission**, so that the official
builds can keep using it. Do not contribute code you cannot license on those
terms.
