///|
pub(all) enum Doc {
  EmptyD
  TextD(String)
  LineD(String)
  HardLineD
  ConcatD(Doc, Doc)
  NestD(Int, Doc)
  UnionD(Doc, Doc)
} derive(Debug)

///|
priv enum Docs {
  NilL
  Cons(Int, Doc, Docs)
}

///|
pub fn empty() -> Doc {
  EmptyD
}

///|
pub fn text(s : String) -> Doc {
  if s == "" {
    EmptyD
  } else {
    TextD(s)
  }
}

///|
pub fn line() -> Doc {
  LineD(" ")
}

///|
pub fn linebreak() -> Doc {
  LineD("")
}

///|
pub fn softline() -> Doc {
  group(line())
}

///|
pub fn softbreak() -> Doc {
  group(linebreak())
}

///|
pub fn hardline() -> Doc {
  HardLineD
}

///|
pub fn space() -> Doc {
  text(" ")
}

///|
pub fn concat(left : Doc, right : Doc) -> Doc {
  match (left, right) {
    (EmptyD, _) => right
    (_, EmptyD) => left
    _ => ConcatD(left, right)
  }
}

///|
pub impl Add for Doc with add(self, other) {
  concat(self, other)
}

///|
pub fn concat_all(docs : ArrayView[Doc]) -> Doc {
  let mut result = EmptyD
  for doc in docs {
    result = concat(result, doc)
  }
  result
}

///|
pub fn nest(indent : Int, doc : Doc) -> Doc {
  if indent == 0 {
    doc
  } else {
    NestD(indent, doc)
  }
}

///|
pub fn flatten(doc : Doc) -> Doc {
  match doc {
    EmptyD => EmptyD
    TextD(_) => doc
    LineD(alt) => text(alt)
    HardLineD => HardLineD
    ConcatD(left, right) => concat(flatten(left), flatten(right))
    NestD(indent, body) => nest(indent, flatten(body))
    UnionD(left, _) => flatten(left)
  }
}

///|
pub fn group(doc : Doc) -> Doc {
  UnionD(flatten(doc), doc)
}

///|
pub fn join(sep : Doc, docs : ArrayView[Doc]) -> Doc {
  match docs {
    [] => EmptyD
    [first, .. rest] => {
      let mut result = first
      for doc in rest {
        result = concat(result, concat(sep, doc))
      }
      result
    }
  }
}

///|
pub fn surround(left : Doc, body : Doc, right : Doc) -> Doc {
  concat_all([left, body, right])
}

///|
pub fn parens(doc : Doc) -> Doc {
  surround(text("("), doc, text(")"))
}

///|
pub fn brackets(doc : Doc) -> Doc {
  surround(text("["), doc, text("]"))
}

///|
pub fn braces(doc : Doc) -> Doc {
  surround(text("{"), doc, text("}"))
}

///|
fn fits(width : Int, docs : Docs) -> Bool {
  if width < 0 {
    return false
  }
  match docs {
    NilL => true
    Cons(indent, doc, rest) =>
      match doc {
        EmptyD => fits(width, rest)
        TextD(s) => fits(width - s.length(), rest)
        LineD(_) => true
        HardLineD => true
        ConcatD(left, right) =>
          fits(width, Cons(indent, left, Cons(indent, right, rest)))
        NestD(extra, body) => fits(width, Cons(indent + extra, body, rest))
        UnionD(left, _) => fits(width, Cons(indent, left, rest))
      }
  }
}

///|
fn write_indent(buf : StringBuilder, indent : Int) -> Unit {
  for _ in 0..<indent {
    buf.write_char(' ')
  }
}

///|
fn render_docs(
  buf : StringBuilder,
  width : Int,
  column : Int,
  docs : Docs,
) -> Int {
  match docs {
    NilL => column
    Cons(indent, doc, rest) =>
      match doc {
        EmptyD => render_docs(buf, width, column, rest)
        TextD(s) => {
          buf.write_string(s)
          render_docs(buf, width, column + s.length(), rest)
        }
        LineD(_) => {
          buf.write_char('\n')
          write_indent(buf, indent)
          render_docs(buf, width, indent, rest)
        }
        HardLineD => {
          buf.write_char('\n')
          write_indent(buf, indent)
          render_docs(buf, width, indent, rest)
        }
        ConcatD(left, right) =>
          render_docs(
            buf,
            width,
            column,
            Cons(indent, left, Cons(indent, right, rest)),
          )
        NestD(extra, body) =>
          render_docs(buf, width, column, Cons(indent + extra, body, rest))
        UnionD(left, right) => {
          let left_docs = Cons(indent, left, rest)
          if fits(width - column, left_docs) {
            render_docs(buf, width, column, left_docs)
          } else {
            render_docs(buf, width, column, Cons(indent, right, rest))
          }
        }
      }
  }
}

///|
pub fn print(doc : Doc, width? : Int = 80) -> String {
  let buf = StringBuilder::new()
  let _ = render_docs(buf, width, 0, Cons(0, doc, NilL))
  buf.to_string()
}
