A simple main function first
```
%builtins output

from starkware.cairo.common.serialize import serialize_word

func main{output_ptr : felt*}():
  serialize_word(1234)
  serialize_word(4321)
  return ()
end
```
There are a few new components here
  - The function `main()`
    - The `main()` function is the starting point of the Cairo program
  - The builtin directive and the output builtin
    - The directive `%builtins output` instructs the Cairo compiler that the program will use the "output" builtin
    - The output builtin is what allows the program to communicate with the external world
      - Equivalent to pythons `print()`
    - As with all builtins, no special instructions in Cairo to use them
      - Communication with the builtin is doen by reading/writing values to memory
    - The output builtin is quite simple
      - Declaring it while using `%builtins` turns the signature of `main()` to `main{output_ptr : felt*}()
      - The syntax `{output_ptr : felt*}` declares an "implicit argument"
        - This means that behind the scenes it adds a correspending argument and return value
    - The argument points to the beginning of the memory segment to which the program output should be written
      - The program should then `return` a pointer that marks the `end` of the output
      - The convention used in Cairo is that the end of a memory segment always points to the memory cell _after_ the last written cell
  - The function `serialize_word()`
    - To write the value `x` to the output we can use the library function `serialize_word(x)`
    - It takes
      - One argument (the value we want to write)
      - One implicit argument `output_ptr` (which means that behind the scenes it also returns one value)
    - This is what it does
      - Writes `x` to the memory cell pointed by `output_ptr` (ie `[output_ptr]`) and returns `output_ptr + 1` (implicitly I think)
    - This is when the implicit argument mechanism kicks in
      - In the first call to `serialize_word()` the Cairo compiles passes the value of `output_ptr` as the implicit argument
      - In the second call it uses the value returned by the first call (and this can go on and on)
  - Import statements
    - The line `from starkware.cairo.common.serialize import serialize_word` tells the compiler to
      - Compile the file `starkware/cairo/common/serialize.cairo`
      - Expose the identifier `serialize_word`
    - You can use `... import serialize_word as foo` to choose a different name

Running the code
  - `cairo-compile array_sum.cairo --output array_sum_compiled.json`
  - `cairo-run --program=array_sum_compiled.json --print_output --layout=small`
    - The `--layout` flag is needed because we're using the output builtin, which is not available in the plain layout

Using array\_sum()
``
builtins output

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.serialize import serialize_word

func array_sum(arr, size) -> (sum):
  # ...
end

func main{output_ptr : felt*}():
  const ARRAY_SIZE = 3

  # Allocate an array.
  let (ptr) = alloc()

  # Populate some values in the array.
  assert [ptr] = 9
  assert [ptr + 1] = 16
  assert [ptr + 2] = 25

  # Call array_sum to compute the sum of the elements.
  let (sum) = array_sum(arr=ptr, size=ARRAY_SIZE)

  # Write the sum to the program output.
  serialize_word(sum)

  return ()
end`
```
Here are some new things
  - Memory allocation
    - We use the standard library funcion `alloc()` to allocate a new memory segment
    - In practice the exact location of the allocated memory will be determined only when the program terminates
      - This allows us to avoid specifying the size of the allocation
  - Constants
    - A constant in Cairo is defined using `const CONST\_NAME = <expr>` where
      - `<expr>` must be an integer (a field element to be precise) known at compile time
