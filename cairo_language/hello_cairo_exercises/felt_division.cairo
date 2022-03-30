%builtins output

from starkware.cairo.common.serialize import serialize_word

func main{output_ptr : felt*}():
  serialize_word(6 / 3)
  serialize_word(7 / 3)
  serialize_word((7 / 3) * 3)
  return ()
end
