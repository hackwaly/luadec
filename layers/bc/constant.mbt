///|
pub(all) enum Constant {
  Nil
  Boolean(Bool)
  Number(Double)
  Integer(Int64)
  Utf8String(String)
  BytesString(Bytes)
  AsciiString(String, is_valid_identifier~ : Bool)
} derive(Eq)

///|
pub impl Debug for Constant with to_repr(self) {
  match self {
    Nil => Repr::literal("nil")
    Boolean(true) => Repr::literal("true")
    Boolean(false) => Repr::literal("false")
    Number(n) => Repr::double(n)
    Integer(i) => Repr::integer(i.to_string())
    Utf8String(s) => Repr::string(s)
    BytesString(b) => Repr::literal(b.to_string())
    AsciiString(s, ..) => Repr::literal(s)
  }
}

///|
pub fn Constant::string(bytes : Bytes) -> Constant {
  try @encoding/ascii.decode(bytes) catch {
    @encoding/ascii.Malformed(_) =>
      try @encoding/utf8.decode(bytes) catch {
        @encoding/utf8.Malformed(_) => BytesString(bytes)
      } noraise {
        str => Utf8String(str)
      }
  } noraise {
    str =>
      AsciiString(
        str,
        is_valid_identifier=str =~ re"^[a-zA-Z_][a-zA-Z0-9_]*$" &&
          !(str
          is ("and"
          | "break"
          | "do"
          | "else"
          | "elseif"
          | "end"
          | "false"
          | "for"
          | "function"
          | "goto"
          | "if"
          | "in"
          | "local"
          | "nil"
          | "not"
          | "or"
          | "repeat"
          | "return"
          | "then"
          | "true"
          | "until"
          | "while")),
      )
  }
}
