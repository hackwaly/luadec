///|
enum Output {
  Stdout
  Stderr
}

///|
extern "js" fn write_once(
  dest : String,
  buf : Bytes,
  offset : Int,
  len : Int,
) -> @js_async.Promise[Int] =
  #| (dest, buf, offset, len) => new Promise((resolve, reject) => {
  #|   if (
  #|     typeof process === "undefined" ||
  #|     process[dest] == null ||
  #|     typeof process[dest].write !== "function"
  #|   ) {
  #|     reject(new Error(dest + " is unavailable"))
  #|     return
  #|   }
  #|
  #|   const chunk = buf.subarray(offset, offset + len)
  #|   process[dest].write(chunk, (error) => {
  #|     if (error) {
  #|       reject(error)
  #|     } else {
  #|       resolve(len)
  #|     }
  #|   })
  #| })

///|
pub impl @io.Writer for Output with fn write_once(_self, buf, offset~, len~) {
  match _self {
    Stdout => write_once("stdout", buf, offset, len).wait()
    Stderr => write_once("stderr", buf, offset, len).wait()
  }
}

///|
pub let stdout : Output = Stdout

///|
pub let stderr : Output = Stderr
