///|
async fn cleanup_dir(path : String) -> Unit {
  rmdir(path, recursive=true) catch {
    _ => ()
  }
}

///|
async test "read_file" {
  let path = "lib/fs/fixtures/sample.txt"
  let expected = "fixture content\nsecond line\n"

  inspect(read_file(path).text(), content=expected)
}

///|
async test "write_file" {
  let path = "_build/fs_write_file_test.txt"

  write_file(path, "hello")
  inspect(read_file(path).text(), content="hello")

  write_file(path, "reset")
  inspect(read_file(path).text(), content="reset")
}

///|
async test "unlink_file" {
  let path = "_build/fs_remove_file_test.txt"

  write_file(path, "to be removed")
  unlink(path)
  let removed = try ignore(read_file(path)) catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(removed, content="true")
}

///|
async test "mkdir" {
  let path = "_build/fs_mkdir_test"
  let file = path + "/child.txt"

  cleanup_dir(path)
  mkdir(path)
  write_file(file, "hello")
  inspect(read_file(file).text(), content="hello")
  cleanup_dir(path)
}

///|
async test "mkdir_recursive" {
  let root = "_build/fs_mkdir_recursive_test"
  let path = root + "/a/b"
  let file = path + "/child.txt"

  cleanup_dir(root)
  mkdir(path, recursive=true)
  write_file(file, "hello")
  inspect(read_file(file).text(), content="hello")
  cleanup_dir(root)
}

///|
async test "rmdir" {
  let path = "_build/fs_rmdir_test"
  let removed_file = path + "/child.txt"

  cleanup_dir(path)
  mkdir(path)
  rmdir(path)
  let removed = try ignore(read_file(removed_file)) catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(removed, content="true")
}

///|
async test "rmdir_recursive" {
  let root = "_build/fs_rmdir_recursive_test"
  let path = root + "/a/b"
  let file = path + "/child.txt"

  cleanup_dir(root)
  mkdir(path, recursive=true)
  write_file(file, "hello")
  rmdir(root, recursive=true)
  let removed = try ignore(read_file(file)) catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(removed, content="true")
}
