///|
pub struct Id(Int) derive(Debug, Eq, Compare, Hash)

///|
pub struct IdGen {
  mut next : Int

  fn new() -> IdGen
} derive(Debug)

///|
pub fn IdGen::new() -> IdGen {
  { next: 0 }
}

///|
pub fn IdGen::next(self : IdGen) -> Id {
  let id = self.next
  self.next += 1
  Id(id)
}
