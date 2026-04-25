///|
pub(all) struct Chunk {
  header : Header
  protos : Array[Proto]
  main : ProtoIndex
}

///|
pub(all) struct Header {
  version : Int
  format : Int
  endianness : Endianness
  int_size : Int
  size_t_size : Int
  instruction_size : Int
  integer_size : Int
  number_size : Int
}

///|
pub(all) enum Endianness {
  LittleEndian
  BigEndian
}
