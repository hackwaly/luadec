///|
const BITRK : Int = 1 << 8

///|
const LFIELDS_PER_FLUSH = 50

///|
fn func_from_proto(proto : @bc.Proto, upvalues~ : Array[Local]) -> Func {
  let code = proto.code
  let entry_pc = 0

  let id : FuncId = { index: proto.index, }
  let local_ = fn(x : Int) -> Local { { func: id, slot: x, } }
  let local_e = fn(x : Int) -> Expr { LocalE(local_(x)) }
  let const_e = fn(x : Int) -> Expr { ConstE(proto.constants[x]) }
  let local_or_const_e = fn(x : Int) -> Expr {
    if x >= BITRK {
      const_e(x - BITRK)
    } else {
      local_e(x)
    }
  }
  let stops : Array[Int] = {
    let end_pc = code.length()
    let mut stops : SortedSet[Int] = SortedSet::new()

    stops = stops.add(entry_pc)
    for pc = entry_pc; pc < end_pc; pc = pc + 1 {
      match code[pc:] {
        [{ op: EQ | LT | LE | TEST, }, { op: JMP, sbx, }, ..] => {
          stops = stops.add(pc + 2)
          stops = stops.add(pc + 2 + sbx)
        }
        [{ op: TESTSET, }, { op: JMP, sbx, }, ..] => {
          stops = stops.add(pc + 2)
          let body_pc = pc + 2 + sbx
          stops = stops.add(body_pc)
        }
        [{ op: LOADBOOL, c: 0, }, ..] => ()
        [{ op: LOADBOOL, c: 1..<_, }, ..] => {
          stops = stops.add(pc + 1)
          stops = stops.add(pc + 2)
        }
        [{ op: JMP, sbx, }, ..] => {
          stops = stops.add(pc + 1)
          stops = stops.add(pc + 1 + sbx)
        }
        [{ op: FORPREP, sbx, }, ..] => stops = stops.add(pc + 1 + sbx)
        [{ op: FORLOOP, sbx, }, ..] => {
          stops = stops.add(pc + 1)
          stops = stops.add(pc + 1 + sbx)
        }
        [{ op: TFORCALL, }, { op: TFORLOOP, sbx, }, ..] => {
          stops = stops.add(pc + 2)
          stops = stops.add(pc + 2 + sbx)
        }
        [{ op: TAILCALL, }, ..] => ()
        [{ op: RETURN, }, ..] => stops = stops.add(pc + 1)
        _ => ()
      }
    }
    stops = stops.add(end_pc)
    stops.to_array()
  }

  let blocks : Map[Label, Block] = {
    let blocks = Map([])
    let add_block = fn(start_pc : Int, end_pc : Int) {
      let stmts : Array[Stmt] = []
      letrec scan = fn(curr : ArrayView[@bc.Instruction]) -> Term {
        for curr = curr {
          let pc = curr.start_offset()
          match curr {
            [] => break JumpT(Label(pc=end_pc))
            [{ op: MOVE, a, b, }, .. next] => {
              stmts.push(SetS(local_(a), local_e(b)))
              continue next
            }
            [{ op: LOADK, a, bx, }, .. next]
            | [{ op: LOADKX, a, }, { op: EXTRAARG, ax: bx, }, .. next] => {
              stmts.push(SetS(local_(a), const_e(bx)))
              continue next
            }
            [{ op: LOADBOOL, a, b, c: 0, }, .. next] => {
              stmts.push(SetS(local_(a), ConstE(Boolean(b != 0))))
              continue next
            }
            [{ op: LOADBOOL, a, b, c, }] => {
              guard c != 0 else { panic() }
              stmts.push(SetS(local_(a), ConstE(Boolean(b != 0))))
              break JumpT(Label(pc=pc + 2))
            }
            [{ op: LOADNIL, a, b, }, .. next] => {
              for x in a..<=(a + b) {
                stmts.push(SetS(local_(x), ConstE(Nil)))
              }
              continue next
            }
            [{ op: GETUPVAL, a, b, }, .. next] => {
              stmts.push(SetS(local_(a), LocalE(upvalues[b])))
              continue next
            }
            [{ op: GETTABUP, a, b, c, }, .. next] => {
              stmts.push(
                SetS(
                  local_(a),
                  IndexE(LocalE(upvalues[b]), local_or_const_e(c)),
                ),
              )
              continue next
            }
            [{ op: GETTABLE, a, b, c, }, .. next] => {
              stmts.push(
                SetS(local_(a), IndexE(local_e(b), local_or_const_e(c))),
              )
              continue next
            }
            [{ op: SETTABUP, a, b, c, }, .. next] => {
              stmts.push(
                SetIndexS(
                  LocalE(upvalues[a]),
                  local_or_const_e(b),
                  local_or_const_e(c),
                ),
              )
              continue next
            }
            [{ op: SETUPVAL, a, b, }, .. next] => {
              stmts.push(SetS(upvalues[b], local_e(a)))
              continue next
            }
            [{ op: SETTABLE, a, b, c, }, .. next] => {
              stmts.push(
                SetIndexS(local_e(a), local_or_const_e(b), local_or_const_e(c)),
              )
              continue next
            }
            [{ op: NEWTABLE, a, b: _, c: _, }, .. next] => {
              stmts.push(SetS(local_(a), NewTableE))
              continue next
            }
            [{ op: SELF, a, b, c, }, .. next] => {
              stmts.push(SetS(local_(a + 1), local_e(b)))
              stmts.push(
                SetS(local_(a), IndexE(local_e(b), local_or_const_e(c))),
              )
              continue next
            }
            [
              {
                op: ADD
                | SUB
                | MUL
                | MOD
                | POW
                | DIV
                | IDIV
                | BAND
                | BOR
                | BXOR
                | SHL
                | SHR as op,
                a,
                b,
                c,
              },
              .. next,
            ] => {
              stmts.push(
                SetS(
                  local_(a),
                  BinaryE(
                    match op {
                      ADD => Add
                      SUB => Sub
                      MUL => Mul
                      MOD => Mod
                      POW => Pow
                      DIV => Div
                      IDIV => IDiv
                      BAND => BAnd
                      BOR => BOr
                      BXOR => BXor
                      SHL => Shl
                      SHR => Shr
                      _ => panic()
                    },
                    local_or_const_e(b),
                    local_or_const_e(c),
                  ),
                ),
              )
              continue next
            }
            [{ op: UNM | BNOT | NOT | LEN as op, a, b, }, .. next] => {
              stmts.push(
                SetS(
                  local_(a),
                  UnaryE(
                    match op {
                      UNM => Neg
                      BNOT => BNot
                      NOT => Not
                      LEN => Len
                      _ => panic()
                    },
                    local_e(b),
                  ),
                ),
              )
              continue next
            }
            [{ op: CONCAT, a, b, c, }, .. next] => {
              let mut acc = local_e(c)
              for x in (c - 1)>=..b {
                acc = BinaryE(Concat, local_e(x), acc)
              }
              stmts.push(SetS(local_(a), acc))
              continue next
            }
            [{ op: JMP, sbx, }] => break JumpT(Label(pc=pc + 1 + sbx))
            [{ op: EQ | LT | LE as op, a, b, c, }, { op: JMP, sbx, }] =>
              break CondT(
                BinaryE(
                  match (op, a == 1) {
                    (EQ, true) => Eq
                    (EQ, false) => Neq
                    (LT, true) => Lt
                    (LT, false) => Geq
                    (LE, true) => Leq
                    (LE, false) => Gt
                    _ => panic()
                  },
                  local_or_const_e(b),
                  local_or_const_e(c),
                ),
                Label(pc=pc + 2 + sbx),
                Label(pc=pc + 2),
              )
            [{ op: TEST, a, c, }, { op: JMP, sbx, }] =>
              break CondT(
                if c == 0 {
                  UnaryE(Not, local_e(a))
                } else {
                  local_e(a)
                },
                Label(pc=pc + 2 + sbx),
                Label(pc=pc + 2),
              )
            [{ op: TESTSET, a, b, c, }, { op: JMP, sbx, }] =>
              break CondSetT(
                if c == 0 {
                  UnaryE(Not, local_e(b))
                } else {
                  local_e(b)
                },
                local_(a),
                local_e(b),
                Label(pc=pc + 2 + sbx),
                Label(pc=pc + 2),
              )
            [{ op: CALL, a, b: 1..<_ as b, c, }, .. next] => {
              let xs : Array[Expr] = []
              for x in (a + 1)..<=(a + b - 1) {
                xs.push(local_e(x))
              }
              match c {
                0 => break close_multi(a, CallM(local_e(a), xs, None), next)
                1 => {
                  stmts.push(SetMultiS([], CallM(local_e(a), xs, None)))
                  continue next
                }
                2 => {
                  stmts.push(SetS(local_(a), CallE(local_e(a), xs, None)))
                  continue next
                }
                _ => {
                  let ys : Array[Local] = []
                  for y in a..<=(a + c - 2) {
                    ys.push(local_(y))
                  }
                  stmts.push(SetMultiS(ys, CallM(local_e(a), xs, None)))
                  continue next
                }
              }
            }
            [{ op: TAILCALL, a, b: 1..<_ as b, }, ..] => {
              let xs : Array[Expr] = []
              for x in (a + 1)..<=(a + b - 1) {
                xs.push(local_e(x))
              }
              break ReturnT([], Some(CallM(local_e(a), xs, None)))
            }
            [{ op: RETURN, a, b: 1..<_ as b, }] => {
              let xs : Array[Expr] = []
              for x in a..<=(a + b - 2) {
                xs.push(local_e(x))
              }
              break ReturnT(xs, None)
            }
            [{ op: FORLOOP, a, sbx, }] =>
              break ForLoopT(
                local_(a),
                local_e(a + 1),
                local_e(a + 2),
                local_(a + 3),
                Label(pc=pc + 1 + sbx),
                Label(pc=pc + 1),
              )
            [{ op: FORPREP, a, sbx, }] =>
              break ForPrepT(local_(a), local_e(a + 2), Label(pc=pc + 1 + sbx))
            [{ op: TFORCALL, a, c, }, { op: TFORLOOP, a: loop_a, sbx, }] => {
              guard loop_a == a + 2 else { panic() }
              let ys : Array[Local] = []
              for y in (a + 3)..<=(a + 2 + c) {
                ys.push(local_(y))
              }
              break GenericForT(
                local_e(a),
                local_e(a + 1),
                local_(a + 2),
                ys,
                Label(pc=pc + 2 + sbx),
                Label(pc=pc + 2),
              )
            }
            [
              { op: SETLIST, a, b: 1..<_ as b, c: 0, },
              { op: EXTRAARG, ax: c, },
              .. next,
            ]
            | [{ op: SETLIST, a, b: 1..<_ as b, c: 1..<_ as c, }, .. next] => {
              let xs : Array[Expr] = []
              for i in 1..<=b {
                xs.push(local_e(a + i))
              }
              stmts.push(
                SetListS(
                  local_e(a),
                  ConstE(Integer(((c - 1) * LFIELDS_PER_FLUSH).to_int64())),
                  xs,
                  None,
                ),
              )
              continue next
            }
            [{ op: CLOSURE, a, bx, }, .. next] => {
              stmts.push(
                SetS(local_(a), ClosureE({ index: proto.protos[bx], })),
              )
              continue next
            }
            [{ op: VARARG, a, b: 0, }, .. next] =>
              break close_multi(a, VarargM, next)
            [{ op: VARARG, b: 1, }, .. next] => continue next
            [{ op: VARARG, a, b: 2..<_ as b, }, .. next] => {
              let ys : Array[Local] = []
              for y in a..<=(a + b - 2) {
                ys.push(local_(y))
              }
              stmts.push(SetMultiS(ys, VarargM))
              continue next
            }
            _ => panic()
          }
        }
      }
      and close_multi = fn(
        base : Int,
        multi : Multi,
        curr : ArrayView[@bc.Instruction],
      ) -> Term {
        match curr {
          [{ op: CALL, a, b: 0, c, }, .. next] => {
            let xs : Array[Expr] = []
            if a + 1 < base {
              for x in (a + 1)..<base {
                xs.push(local_e(x))
              }
            }
            match c {
              0 => close_multi(base, CallM(local_e(a), xs, Some(multi)), next)
              1 => {
                stmts.push(SetMultiS([], CallM(local_e(a), xs, Some(multi))))
                scan(next)
              }
              2 => {
                stmts.push(SetS(local_(a), CallE(local_e(a), xs, Some(multi))))
                scan(next)
              }
              _ => {
                let ys : Array[Local] = []
                for y in a..<=(a + c - 2) {
                  ys.push(local_(y))
                }
                stmts.push(SetMultiS(ys, CallM(local_e(a), xs, Some(multi))))
                scan(next)
              }
            }
          }
          [{ op: TAILCALL, a, b: 0, }, ..] => {
            let xs : Array[Expr] = []
            if a + 1 < base {
              for x in (a + 1)..<base {
                xs.push(local_e(x))
              }
            }
            ReturnT([], Some(CallM(local_e(a), xs, Some(multi))))
          }
          [{ op: RETURN, a, b: 0, }] => {
            let xs : Array[Expr] = []
            if a < base {
              for x in a..<base {
                xs.push(local_e(x))
              }
            }
            ReturnT(xs, Some(multi))
          }
          [{ op: SETLIST, a, b: 0, c: 0, }, { op: EXTRAARG, ax: c, }, .. next]
          | [{ op: SETLIST, a, b: 0, c: 1..<_ as c, }, .. next] => {
            let xs : Array[Expr] = []
            if a + 1 < base {
              for x in (a + 1)..<base {
                xs.push(local_e(x))
              }
            }
            stmts.push(
              SetListS(
                local_e(a),
                ConstE(Integer(((c - 1) * LFIELDS_PER_FLUSH).to_int64())),
                xs,
                Some(multi),
              ),
            )
            scan(next)
          }
          _ => panic()
        }
      }

      let term = scan(code[start_pc:end_pc])
      let block : Block = { stmts, term, }
      blocks[Label(pc=start_pc)] = block
    }

    for i = 0; i < stops.length() - 1; i = i + 1 {
      let pc = stops[i]
      let end_pc = stops[i + 1]
      add_block(pc, end_pc)
    }

    blocks
  }

  let params : Array[Local] = []
  for i in 0..<proto.param_count {
    params.push(local_(i))
  }

  {
    index: proto.index,
    params,
    upvalues,
    vararg: proto.vararg,
    blocks,
    entry: Label(pc=entry_pc),
  }
}

///|
pub fn from_bc(chunk : @bc.Chunk) -> Program {
  let upvalues_table : Map[@bc.ProtoIndex, Array[Local]] = Map([])
  let items = [(chunk.main, [Local::env()])]
  while items.pop() is Some((proto, upvalues)) {
    let func_id : FuncId = { index: proto, }
    upvalues_table[proto] = upvalues
    let proto = chunk.protos[proto]
    for child in proto.protos {
      let child_proto = chunk.protos[child]
      let child_upvalues : Array[Local] = []
      for up in child_proto.upvalues {
        if up.on_stack {
          child_upvalues.push({ func: func_id, slot: up.index, })
        } else {
          child_upvalues.push(upvalues[up.index])
        }
      }
      items.push((child, child_upvalues))
    }
  }
  let funcs = chunk.protos.map(proto => {
    func_from_proto(proto, upvalues=upvalues_table[proto.index])
  })
  { funcs, main: { index: chunk.main, }, }
}
