///|
const LUA_SIGNATURE : Bytes = b"\x1bLua"

///|
const LUAC_DATA : Bytes = b"\x19\x93\x0d\x0a\x1a\x0a"

///|
const LUAC_INT : Int64 = 0x5678L

///|
const LUAC_NUM : Double = 370.5

///|
fn decode_uint(view : BytesView, endianness : Endianness) -> UInt64 {
  let mut value = 0UL
  match endianness {
    LittleEndian =>
      for i in 0..<view.length() {
        value = value + (view[i].to_uint().to_uint64() << (i * 8))
      }
    BigEndian =>
      for byte in view {
        value = (value << 8) + byte.to_uint().to_uint64()
      }
  }
  value
}

///|
fn decode_signed(value : UInt64, size : Int) -> Int64 {
  if size == 8 {
    return value.reinterpret_as_int64()
  }
  let bits = size * 8
  let sign = 1UL << (bits - 1)
  if value >= sign {
    (value - (1UL << bits)).reinterpret_as_int64()
  } else {
    value.reinterpret_as_int64()
  }
}

///|
fn decode_number(
  view : BytesView,
  endianness : Endianness,
) -> Double raise Failure {
  let bits = decode_uint(view, endianness)
  match view.length() {
    4 => Float::reinterpret_from_uint(bits.to_uint()).to_double()
    8 => bits.reinterpret_as_double()
    _ => fail("unsupported lua_Number size: \{view.length()}")
  }
}

///|
fn infer_endianness(
  integer_marker : BytesView,
  number_marker : BytesView,
) -> Endianness? raise Failure {
  let little_ok = decode_signed(
      decode_uint(integer_marker, LittleEndian),
      integer_marker.length(),
    ) ==
    LUAC_INT &&
    decode_number(number_marker, LittleEndian) == LUAC_NUM
  if little_ok {
    return Some(LittleEndian)
  }
  let big_ok = decode_signed(
      decode_uint(integer_marker, BigEndian),
      integer_marker.length(),
    ) ==
    LUAC_INT &&
    decode_number(number_marker, BigEndian) == LUAC_NUM
  if big_ok {
    return Some(BigEndian)
  }
  None
}

///|
priv struct Parser {
  input : BytesView
  mut offset : Int
  protos : Array[Proto]
}

///|
fn Parser::new(input : BytesView) -> Parser {
  { input, offset: 0, protos: [] }
}

///|
fn[T] Parser::parse_error(self : Parser, message : String) -> T raise Failure {
  fail("invalid Lua 5.3 chunk at byte \{self.offset}: \{message}")
}

///|
fn Parser::take(self : Parser, size : Int) -> BytesView raise Failure {
  if size < 0 {
    self.parse_error("negative read size")
  }
  let end_offset = self.offset + size
  if end_offset > self.input.length() {
    self.parse_error("unexpected end of input")
  }
  let start = self.offset
  self.offset = end_offset
  self.input[start:end_offset]
}

///|
fn Parser::read_byte(self : Parser) -> Byte raise Failure {
  self.take(1)[0]
}

///|
fn Parser::expect_bytes(
  self : Parser,
  expected : Bytes,
  description : String,
) -> Unit raise Failure {
  let actual = self.take(expected.length())
  if actual != expected {
    self.parse_error("expected \{description}")
  }
}

///|
fn Parser::read_uint(
  self : Parser,
  size : Int,
  endianness : Endianness,
) -> UInt64 raise Failure {
  if size <= 0 || size > 8 {
    self.parse_error("unsupported integer size: \{size}")
  }
  decode_uint(self.take(size), endianness)
}

///|
fn Parser::read_size(
  self : Parser,
  size : Int,
  endianness : Endianness,
  description : String,
) -> Int raise Failure {
  let value = self.read_uint(size, endianness)
  if value > 0x7fffffffUL {
    self.parse_error("\{description} exceeds MoonBit Int range")
  }
  value.to_int()
}

///|
fn Parser::read_integer(
  self : Parser,
  size : Int,
  endianness : Endianness,
) -> Int64 raise Failure {
  decode_signed(self.read_uint(size, endianness), size)
}

///|
fn Parser::read_number(
  self : Parser,
  size : Int,
  endianness : Endianness,
) -> Double raise Failure {
  let raw = self.take(size)
  match raw.length() {
    4 | 8 => decode_number(raw, endianness)
    _ => self.parse_error("unsupported lua_Number size: \{size}")
  }
}

///|
fn Parser::read_header(self : Parser) -> Header raise Failure {
  self.expect_bytes(LUA_SIGNATURE, "Lua signature")
  let version = self.read_byte().to_int()
  if version != 0x53 {
    self.parse_error(
      "expected version 0x53, got 0x\{version.to_string(radix=16)}",
    )
  }
  let format = self.read_byte().to_int()
  if format != 0 {
    self.parse_error("expected format 0, got \{format}")
  }
  self.expect_bytes(LUAC_DATA, "LUAC_DATA")
  let int_size = self.read_byte().to_int()
  let size_t_size = self.read_byte().to_int()
  let instruction_size = self.read_byte().to_int()
  let integer_size = self.read_byte().to_int()
  let number_size = self.read_byte().to_int()
  let integer_marker = self.take(integer_size)
  let number_marker = self.take(number_size)
  let endianness = match infer_endianness(integer_marker, number_marker) {
    Some(value) => value
    None => self.parse_error("LUAC_INT / LUAC_NUM validation failed")
  }
  if instruction_size != 4 {
    self.parse_error("unsupported instruction size: \{instruction_size}")
  }
  {
    version,
    format,
    endianness,
    int_size,
    size_t_size,
    instruction_size,
    integer_size,
    number_size,
  }
}

///|
fn Parser::read_bool(self : Parser) -> Bool raise Failure {
  match self.read_byte() {
    b'\x00' => false
    b'\x01' => true
    value => self.parse_error("invalid boolean payload: \{value.to_int()}")
  }
}

///|
fn Parser::read_string(self : Parser, header : Header) -> Bytes? raise Failure {
  let size_prefix = self.read_byte().to_int()
  if size_prefix == 0 {
    return None
  }
  let size = if size_prefix == 0xFF {
    self.read_size(header.size_t_size, header.endianness, "string length")
  } else {
    size_prefix
  }
  if size <= 0 {
    self.parse_error("invalid string length")
  }
  let payload_size = size - 1
  Some(self.take(payload_size).to_owned())
}

///|
fn Parser::read_instruction(
  self : Parser,
  header : Header,
) -> Instruction raise Failure {
  let raw = self.read_uint(header.instruction_size, header.endianness)
  Instruction(raw.to_uint())
}

///|
fn Parser::read_constant(
  self : Parser,
  header : Header,
) -> Constant raise Failure {
  match self.read_byte().to_int() {
    0 => Nil
    1 => Boolean(self.read_bool())
    3 => Number(self.read_number(header.number_size, header.endianness))
    0x13 => Integer(self.read_integer(header.integer_size, header.endianness))
    4 | 0x14 =>
      match self.read_string(header) {
        Some(bytes) => Constant::string(bytes)
        None => self.parse_error("string constant payload cannot be null")
      }
    tag => self.parse_error("unsupported constant tag: \{tag}")
  }
}

///|
fn Parser::read_upvalue(self : Parser) -> Upvalue raise Failure {
  { on_stack: self.read_bool(), index: self.read_byte().to_int() }
}

///|
fn Parser::read_local_info(
  self : Parser,
  header : Header,
) -> LocalInfo raise Failure {
  let name = match self.read_string(header) {
    Some(value) => value
    None => self.parse_error("local variable name cannot be null")
  }
  {
    name,
    start_pc: self.read_size(
      header.int_size,
      header.endianness,
      "local start_pc",
    ),
    end_pc: self.read_size(header.int_size, header.endianness, "local end_pc"),
  }
}

///|
fn Parser::read_debug_info(
  self : Parser,
  header : Header,
) -> DebugInfo raise Failure {
  let line_count = self.read_size(
    header.int_size,
    header.endianness,
    "line info length",
  )
  let line_info : Array[Int] = []
  for _ in 0..<line_count {
    line_info.push(
      self.read_size(header.int_size, header.endianness, "line info entry"),
    )
  }

  let local_count = self.read_size(
    header.int_size,
    header.endianness,
    "local info length",
  )
  let local_info : Array[LocalInfo] = []
  for _ in 0..<local_count {
    local_info.push(self.read_local_info(header))
  }

  let upvalue_name_count = self.read_size(
    header.int_size,
    header.endianness,
    "upvalue name length",
  )
  let upval_info : Array[Bytes] = []
  for _ in 0..<upvalue_name_count {
    let name = match self.read_string(header) {
      Some(value) => value
      None => b""
    }
    upval_info.push(name)
  }

  { line_info, local_info, upval_info }
}

///|
fn Parser::read_proto(
  self : Parser,
  header : Header,
) -> ProtoIndex raise Failure {
  let source = self.read_string(header)
  let line_defined = self.read_size(
    header.int_size,
    header.endianness,
    "line_defined",
  )
  let last_line_defined = self.read_size(
    header.int_size,
    header.endianness,
    "last_line_defined",
  )
  let param_count = self.read_byte().to_int()
  let vararg = self.read_bool()
  let max_stack_size = self.read_byte().to_int()

  let code_count = self.read_size(
    header.int_size,
    header.endianness,
    "code length",
  )
  let code : Array[Instruction] = []
  for _ in 0..<code_count {
    code.push(self.read_instruction(header))
  }

  let constant_count = self.read_size(
    header.int_size,
    header.endianness,
    "constant length",
  )
  let constants : Array[Constant] = []
  for _ in 0..<constant_count {
    constants.push(self.read_constant(header))
  }

  let upvalue_count = self.read_size(
    header.int_size,
    header.endianness,
    "upvalue length",
  )
  let upvalues : Array[Upvalue] = []
  for _ in 0..<upvalue_count {
    upvalues.push(self.read_upvalue())
  }

  let proto_count = self.read_size(
    header.int_size,
    header.endianness,
    "nested proto length",
  )
  let protos : Array[ProtoIndex] = []
  for _ in 0..<proto_count {
    protos.push(self.read_proto(header))
  }

  let debug_info = self.read_debug_info(header)
  let index = self.protos.length()
  let proto : Proto = {
    index,
    source,
    line_defined,
    last_line_defined,
    param_count,
    vararg,
    max_stack_size,
    code,
    constants,
    upvalues,
    protos,
    debug_info,
  }
  self.protos.push(proto)
  proto.index
}

///|
pub fn parse(bytes : BytesView) -> Chunk raise Failure {
  let parser = Parser::new(bytes)
  let header = parser.read_header()
  let _ = parser.read_byte() // sizeupvalues
  let main = parser.read_proto(header)
  if parser.offset != parser.input.length() {
    parser.parse_error("trailing bytes after main prototype")
  }
  { header, protos: parser.protos, main }
}
