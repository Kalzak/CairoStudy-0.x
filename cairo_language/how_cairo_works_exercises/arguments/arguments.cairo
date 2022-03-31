func main(): 
  let args = cast(ap, foo.Args*)
  args.new_x = 4; ap++
  args.new_y = 5; ap++
  static_assert args + foo.Args.SIZE == ap
  let foo_ret = call foo
  ret
end

func foo(new_x, new_y) -> (z, w):
  [ap] = new_x + new_y; ap++  # z
  [ap] = new_x * new_y; ap++  # w
  ret
end
