///|
/// MoonBit has no view pattern for now. To make life easier, we store unpacked
/// fields here.
pub(all) struct Instruction {
  op : Opcode
  a : Int
  b : Int
  c : Int
  ax : Int
  bx : Int
  sbx : Int
} derive(Debug)

///|
pub fn Instruction::Instruction(raw : UInt) -> Instruction {
  let op = opcodes[(raw & 0x3FU).reinterpret_as_int()]
  let a = ((raw >> 6) & 0xFFU).reinterpret_as_int()
  let c = ((raw >> 14) & 0x1FFU).reinterpret_as_int()
  let b = ((raw >> 23) & 0x1FFU).reinterpret_as_int()
  let bx = ((raw >> 14) & 0x3FFFFU).reinterpret_as_int()
  let ax = (raw >> 6).reinterpret_as_int()
  let sbx = bx - 131071
  { op, a, ax, b, bx, sbx, c }
}
