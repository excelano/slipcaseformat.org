# Contributing

The site is public and so is this repository. Corrections, clearer wording, a
missing implementation, a broken link, a rendering bug in a browser I do not
have — all of it is welcome as a pull request or an issue.

## Contributions are dedicated to the public domain

Everything here is dedicated to the public domain under [CC0 1.0](LICENSE). By
contributing you dedicate your contribution on the same terms, waiving copyright
and related rights in it to the extent possible under law. This matches the
specification, which cannot carry a part that an implementer may not use.

## Two things that do not belong here

**Changes to the specification.** `spec/` and `design/` are generated from
`SPEC.md` and `DESIGN.md` in
[excelano/slipcase](https://github.com/excelano/slipcase), which is the authority
on the format. An edit to those pages is overwritten the next time they are
baked, and a website is not somewhere a format gets amended. Take it to that
repository; if the specification cannot answer a question you actually hit, that
is the most valuable thing you can send anywhere.

**An implementation that does not exist yet.** The implementations page lists
programs a person can obtain. A plan is not one.

## Adding an implementation

Open a pull request against `implementations/index.html` with the name, what it
does, which version of the specification it implements, and a link to its source
or its listing. Completeness is not a bar — a library that only reads containers
is worth listing, and worth saying so about.

## House style

Prose, in paragraphs. The specification is written that way and the site follows
it: full sentences over bullet points, and a claim stated plainly rather than
hedged. If a sentence could be a heading and a list, it is usually better as a
sentence.

Plain HTML. No framework, no build step for the hand-written pages, no
JavaScript beyond the theme toggle, and nothing loaded from a third party — no
fonts, no analytics, no CDN. A page must work with JavaScript off.

Styling comes from the vendored [Axe](https://github.com/excelano/axe)
framework, which styles standard HTML elements without classes. Reach for the
right element before reaching for a class, and add a class to `brand.css` only
when the framework has no opinion about what you are building.

Check both themes. The toggle in the navigation bar switches them, and a colour
that only works in one is a bug.

## Before you open a pull request

Serve the site and look at what you changed:

```sh
python3 -m http.server 8000    # then http://localhost:8000/
```

If you touched anything that could fall out of step with the specification, run
`tools/bake-docs.sh --check`. It exits non-zero when the generated pages no
longer match the upstream text.
