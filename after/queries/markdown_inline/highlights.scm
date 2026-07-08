; Full local copy of nvim-treesitter's queries/markdown_inline/highlights.scm,
; with one rule changed (see "Conceal shortcut links" below). Diff against
; ~/.local/share/nvim/lazy/nvim-treesitter/queries/markdown_inline/highlights.scm
; to keep in sync with upstream changes.
;
; NOTE: this file is NOT used directly by treesitter — Neovim's after/queries
; loading MERGES with the bundled query rather than replacing it (confirmed
; empirically: an empty override here left the bundled rule fully active), so
; simply dropping this file in gets you the upstream rule PLUS whatever's
; here, not a replacement. lua/plugins/ui/markdown_inline_query.lua reads
; this file's text and calls vim.treesitter.query.set() directly, which does
; replace the compiled query — that's what actually makes the fix below take
; effect. Keep this .scm file as the source of truth (readable, diffable
; against upstream); the Lua file just loads and installs it.

; From MDeiml/tree-sitter-markdown
(code_span) @markup.raw @nospell

(emphasis) @markup.italic

(strong_emphasis) @markup.strong

(strikethrough) @markup.strikethrough

(shortcut_link
  (link_text) @nospell)

[
  (backslash_escape)
  (hard_line_break)
] @string.escape

; Conceal codeblock and text style markers
([
  (code_span_delimiter)
  (emphasis_delimiter)
] @conceal
  (#set! conceal ""))

; Conceal inline links
(inline_link
  [
    "["
    "]"
    "("
    (link_destination)
    ")"
  ] @markup.link
  (#set! conceal ""))

[
  (link_label)
  (link_text)
  (link_title)
  (image_description)
] @markup.link.label

((inline_link
  (link_destination) @_url) @_label
  (#set! @_label url @_url))

((image
  (link_destination) @_url) @_label
  (#set! @_label url @_url))

; Conceal image links
(image
  [
    "!"
    "["
    "]"
    "("
    (link_destination)
    ")"
  ] @markup.link
  (#set! conceal ""))

; Conceal full reference links
(full_reference_link
  [
    "["
    "]"
    (link_label)
  ] @markup.link
  (#set! conceal ""))

; Conceal collapsed reference links
(collapsed_reference_link
  [
    "["
    "]"
  ] @markup.link
  (#set! conceal ""))

; Conceal shortcut links — EXCEPT checkbox-shaped ones ([ ], [x], [X], []).
; GFM task-list syntax technically requires a leading list marker (`- `) for
; `[ ]`/`[x]` to parse as a real task item; without one, this grammar falls
; back to treating any bare "[text]" as a shortcut reference link, and
; upstream conceals its brackets unconditionally. That silently eats the
; brackets on a checkbox typed without a dash, leaving a bare "x" (or
; nothing, for "[ ]") behind on screen — worse than just showing the raw
; markdown. Skip concealment when the bracket contents look like a checkbox
; marker so it displays as literal "[ ]"/"[x]" instead.
((shortcut_link
  (link_text) @_text
  [
    "["
    "]"
  ] @markup.link)
  (#not-match? @_text "^[ xX]?$")
  (#set! conceal ""))

[
  (link_destination)
  (uri_autolink)
  (email_autolink)
] @markup.link.url @nospell

((uri_autolink) @_url
  (#offset! @_url 0 1 0 -1)
  (#set! @_url url @_url))

(entity_reference) @nospell

; Replace common HTML entities.
((entity_reference) @character.special
  (#eq? @character.special "&nbsp;")
  (#set! conceal " "))

((entity_reference) @character.special
  (#eq? @character.special "&lt;")
  (#set! conceal "<"))

((entity_reference) @character.special
  (#eq? @character.special "&gt;")
  (#set! conceal ">"))

((entity_reference) @character.special
  (#eq? @character.special "&amp;")
  (#set! conceal "&"))

((entity_reference) @character.special
  (#eq? @character.special "&quot;")
  (#set! conceal "\""))

((entity_reference) @character.special
  (#any-of? @character.special "&ensp;" "&emsp;")
  (#set! conceal " "))
