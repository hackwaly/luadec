///|
extern "js" fn read_file_impl(
  path : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[Bytes] =
  #| async (path, signal) => {
  #|   const fs = typeof require === "function"
  #|     ? require("node:fs/promises")
  #|     : await import("node:fs/promises")
  #|   return fs.readFile(path, { signal })
  #| }

///|
extern "js" fn write_file_impl(
  path : String,
  content : Bytes,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[Unit] =
  #| async (path, content, signal) => {
  #|   const fs = typeof require === "function"
  #|     ? require("node:fs/promises")
  #|     : await import("node:fs/promises")
  #|   await fs.writeFile(path, content, { signal })
  #| }

///|
extern "js" fn unlink_impl(
  path : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[Unit] =
  #| async (path, signal) => {
  #|   const fs = typeof require === "function"
  #|     ? require("node:fs/promises")
  #|     : await import("node:fs/promises")
  #|   await fs.unlink(path, { signal })
  #| }

///|
extern "js" fn mkdir_impl(
  path : String,
  recursive : Bool,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[Unit] =
  #| async (path, recursive, signal) => {
  #|   const fs = typeof require === "function"
  #|     ? require("node:fs/promises")
  #|     : await import("node:fs/promises")
  #|   await fs.mkdir(path, { recursive, signal })
  #| }

///|
extern "js" fn rmdir_impl(
  path : String,
  recursive : Bool,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[Unit] =
  #| async (path, recursive, signal) => {
  #|   const fs = typeof require === "function"
  #|     ? require("node:fs/promises")
  #|     : await import("node:fs/promises")
  #|   if (recursive) {
  #|     await fs.rm(path, { recursive: true, signal })
  #|   } else {
  #|     await fs.rmdir(path, { signal })
  #|   }
  #| }

///|
pub async fn read_file(path : StringView) -> &@io.Data {
  @js_async.run_promise(signal => read_file_impl(path.to_string(), signal))
}

///|
pub async fn write_file(path : StringView, content : &@io.Data) -> Unit {
  @js_async.run_promise(_signal => {
    write_file_impl(path.to_string(), content.binary(), _signal)
  })
}

///|
pub async fn unlink(path : StringView) -> Unit {
  @js_async.run_promise(signal => unlink_impl(path.to_string(), signal))
}

///|
pub async fn mkdir(path : StringView, recursive? : Bool = false) -> Unit {
  @js_async.run_promise(signal => {
    mkdir_impl(path.to_string(), recursive, signal)
  })
}

///|
pub async fn rmdir(path : StringView, recursive? : Bool = false) -> Unit {
  @js_async.run_promise(signal => {
    rmdir_impl(path.to_string(), recursive, signal)
  })
}
