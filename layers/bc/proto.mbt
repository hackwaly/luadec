///|
pub type ProtoIndex = Int

///|
pub(all) struct Proto {
  index : ProtoIndex // index in chunk
  source : Bytes?
  line_defined : Int
  last_line_defined : Int
  param_count : Int
  vararg : Bool
  max_stack_size : Int
  code : Array[Instruction]
  constants : Array[Constant]
  upvalues : Array[Upvalue]
  protos : Array[ProtoIndex]
  debug_info : DebugInfo
}

///|
pub(all) struct Upvalue {
  on_stack : Bool
  index : Int
}

///|
pub(all) struct DebugInfo {
  line_info : Array[Int]
  local_info : Array[LocalInfo]
  upval_info : Array[Bytes]
}

///|
pub(all) struct LocalInfo {
  name : Bytes
  start_pc : Int
  end_pc : Int
}
