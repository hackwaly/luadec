///|
const BITRK : Int = 1 << 8

///|
const TOP_COUNT_LABEL : String = "top"

///|
fn line_number(proto : Proto, pc : Int) -> String {
  if pc < proto.debug_info.line_info.length() {
    proto.debug_info.line_info[pc].to_string()
  } else {
    "-"
  }
}

///|
fn endianness_name(value : Endianness) -> String {
  match value {
    LittleEndian => "little"
    BigEndian => "big"
  }
}

///|
fn opcode_name(op : Opcode) -> String {
  match op {
    MOVE => "MOVE"
    LOADK => "LOADK"
    LOADKX => "LOADKX"
    LOADBOOL => "LOADBOOL"
    LOADNIL => "LOADNIL"
    GETUPVAL => "GETUPVAL"
    GETTABUP => "GETTABUP"
    GETTABLE => "GETTABLE"
    SETTABUP => "SETTABUP"
    SETUPVAL => "SETUPVAL"
    SETTABLE => "SETTABLE"
    NEWTABLE => "NEWTABLE"
    SELF => "SELF"
    ADD => "ADD"
    SUB => "SUB"
    MUL => "MUL"
    MOD => "MOD"
    POW => "POW"
    DIV => "DIV"
    IDIV => "IDIV"
    BAND => "BAND"
    BOR => "BOR"
    BXOR => "BXOR"
    SHL => "SHL"
    SHR => "SHR"
    UNM => "UNM"
    BNOT => "BNOT"
    NOT => "NOT"
    LEN => "LEN"
    CONCAT => "CONCAT"
    JMP => "JMP"
    EQ => "EQ"
    LT => "LT"
    LE => "LE"
    TEST => "TEST"
    TESTSET => "TESTSET"
    CALL => "CALL"
    TAILCALL => "TAILCALL"
    RETURN => "RETURN"
    FORLOOP => "FORLOOP"
    FORPREP => "FORPREP"
    TFORCALL => "TFORCALL"
    TFORLOOP => "TFORLOOP"
    SETLIST => "SETLIST"
    CLOSURE => "CLOSURE"
    VARARG => "VARARG"
    EXTRAARG => "EXTRAARG"
  }
}

///|
fn format_constant(constant : Constant) -> String {
  match constant {
    Nil => "nil"
    Boolean(value) => value.to_string()
    Number(value) => value.to_string()
    Integer(value) => value.to_string()
    Utf8String(value) => value.escape(quote=true)
    BytesString(value) => value.to_string()
    AsciiString(value, ..) => value.escape(quote=true)
  }
}

///|
fn format_constant_ref(proto : Proto, index : Int) -> String {
  if index < proto.constants.length() {
    "K\{index}(\{format_constant(proto.constants[index])})"
  } else {
    "K\{index}(?)"
  }
}

///|
fn format_register(value : Int) -> String {
  "R\{value}"
}

///|
fn format_upvalue(proto : Proto, index : Int) -> String {
  let mut result = "U\{index}"
  if index < proto.debug_info.upval_info.length() {
    let name = proto.debug_info.upval_info[index]
    if name.length() > 0 {
      result = result + "[\{name}]"
    }
  }
  if index < proto.upvalues.length() {
    let upvalue = proto.upvalues[index]
    let kind = if upvalue.on_stack { "stack" } else { "upvalue" }
    result = result + "(\{kind}=\{upvalue.index})"
  }
  result
}

///|
fn format_rk(proto : Proto, value : Int) -> String {
  if value >= BITRK {
    format_constant_ref(proto, value - BITRK)
  } else {
    format_register(value)
  }
}

///|
fn jump_target(pc : Int, sbx : Int) -> Int {
  pc + 1 + sbx
}

///|
fn format_count(raw : Int, delta : Int, zero_label : String) -> String {
  if raw == 0 {
    zero_label
  } else {
    (raw - delta).to_string()
  }
}

///|
fn extra_arg_ax(proto : Proto, pc : Int) -> Int? {
  let next_pc = pc + 1
  if next_pc < proto.code.length() {
    let next = proto.code[next_pc]
    match next.op {
      EXTRAARG => return Some(next.ax)
      _ => ()
    }
  }
  None
}

///|
fn operands(proto : Proto, pc : Int, inst : Instruction) -> String {
  match inst.op {
    MOVE => "\{format_register(inst.a)} \{format_register(inst.b)}"
    LOADK => "\{format_register(inst.a)} \{format_constant_ref(proto, inst.bx)}"
    LOADKX =>
      match extra_arg_ax(proto, pc) {
        Some(ax) =>
          "\{format_register(inst.a)} \{format_constant_ref(proto, ax)}"
        None => "\{format_register(inst.a)} K?(missing EXTRAARG)"
      }
    LOADBOOL => "\{format_register(inst.a)} \{inst.b != 0} skip=\{inst.c != 0}"
    LOADNIL => "\{format_register(inst.a)}..\{format_register(inst.a + inst.b)}"
    GETUPVAL => "\{format_register(inst.a)} \{format_upvalue(proto, inst.b)}"
    GETTABUP =>
      "\{format_register(inst.a)} \{format_upvalue(proto, inst.b)} \{format_rk(proto, inst.c)}"
    GETTABLE =>
      "\{format_register(inst.a)} \{format_register(inst.b)} \{format_rk(proto, inst.c)}"
    SETTABUP =>
      "\{format_upvalue(proto, inst.a)} \{format_rk(proto, inst.b)} \{format_rk(proto, inst.c)}"
    SETUPVAL => "\{format_upvalue(proto, inst.b)} \{format_register(inst.a)}"
    SETTABLE =>
      "\{format_register(inst.a)} \{format_rk(proto, inst.b)} \{format_rk(proto, inst.c)}"
    NEWTABLE => "\{format_register(inst.a)} array=\{inst.b} hash=\{inst.c}"
    SELF =>
      "\{format_register(inst.a)} \{format_register(inst.b)} \{format_rk(proto, inst.c)}"
    ADD | SUB | MUL | MOD | POW | DIV | IDIV | BAND | BOR | BXOR | SHL | SHR =>
      "\{format_register(inst.a)} \{format_rk(proto, inst.b)} \{format_rk(proto, inst.c)}"
    UNM | BNOT | NOT | LEN =>
      "\{format_register(inst.a)} \{format_register(inst.b)}"
    CONCAT =>
      "\{format_register(inst.a)} \{format_register(inst.b)}..\{format_register(inst.c)}"
    JMP => "close=\{inst.a} -> \{jump_target(pc, inst.sbx)}"
    EQ | LT | LE =>
      "\{format_rk(proto, inst.b)} \{format_rk(proto, inst.c)} invert=\{inst.a != 0}"
    TEST => "\{format_register(inst.a)} expect=\{inst.c != 0}"
    TESTSET =>
      "\{format_register(inst.a)} \{format_register(inst.b)} expect=\{inst.c != 0}"
    CALL =>
      "\{format_register(inst.a)} args=\{format_count(inst.b, 1, TOP_COUNT_LABEL)}" +
      " results=\{format_count(inst.c, 1, TOP_COUNT_LABEL)}"
    TAILCALL =>
      "\{format_register(inst.a)} args=\{format_count(inst.b, 1, TOP_COUNT_LABEL)}"
    RETURN =>
      "\{format_register(inst.a)} values=\{format_count(inst.b, 1, TOP_COUNT_LABEL)}"
    FORLOOP | FORPREP =>
      "\{format_register(inst.a)} -> \{jump_target(pc, inst.sbx)}"
    TFORCALL => "\{format_register(inst.a)} results=\{inst.c}"
    TFORLOOP => "\{format_register(inst.a)} -> \{jump_target(pc, inst.sbx)}"
    SETLIST =>
      match extra_arg_ax(proto, pc) {
        Some(ax) if inst.c == 0 =>
          "\{format_register(inst.a)} count=\{format_count(inst.b, 0, TOP_COUNT_LABEL)} block=\{ax}"
        _ =>
          "\{format_register(inst.a)} count=\{format_count(inst.b, 0, TOP_COUNT_LABEL)} block=\{inst.c}"
      }
    CLOSURE => "\{format_register(inst.a)} P\{inst.bx}"
    VARARG =>
      "\{format_register(inst.a)} values=\{format_count(inst.b, 1, TOP_COUNT_LABEL)}"
    EXTRAARG => "Ax=\{inst.ax}"
  }
}

///|
fn instruction_text(proto : Proto, pc : Int) -> String {
  let inst = proto.code[pc]
  "\{pc} [\{line_number(proto, pc)}] \{opcode_name(inst.op)} \{operands(proto, pc, inst)}"
}

///|
pub fn instruction_to_string(proto : Proto, pc : Int) -> String raise Failure {
  if pc < 0 || pc >= proto.code.length() {
    fail("instruction index out of bounds: \{pc}")
  }
  instruction_text(proto, pc)
}

///|
fn write_indent(builder : StringBuilder, depth : Int) -> Unit {
  for _ in 0..<depth {
    builder.write_string("  ")
  }
}

///|
fn write_line(builder : StringBuilder, depth : Int, line : String) -> Unit {
  write_indent(builder, depth)
  builder.write_string(line)
  builder.write_string("\n")
}

///|
fn write_constants(builder : StringBuilder, proto : Proto, depth : Int) -> Unit {
  write_line(builder, depth, "constants[\{proto.constants.length()}]")
  for index in 0..<proto.constants.length() {
    write_line(
      builder,
      depth + 1,
      "K\{index} = \{format_constant(proto.constants[index])}",
    )
  }
}

///|
fn write_upvalues(builder : StringBuilder, proto : Proto, depth : Int) -> Unit {
  write_line(builder, depth, "upvalues[\{proto.upvalues.length()}]")
  for index in 0..<proto.upvalues.length() {
    write_line(builder, depth + 1, format_upvalue(proto, index))
  }
}

///|
fn write_proto(
  builder : StringBuilder,
  chunk : Chunk,
  proto : ProtoIndex,
  depth : Int,
) -> Unit {
  let proto = chunk.protos[proto]
  write_line(
    builder,
    depth,
    "proto#\{proto.index} lines=\{proto.line_defined}..\{proto.last_line_defined}" +
    " params=\{proto.param_count} vararg=\{proto.vararg} stack=\{proto.max_stack_size}",
  )
  write_line(builder, depth, "code[\{proto.code.length()}]")
  for pc in 0..<proto.code.length() {
    write_line(builder, depth + 1, instruction_text(proto, pc))
  }
  write_constants(builder, proto, depth)
  write_upvalues(builder, proto, depth)
  if proto.debug_info.local_info.length() > 0 {
    write_line(
      builder,
      depth,
      "locals[\{proto.debug_info.local_info.length()}]",
    )
    for local_info in proto.debug_info.local_info {
      write_line(
        builder,
        depth + 1,
        "\{local_info.name} pc=\{local_info.start_pc}..\{local_info.end_pc}",
      )
    }
  }
  if proto.protos.length() > 0 {
    write_line(builder, depth, "protos[\{proto.protos.length()}]")
    for index in 0..<proto.protos.length() {
      write_proto(builder, chunk, proto.protos[index], depth + 1)
    }
  }
}

///|
pub fn disassemble_proto(chunk : Chunk, proto : Proto) -> String {
  let builder = StringBuilder()
  write_proto(builder, chunk, proto.index, 0)
  builder.to_string()
}

///|
pub fn disassemble(chunk : Chunk) -> String {
  let builder = StringBuilder()
  write_line(
    builder,
    0,
    "header version=0x\{chunk.header.version.to_string(radix=16)} format=\{chunk.header.format}" +
    " endianness=\{endianness_name(chunk.header.endianness)} int=\{chunk.header.int_size}" +
    " size_t=\{chunk.header.size_t_size} instruction=\{chunk.header.instruction_size}" +
    " integer=\{chunk.header.integer_size} number=\{chunk.header.number_size}",
  )
  builder.write_string("\n")
  write_proto(builder, chunk, chunk.main, 0)
  builder.to_string()
}
