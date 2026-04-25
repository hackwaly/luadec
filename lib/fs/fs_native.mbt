///|
pub async fn read_file(path : StringView) -> &@io.Data {
  @async/fs.read_file(path)
}

///|
pub async fn write_file(path : StringView, content : &@io.Data) -> Unit {
  @async/fs.write_file(path, content, create=0o644)
}

///|
pub async fn unlink(path : StringView) -> Unit {
  @async/fs.remove(path)
}

///|
pub async fn mkdir(path : StringView, recursive? : Bool = false) -> Unit {
  @async/fs.mkdir(path, permission=0o755, recursive~)
}

///|
pub async fn rmdir(path : StringView, recursive? : Bool = false) -> Unit {
  @async/fs.rmdir(path, recursive~)
}
