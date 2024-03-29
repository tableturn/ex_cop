[
  inputs: [
    "{config,lib,priv,test}/**/*.{ex,exs}",
    "mix.exs",
    ".formatter.exs",
    ".iex.exs"
  ],
  locals_without_parens: [
    delegated: :*,
    subject: :*,
    persona: :*,
    parent: :*,
    parent_in: :*,
    field: :*,
    field_in: :*,
    context: :*,
    args: :*,
    guard: :*,
    check: :*
  ]
]
