# slipcaseformat.org

The website for the [Slipcase](https://github.com/excelano/slipcase) container
format, live at <https://slipcaseformat.org>.

**The specification is not kept here.** It lives in `excelano/slipcase`, which is
the authority on the format; this repository holds the site that presents it. A
page here that disagrees with the specification is a bug in the page.

## What is in it

Four pages of plain HTML. `index.html` is what a container is and why;
`implementations/` is the programs that read and write one; `spec/` and
`design/` are generated (see below). Styling is the
[Axe](https://github.com/excelano/axe) framework, vendored under `axe/` as real
files, with `brand.css` layered over it as this site's palette.

There is no build step for the hand-written pages, no framework, and no
JavaScript beyond `axe/theme.js`, which remembers whether you asked for the dark
theme. The site loads nothing from a third party: no fonts, no analytics, no
trackers, no CDN.

## The two generated pages

`spec/index.html` and `design/index.html` are rendered from `SPEC.md` and
`DESIGN.md` in the specification repository. Do not edit them — edit the
specification, and re-bake:

```sh
tools/bake-docs.sh                                # from the tip of main
tools/bake-docs.sh --ref=v1.0                     # from a tag
tools/bake-docs.sh --check                        # exit 1 if the site is stale
SPEC_SRC=~/slipcase/slipcase tools/bake-docs.sh   # from a local checkout
```

It needs `pandoc`, and `curl` unless `SPEC_SRC` names a checkout. Each page is
stamped with the commit it was rendered from, so a reader can tell what revision
they are looking at. The output is committed, so deploying the site needs
neither tool and no network.

`tools/build-og-card.sh` regenerates the social card at `img/og-card.png`; it
needs ImageMagick and `rsvg-convert`. Its output is committed too. Nothing in
`tools/` is served — the deploy excludes the directory.

## Working on it

Root-relative URLs mean the pages need a server root rather than `file://`:

```sh
python3 -m http.server 8000    # then http://localhost:8000/
```

`update-axe.sh` refreshes the vendored framework from a local `~/axe`. It is
gitignored and is the maintainer's, not a contributor's.

## Contributing

Pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). A merged
change goes live when the maintainer deploys, which is a manual step and usually
quick.

## Licence

Everything here is dedicated to the public domain under
[CC0 1.0](LICENSE), the same terms as the specification.

Two exceptions, both belonging to other repositories and carried here as copies:
`img/slipcase-icon.svg` is from
[excelano/slipcase-common](https://github.com/excelano/slipcase-common) and
`axe/` is from [excelano/axe](https://github.com/excelano/axe), each MIT
licensed, © Excelano LLC.
