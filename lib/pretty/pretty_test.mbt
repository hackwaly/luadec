///|
test "pretty.render prints plain text" {
  let doc = concat_all([text("hello"), space(), text("world")])
  assert_eq(print(doc), "hello world")
}

///|
test "pretty.group flattens when it fits" {
  let doc = group(
    concat_all([text("foo"), nest(2, concat(line(), text("bar")))]),
  )
  assert_eq(print(doc, width=80), "foo bar")
}

///|
test "pretty.group breaks and indents when it does not fit" {
  let doc = group(
    concat_all([text("foo"), nest(2, concat(line(), text("bar")))]),
  )
  assert_eq(print(doc, width=6), "foo\n  bar")
}

///|
test "pretty.linebreak flattens to empty text" {
  let doc = group(concat_all([text("a"), linebreak(), text("b")]))
  assert_eq(print(doc, width=80), "ab")
  assert_eq(print(doc, width=1), "a\nb")
}

///|
test "pretty.hardline always breaks" {
  let doc = group(concat_all([text("a"), hardline(), text("b")]))
  assert_eq(print(doc, width=80), "a\nb")
}

///|
test "pretty.join builds multiline groups" {
  let comma_line = concat(text(","), line())
  let items = [text("aaa"), text("bbb"), text("ccc")]
  let doc = group(
    concat_all([
      text("["),
      nest(2, concat(softbreak(), join(comma_line, items))),
      softbreak(),
      text("]"),
    ]),
  )
  assert_eq(print(doc, width=80), "[aaa, bbb, ccc]")
  assert_eq(print(doc, width=10), "[aaa,\n  bbb,\n  ccc]")
}
