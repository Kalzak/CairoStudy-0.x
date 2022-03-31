# Kalzaks condensed Cairo notes
Sections
  - cairo intro
  - debugging-related flags
  - the program counter (`pc`)
  - consts and references
  - functions
## cairo intro
### field elements
  - The basic datatype is Cairo is a field element
  - It is an integer in the range `0 <= x < P` where `P` is a prime number
  - In modern CPUs the basic datatype is a 64 bit integer (we can think of this as doing computations as modulo `2^64`
    - Think how `-17` is represented as `2^64 - 17`
    - Think how `(2^63) * 2` gets you `0`
  - In Cairo all computations are done in modulo `P`
  - Because of this there are some cases where working modulo `P` requires caution
    - Division
      - In regular CPUs integer division `x/y` is defined as `⌊x/y⌋`, so `7/2 == 3`
      - In Cairo the result of `x/y` must satisfy `(x/y)*y == x`
        - If `y` divides `x` as integers you will get expected result (eg `6/2 == 3`)
        - When `y` does not divide `x` it's very different
        - _I should come back to this to fully understand the math_
    - Checking if value is even
      - In regular CPU if you take value `x` and multiply it by `2` result is always even
      - Not in Cairo
      - _Reason is related to the math in the division section_

### non deterministic computation
  - The goal of a Cairo program is to prove that some computation is correct
  - We can take some shortcuts
  - Consider this example
    - We want to prove that the square root of `x = 961` is in the range of `0,1,...,100`
    - The result of the square root is `y`
    - Direct approach is to write code that starts from 961, computes root, verifies its within range
    - We can do something much easier
      - Show that if we start with `31` and square it we get `961`
      - Then we just verify that `31` is in the range
      - Instead of starting with the input (`961`) we can start with the solution (`31`)
      - This is called non deterministic computation
    - The psuedocode would be the following
      - Magically guess the value of `y` (this is the non deterministic part)
      - Compute `y^2` and make sure it's equal to `x`
      - Verify `y` is in the range
  - This can be used in _hints_ and _nondeterministic jumps_

### memory model
  - Cairo supports a read-only non deterministic memory
  - Means that the value for each memory cell is chosen by the prover, but it cannot change during program execution
  - The syntax `[x]` is used to represent that value of the memory at address `x`
  - You can write a value to a memory cell once and cannot change after
  - Therefore we can interpret `[0] == 7` as either of the following (depending on whether memory cell `0` has been set)
    - Read the value from the memory cell at address `0` and verify that it is `7`
    - Write the value `7` to that memory cell

### registers
  - The only values that can change over time are held within designated registers
  - `ap` (allocation pointer)
    - Points to a yet-unused memory cell
  - `fp` (frame pointer)
    - Points to the frame of the current function
    - Addresses of the function's arguments and local variables are relative to the value of this register
    - On function start it is equal to `ap`, but unlike `ap` the value of `fp` remains the same through the function scope
  - `pc` (program counter)
    - Points to the current instruction

### basic instructions
  - A simple Caino instruction takes the form of an assertion for equality
  - EG: `[ap] = [ap - 1] * [fp]; ap++`
    - States that the product of two memory cells (`[ap - 1]` and `[fp]`) must be the same as the value of the next unused cell (`[ap]`)
    - This is like "writing" the product of the two values into `[ap]`
    - The suffix `ap++` tells Cairo to increase `ap` by one _after_ performing the instruction (since that memory slot was taken up)
      - If you want to change `ap` in any other way besides `ap++` you have to use `ap += ...`
    - `ap++` is not an instruction on its own, it is part of the instruction before the semicolon
      - Semicolon syntax is unique to `ap++` and cannot be used to separate two instructions unlike languages like C++
  - This list demonstrates valid assert-equal instructions in Cairo
    ```
    [fp - 1] = [ap - 2] + [fp + 4]
    [ap - 1] = [fp + 10] * [ap]; ap++
    [ap - 1] = [fp + 10] + 12345; ap++  # See (note1) below
    [fp + 2] = [ap + 5]
    [fp + 2] = 12345
    [ap + 2] = [[ap + 5]]               # See (note2) below
    [ap] = [fp - 3] - [ap + 4]          # See (note3) below
    [ap] = [fp - 3] / [ap + 4]          # See (note3) below
    ```
    - _note1_: There are two types of integers that may appear in an instruction as either of the two following
      - Immediates, which can be used in two ways
        - Second operands in a given operation
          - EG: `12345` in `[ap - 1] = [fp + 10] + 12345`
        - Standalone value for assignment
          - EG: `[fp + 2] = 12345`
      - Offsets, which appear inside brackets
        - EG: `5` in `[ap + 5]` or `-3` in `[fp - 3]`
      - An immediate can be any field element
      - An offset in limited to the range `[-2^15, 2^15)`
        - Note the difference in brackets
          - `[`,`]` means greater/less than or equal to (for the beginning/end in the set)
          - `(`,`)` means greater/less than (for the beginning/end in the set)
        - This is the equivalent to `-2^15 >= x > 2^15` where `x` is the offset
    - _note2_: The instruction `[ap + 2] = [[ap + 5]]` is a double dereference instruction
      - The value of `[ap + 5]` is treated as a memory address to then be dereferenced to find another value
    - _note3_: These instructions are syntactic sugar
      ```
      [ap] = [fp - 3] - [ap + 4]
      # Is replaced by
      [fp - 3] = [ap] + [ap + 4]
      ```
      ```
      [ap] = [fp - 3] / [ap + 4]
      # Is replaced by
      [fp - 3] = [ap] * [ap + 4]
      ```
      - What's happening here is the statement is being rearranged to not use subtraction or division

### Continuous memory
  - Cairo has a technical requirement that memory addresses accessed by a program must be continuous
    - EG: If addresess `7` and `9` are accessed, then `8` must also be accessed before the end of the program
      - The order of access doesn't matter however
  - If small gaps are in the address range then prover automatically fills those addresses with arbitrary values
  - Having gaps is inefficient (memory is being consumed without being used)
  - Too many gaps could make the generation of a proof too expensive for an honest prover to perform

## debugging-related flags
  - These are flags for `cairo-run` to help debug errors
  - Besides these you can also use hints to print a certain identifier or memory cell
  - `--print_info`
    - Instructs `cairo-run` to print the info section which contains the following
      - Number of executed steps
      - Number of used memory celly
      - Values of the registers at end of execution
      - Segment relocation table
  - `--print_memory`
    - Prints the addresses and values of the memory cells that were assigned during execution
  - `--steps`
    - Can control the number of steps that `cairo-run` performs using this flag
    - Is an optional parameter, if not specified `cairo-run` will run until end of program
  - `--no-end`
    - When using `--steps` if the program does not end in your given amount of steps `cairo-run` will throw an error
      - `End of program was not reached`
    - Can instruct `cairo-run` to ignore this using `--no_end` flag
  - `--debug_error`
    - When an error occurs the memory and info sections are not printed by default
    - Can use this flag to print them anyways
  - `--profile_output profiles.pb.gz`
    - Outputs a profile result file that can be viewed with [pprof](https://github.com/google/pprof)

## the program counter
### program counter and jumps
  - Program is stored in memory where each instruction takes 1 or 2 field elements
    - An example of an instruction that takes two field elements is when an immediate value is used in the instruction
      - One field element for the instruction
      - One field element for the immediate value
  - The program counter (`pc`) keeps the address of the current instruction
  - Usually advances by 1 or 2 per instruction (depending on size of instruction)
  - A `jmp` instruction can be used to jump to different instruction
  - `jmp` has 3 flavors
    - _Absolute jump_
      - Jumps to a given address (by changing `pc` to the given value)
      - EG: `jmp abs 17` changes `pc` to `17`
    - _Relative jump_
      - Jumps to an offset from the current instruction
      - EG: `jmp rel 17` changes `pc` to `pc + 17`
      - Note that `pc` points to the current instruction, therefore using `jmp rel 0` you can have an infinite loop
    - _Jump to a label_
      - Cairo compiler calculates the difference between the current instruction and the label and turns it into a relative jump
      - Is the most useful and readable jump

### conditional jumps
  - Syntax is `jmp <label> if [<expr>] != 0`
    - `<expr>` is either `ap + offset` or `fp + offset`
      - Offset can be omitted if `ap`/`fp` are already in the right place
  - If the corresponding memory cell is not zero, the Cairo machine will jump to the given label
  - Otherwise it will continue to the next instruction
  - If you don't want to use a label to jump you can use a relative jump
    - EG: `jmp rel 17 if [ap - 1] != 0`

## consts and references
### consts
  - Cairo supports defining constant expressions (only integers)
    - For example
      ```
      const value = 1234
      [ap] = value
      ```
      is equivalent to
      ```
      [ap] = 1234
      ```
    - In the first code block the compiler will just replace `value` with `1234` 

### short string literals
  - A short string is a string whose length is at most 31 characters (i.e: fits in a field element)
    - `[ap] = 'hello'` is same as `[ap] = 0x68656c6c6f`
  - Rememeber that it's still really just a field element and not a real string
  - Cairo doesn't support strings currently
    - When it does they will be wrapped with `"` instead of `'`
  - The strings first character is the most significant byte of the integer (big endian)

### references
  - Can be hard to follow progress of the `ap` register
  - Instead of having to keep track of `ap` and rememeber how many memory slots "back" you need to go you can
    ```
    let x = ap
    [x] = 3; ap++

    # lots of code here which means if you want to reference the `ap` above you'd have to do [ap - 17]

    [ap] = [ap - 1] + [x]; ap++
    ```
  - The `let` syntax defines a reference and the code compilation calculates how many memory slots "back" to go
  - The compiler tracks the progress of the referenced `ap` register and substitutes `x` accordingly
  - References can hold any Cairo expression
    ```
    let x = [[fp + 3] + 1]
    [ap] = x  # This compiles to [ap] = [[fp + 3] + 1]
    ```

### assert statement and compound expressions
  - An expression that involves more than one operation (EG: `[ap] * [ap] * [ap]`) is called a compound expression
  - The Cairo compiler supports the following syntax to allow asserting the _equality_ between values of two compound expressions
    ```
    assert <compound-expr> = <compound-expr>
    
    # In use
    let x = [ap - 1] 
    let y = [ap - 2] 
    assert x * x = x + 5 * y
    ```
  - Such statements are usually compiled to more than one instruction and `ap` may advance an unknown number of steps
  - Therefore should avoid using `ap` and `fp` directly in such expressions
    - Try to use temporary/local variables ore references instead

### revoked references
  - If you define a reference that depends on `ap` and then use a label or call instruction the reference may be revoked
  - Compiler may not be able to compute the change of `ap` as it may be changed in an unknown way in the label jump or function call
  - References that do not depend on `ap` (EG: `let x = [[fp]]` are never revoked by the compiler)
    - Same rule applies however, using references outside of their function scope may result in undefined behavior

### typed references
  - You can define a struct with the following syntax
    ```
    struct MyStruct:
      member x : felt
      member y : felt
      member z : felt
    end
    ```
  - `felt` stands for field element, the primitive type in Cairo
  - The compiler automatically computes the offset from the beginning of the struct
    - EG: `MyStruct.x = 0`, `MyStruct.y = 1`, `MyStruct.z = 2`
  - You can also get the total size of a struct with `MyStruct.SIZE` which returns the total memory size
    - In the given example above the size would be 3
  - Let's say you have a `MyStruct` at register `fp`
    ```
    let ptr : MyStruct* = cast([fp], MyStruct*)
    assert ptr.y = 10
    # ptr.y will compile to [ptr + MyStruct.y]
    # which will then compile to [[fp] + 1] 
    ```
  - You don't need to define the type (`MyStruct*`) and the Cairo compiler can deduce the type from the RHS
    - But probably better readability wise to explicitly state it anyways

### casting
  - Every expression has an associated type
  - Cairo supports types such as
    - Field element (`felt`)
    - Pointers
    - Structs
  - You can change the type of an expression using `cast(<expr>, <type>)` where `<type>` can be
    - `felt` (for a field element)
    - `T` (for a struct `T`)
    - A pointer to another type (Such as `T*` or `felt**`)

### temporary variables
  - Cairo supports the following syntactic sugar which allows defining temporary variables
    ```
    tempvar var_name = <expr>
    ```
  - For simple expressions with at most one operation this is equivalent to
    ```
    [ap] = <expr>; ap++
    let var_name = [ap - 1]
    ```

### local variables
  - Local variables are based on the `fp` register
    - This is unlike temporary variables which are based on the `ap` register 
    - This means that temporary variables can be revoked (because it's based on `ap`) and local variables cannot
  - In the scope of a function, first local variable would reference to `[fp + 0]`, the second would be `[fp + 1]` and so on
  - Local variables do not increment `ap` automatically like temporary variables do
    - You have to increment `ap` yourself
    - This can be done by using the contstant `SIZEOF_LOCALS` that the compiler generates
    - `SIZEOF_LOCALS` is equal to the accumulated size (of cells) of locals within the same scope.
    - EG
      ```
      func main():
        ap += SIZEOF_LOCALS
        local x   # x will be a reference to [fp + 0]
        local y   # y will be a reference to [fp + 1]

        x = 5
        y = 7
        ret
      end
      ```
  - Cairo also provides the instruction `alloc_locals` which is transformed to `ap += SIZEOF_LOCALS`
  - Local variables can have a type just like a reference
    - `felt` is the default type if another type isn't specifically set
    - The type is _not_ deducted from the type of initialization value

### typed local variables
  - You can specify a type for the local variable in two different ways
    ```
    local x : T* = <expr>
    local y : T = <expr>
    ```
  - First one allocates a cell which is a pointer to a struct of type `T`
    - Therefore `x.a` is equivalent to `[[fp + 0] + T.a]`
  - Second one allocated `T.SIZE` cells from `fp` (well, `fp + 1` in the shown example)
    - Therefore `y.a` is equivalent to `[fp + 1 + T.a]`, notice that we aren't dereferencing this time because it's not a pointer

### reference rebinding
  - Cairo allows you to define a reference with the name of an existing reference
    ```
    let x : T* = cast(ap, T*)
    x.a = 1

    # ...

    # Rebind x to the address fp + 3 instead of ap
    let x : T* = cast(fp + 3, T*)
    x.b = 2
    ```

### tuples
  - Tuples allow convenient referencing of an ordered collection of elements
  - Tuples consist of any combination of valid types including other tuples
  - They are represented as a comma-separated list of elements enclosed in parentheses
    - EG: `(3, x)`
  - Consider the following assert statement
    ```
    assert (x, y) = (1, 2)
    # The above statement compiles to
    assert x = 1
    assert y = 2
    ```
  - Tuple elements are accessed with the tuple expression followed by brackets containing a zero-based index to the element
    ```
    let a (7, 6 ,5)[2]  # let a = 5
    ```
    - The index must be known at compile time
  - Cairo requires a trailing comma for since element tuples EG: `(5,)`
  - Access to nested tuples is similar to nested arrays
    - `MyTuple[2][4][3][1]`

### arrays
  - Arrays can be represented with a pointer to the beginning of an array by using `alloc()` to allocate the memory
  - The expression `struct_array[n]` is used to access the `n`-th element of the array (zero indexed)
    - `struct_array[index]` is compiled to `struct_array + index * MyStruct.SIZE]` and is of type `MyStruct`

## functions
### introduction
  - A function is a reusable unit of code that receives arguments and returns a value
  - Two low-level instructions have been introduced to support this
    - `call addr`
    - `ret`
  - The Cairo compiler also supports high-level syntax for those instructions (listed respectively)
    - `foo(...)`
    - `return (...)`
  - A function is declared as follows
    ```
    func function_name():
      # Code here
      return ()
    end
    ```
    - Note that the lines `func function_name():` and `end` are not translated into Cairo instructions
      - They are just used by the compiler to name the function and create a corresponding scope
  - To call the function you can use the
    - Call instruction: `call function_name`
    - High-level syntax: `function_name()`
  - The full syntax of `call` is similar to `jmp` (to a label or relative, but not absolute)

### the fp register
  - When a function starts the frame pointer register `fp` is initialized to the current value of `ap`
  - During the entire scope of the function (excluding inner function calls) the value of `fp` remains constant
  - When a function `foo` calls an inner function `bar` the value of `fp` changes when `bar` starts but is restored when `bar` ends
  - The idea is that `ap` can change in unknown ways so we have `fp` to reliably access function local variables and arguments

### under the hood
  - `call addr` is roughly equivalent to the following set of instructions
    ```
    # Stores the value of the current fp, which will be restored once the called function ends using ret
    [ap] <-- fp

    # Stores the address of the next instruction, to run once the called function ends
    # This will be assigned to the pc when ret in invoked
    [ap + 1] <-- return_pc

    # Increase ap by 2, to account for the last two writes
    ap += 2

    # Updates fp to be the new ap, so it points to the start of the new frame within the called function's scope
    fp <-- ap

    jmp addr
    ```
  - `ret` is roughly equivalent to the following set of instructions
    ```
    # Jumps to return_pc (stored on the stack)
    jmp [fp - 1]

    # Restores the value of the previous fp
    fp <-- [fp - 2]
    ```
  - They can be summarized as 
    - `call` "pushes" the current frame pointer and return-address to a (virtual) stack of pairs (fp, pc) and jumps to given address
    - `ret` "pops" the previous `fp` and jumps to `return_pc` that were pushed during the call

### accessing the values of the registers
  - Cairo's standard library has two functions that allow to retrieve the values of the three registers
  - The can be used as follows
    ```
    from starkware.cairo.common.registers import get_ap
    from starkware.cairo.common.registers import get_fp_and_pc

    let get_ap_res = get_ap()
    tempvar my_ap = get_ap_res.ap_val

    let fp_and_pc = get_fp_and_pc()
    tempvar my_fp = fp_and_pc.fp_val
    tempvar my_pc = fp_and_pc.pc_val
    ```
  - When Cairo needs to use the _address_ fp in a compound expression it will try to replace it with a variable named `__fp__`
  - `__fp__` is assumed to contain the value of `fp`
  - Demonstration of getting `fp`
    ```
    local __fp__ = fp_and_pc.fp_val   # Getting the address of `fp` and putting it in `__fp__`
    tempvar x = fp                    # We can now store the address of `fp` (you need to run the above line for this to work)
    tempvar y = [fp]                  # This would have worked regardless of the above two lines
    ```

### function arguments and return values
  - The following is an example of a function which gets two values `x` and `y` and returns their sum `z` and product `w`
    ```
    func foo(x, y) -> (z, w):
      [ap] = x + y; ap++  # z
      [ap] = x * y; ap++  # w
      ret
    end
    ```

### arguments
  - Arguments are written to the "stack" before the `call` instruction
    - EG: To call `foo(4, 5)` you should write
      ```
      [ap] = 4; ap++  # x
      [ap] = 5; ap++  # y
      call foo
      ```
  - The instruction `call` pushes two more values to the stack (next `pc` and current `fp`)
    - Therefore when a function starts the arguments are available at `[fp - 3]`, `[fp - 4]`, ... (in reverse order)
  - For each argument the Cairo compiler 
    - Creates a reference `argname` to its value
    - Creates a constant `Args.argname` with its offset (0, 1, 2, ...)
  - Any usage of the reference `argname` is replaced by `[fp - (2 + n_args) + Args.argname]`
    - This way you can access the value of an argument named `x` by simply writing `x`
  - Cairo also supports the following syntactic sugar to call a function: `foo(x=4, y=5)`

### return values
  - The function writes to the stack its return values just before the `ret` instruction
    - Thus after the function call the return values will be available to the caller at `[ap - 1]`, `[ap - 2]` and so on
  - Example of using values returned by `foo`
    ```
    foo(x=4, y=5)
    [ap] = [ap - 1] + [ap - 2]; ap++  # Compute z + w
    ```
  - Cairo compiler automatically creates contants named `foo.Return.z` and `foo.Return.w` with the values `-1` and `-2` respectively
    - This means that `[ap - 1]` can be written as [ap + foo.Return.z]`
  - You can also define a typed reference as follows
    ```
    let foo_ret : foo.Return = ap`
    ```
    - Now you can access `z` as `foo\_ret.z`
    - In the case above `foo\_ret` is implicitly a reference to `ap` with type `foo.Return`

### return values unpacking
  - Cairo supports syntactic sugar to assign multiple return values to references via tuples
  - The syntax `let (z, w) = foo(x=4, x=5)` assigns `foo`'s return values to `z` and `w` respectively
    ```
    let (z, w) = foo(x=4, y=5)
    [ap] = z + w; ap++
    ```
  - In many cases you may want to copy the result to a local variable in order to prevent it from being revoked later
    - While you can add an instruction `local z = z` which rebinds the reference to a new local variable with the same 
    - You can do the same thing instead by doing
      ```
      let (local z, local w) = foo(x=4, y=5)
      [ap] = z + x; ap++
      ```
 
### named arguments
  - The compiler can warn about inconsistencies between the lists of arguments in the function definition and function call
  - EG: If function argument is added you may want an error if that argument was not passed when the function was called
  - Use the following pattern to produce the above alert
    ```
    let args = cast(ap, foo.Args*)
    args.x = 4; ap++
    args.y = 5; ap++
    # Check that ap was advanced the correct number of times
    # (this will ensure arguments were not forgotten)
    static_assert args + foo.Args.SIZE == ap
    let foo_ret = call foo
    ```
  - A bonus note is that you can pass the arguments in any order when using this method

### tail recursion
  - Using the approach above allows one to do tail recursion efficiently
  - Tail recursion is when a function ends by calling a second function and immediately returning the output of the inner function
  - Use the following pattern in this case
    ```
    call inner_func
    ret
    ```
  - The high level syntax equivalent of a tail call is
    ```
    return inner_func(x=4, y=5)
    ```

### return tuple
  - Cairo supports the following syntactic sugar which allows returning values from a function easily
    ```
    func foo() -> (a, b):
      return (<expr0>, b=<expr1>)
    end
    ```
  - This is equivalent to
    ```
    func foo() -> (a, b):
      [ap] = <expr0>; ap++
      [ap] = <expr1>; ap++
      ret
    end
    ```
  - Named return arguments are checked against declared return type
  - Compound expressions are supported in return values

## types
### tuples
  - A tuple type is defined similarly to a tuple expression
  - EG: Given two types `a` and `b`, the type `(a, b)` represents a tuple that contains two elements `a` and `b` respectively
  - EG: `(felt, felt)` may be used to represent a two dimensional point

### used-defined type aliases
  - You can give a new alias for a type as follows: `using Point = (x : felt, y : felt)`
  - Note that `Point` is not a new type in this case
    - It is only an alias to `(x : felt, y : felt)`
  - Example
    ```
    local pt : (x : felt, y : felt) = (x=2, y=3)
    # You can replace the above with
    local pt : Point = (x=2, y=3)
    ```
