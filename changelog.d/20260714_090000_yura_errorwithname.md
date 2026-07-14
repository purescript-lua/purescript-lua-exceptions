### Added

- `Effect.Exception.errorWithName` (upstream v6.1.0 parity, #269). Following
  the fork's string-`Error` model, the name is unobservable: `message`
  returns the supplied message and `name` keeps answering the constant
  `"Error"`, the same precedent as `errorWithCause`'s dropped cause.
