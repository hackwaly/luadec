///|
extern "js" fn get_argv() -> FixedArray[String] =
  #|() => process.argv.slice(2)

///|
pub let argv : Array[String] = get_argv().iter().to_array()
