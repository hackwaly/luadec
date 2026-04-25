///|
extern "js" fn get_argv() -> Array[String] =
  #|() => process.argv.slice(2)

///|
pub let argv : Array[String] = get_argv()
