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
    - Now you can access `z` as `foo_ret.z`
    - In the case above `foo_ret` is implicitly a reference to `ap` with type `foo.Return`

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

## object allocation
  - Cairo has a few ways of storing an object in memory and getting a pointer to it (which can be used in other functions)
    - Memory segment allocation
      - The `alloc()` function can be used to create an arbitrary length array
    - Single item allocation
      - The `new` operator initializes a single item and returns a pointer to it
    - Local variables
      - You can allocate a local variable and retrieve its address

### alloc()
  - The standard library function `alloc()` may be used to "dynamically" allocate a new memory segment
  - This segment can be used to store an array or a single element
  - Shown example
    ```
    from starkware.cairo.common.alloc import alloc

    func foo():
      let (struct_array : MyStruct*) = alloc()

      # Set the first three elements
      assert struct_array[0] = MyStruct(a=1, b=2)
      assert struct_array[1] = MyStruct(a=3, b=4)
      assert struct_array[2] = MyStruct(a=5, b=6)
      return ()
    end
    ```

### the "new" operator
  - The `new` operator takes an expression and pushes it onto the stack and returns a pointer to memory address of that object
  - Shown example
    ```
    func foo():
      tempvar ptr : MyStruct* = new MyStruct(a=1, b=2)
      assert ptr.a = 1
      assert ptr.b = 2
      return ()
    end
    ```
  - Unlike `alloc()` (which allocates a new memory segment) the `new` operator creates the object in the execution segment
  - Since memory on Cairo is never freed both applications have a similar outcome: You can use the pointer even after the function ends
  - Since the object is created in the execution segment it can't be used for arbitrary sized arrays
  - The `new` operator is useful because you can allocate the memory and initialize the object in one instruction
  - Can use multiple `new` operators in the same line
  - You can use `new` to allocate a fixed-size array using tuples
    ```
    func foo():
      tempvar arr : felt* = new (1, 1, 2, 3 ,5)
      assert arr[4] = 5
      return ()
    end
    ```
  - For arrays of structs you need to explicitly cast the pointer 
    ```
    func foo(): 
      tempvar arr : MyStruct* = cast(new (MyStruct(a=1, b=2), MyStruct(a=3, b=4)), MyStruct*)
      assert arr[1].a = 3
      return ()
    end
    ```

## scope attributes
  - You can define an attribute as a code block by surrounding it with a `with_attr` statement as follows
    ```
    with_attr attribute_name("Attribute value"):
      # Code block
    end
    ```
  - The attribute value must be a string and can refer to local variables only
    - Referring to a variables is done like this: `"x must be positive. Got: {x}."`
  - Currently only one attribute is supported by the Cairo runner: `error_message`
    - It allows user to annotate a code block with an error message
    - The error message (attribute value) will be added to the trace in the case of an error inside the attribute

## imports
  - For readability and modularity you can import instead of having everything in one source file
  - Cairo allows importing from another file with the following syntax
    ```
    from a.b import c as d
    ```
    - Will search for a Cairo module `a.b` and import `c` from it, binding `c` to the name `d` in this module
    - The `as` clause is optional, if not used then you simply refer to `c` as `c`

### import search paths
  - When Cairo looks for the module `a.b` in the example above it will
    - Search for file `a/b.cairo` in the paths it has been configured to search
      - The paths searched are taken from a colon-separated list that can be set in two ways
        - The `--cairo_path` argument to the compiler
        - The environment variable `CAIRO_PATH`
      - If you wanted to add `/home/cairo_libs` and `/tmp/cairo_libs` then you will do either of the following
        - `cairo-compile --cairo_path="/home/cairo_libs:/tmp/cairo_libs" ...`
        - `CAIRO_PATH="/home/cairo_libs:/tmp/cairo_libs"` followed by `cairo-compile`
  - Compiler will also search the current directory and the standard library directory relative to the compiler path
  - Compiler will automatically detect and fail on
    - Cyclic imports
    - Multiple imports sharing same name in a single Cairo file

## hints
### introduction
  - Cairo supports nondeterministic instructions
    - EG: To compute the root of 25 one may write
      ```
      [ap] = 25; ap++
      [ap - 1] = [ap] * [ap]; ap++
      ```
    - This expression is fine for the verifier but the prover cannot handle (value could be `-5` or `5`)
      - So we have to tell the prover what to do in order to compute the root
    - This is done by adding "hints"
  - A hint is a block of Python code that will be executed by the prover right before the next instruction
  - The format is as follows
    ```
    [ap] = 25; ap++
    %{
      import math
      memory[ap] = int(math.sqrt(memory[ap - 1]))
    }%
    [ap - 1] = [ap] * [ap]; ap++
    ``` 
    - To access [ap] in the hint we use the syntax `memory[ap]`
    - To access a Cairo constant `x` in a hint you use the expression `ids.x`
      - Function arguments and references can be accessed in the same way
  - Note that a hint is attached to the next instruction and is executed _before each execution_ of the corresponding instruction
    - EG:
      ```
      %{ print("Hello world!") }%
      jmp rel 0
      ``` 
      - This would print `Hello world!` infinitely (rather than just printing once and then starting the infinite loop)

## program input and output
  - A Cairo program may have a secret input (called "program input") and a public output (called "program output")
  - Use case
    - You want to prove you know the pre-image of a hash function (that is, `x` such that `hash(x) = y` for a given `y`)
    - Input is your secret `x`
    - Program computes the hash of your input
    - Program outputs result, and since Cairo output is public everyone who gets the proof will be convinced that you know the pre-image
  - Note that sometimes part of the program input needs to be in output to be a good proof
    - EG: Proving "I know the n-th Fibonacci number is Y"
    - Program input in this case in `n` and output will be `n` and `Y` because the verifier has to see what `n` is
    - Without it, people will just see a proof "I know that some Fibonacci number if `Y`"

### program input
  - To add program to a Cairo program you create a `json` file with your program input
    ```
    {
      "secret": 1234
    }
    ```
  - In your Cairo code you can refer to the secret with a hint
    ```
    func main():
      %{ memory[ap] = program_input['secret'] %}
      [ap] = [ap]; ap++
      ret
    end
    ```
  - Then pass it to `cairo-run` using the `--program_input` flag
  - Then you can use hints to access the content of this file using the variable `program_input`
    - Recall that hints are only visible to the prover

### program output
  - Start by adding the following directive to the top of your file: `%builtins output`
  - You need to run your program with a different layout to use the `output` builtin
    - Add `--layout=small` to `cairo-run`
    - Using the `small` layout requires the number of steps to be divisible by 512
    - That means you have to specify the number of steps, for small programs 512 will suffice
  - The `%builtins output` directive makes the `main()` function get one argument and return one value
    - The argument is conventionally called `output_ptr`
      - Program should use it as a pointer to a block of memory to which it may write its outputs
    - `main()` should return the value of the pointer after writing, signifying where the chunk of output memory ends
  - The following program writes three contant values to output
    ```
    %builtins output

    func main(output_ptr) -> (output_ptr):
      [ap] = 100
      [ap] = [output_ptr]; ap++

      [ap] = 200
      [ap] = [output_ptr + 1]; ap++

      [ap] = 300
      [ap] = [output_ptr + 2]; ap++

      # Return the new value of output_ptr, which was advanced by 3
      [ap] = output_ptr + 3; ap++
      ret
    end
    ```
  - Remember that `output_ptr` is the address while `[output_ptr]` is the value it points to

## segments
### rationale
  - The memory of a Cairo program has to be continuous
    - However some parts of the program may be invididually continuous but vary in length in ways that are only computed at runtime
      - Their size can only be known after the program terminates
  - For this purpose during the run of the Cairo VM it's useful to treat the memory as a list of continous segments
    - These segments are concatenated to form one continuous chunk at the end of the run, only once their final sizes are calculated

### relocatable values
  - The absolute address of every memory cell within a segment can only be determined at the end of a VM run
  - Because these addresses can be stored in memory cells themselves, the VM needs a way to refer to them
  - This is achieved with _relocatable values_, represented as `<segment>:<offset>` where
    - `<segment>` is the segment number, assigned arbitrarily at the start of the run
    - `<offset>` is the offset of the memory cell within the segment
  - Note that because segment numbers are assigned arbitrarily, the number is not guaranteed to represent the same segment
    - This even applies for multiple runs in the same program, you will still find different segment numbers

### segment use - program and execution segments
  - Cairo programs themselves are kept in memory, in what is called the "program segment"
    - This segment is of a fixed length and contains the numeric representation of the Cairo program
    - The program counter `pc` starts at the beginning of the program segment
  - In addition to this, any Cairo program requires an "execution segment"
    - This is where
      - The registers `ap` and `fp` start
      - Where data generated during the run of a Cairo program (variables, return addresses for function calls, etc) is stored
  - The length of the execution segment is variables as it can depend on factors such as the program input

### segment use - builtin segments
  - Every builtin receives its own continuous area in memory
  - This memory is located in its own segment which is variable in length

## nondeterministic jumps
  - There is a code pattern called "nondeterministic jumps" that combines conditional jumps and hints
  - A nondeterministic jump is a jump instruction that may or may not be executed
    - The decision to execute the jump will be done according to the __provers__ decision
      - Decision is the provers rather than according to a condition on values which were computed before
  - To do this use the Cairo instruction
    ```
    jmp label if [ap] != 0; ap++
    ```
  - The idea is to use an unused memory cell (`[ap]`) to decide whether or not to jump
    - Don't forget to increment `ap` to make sure the following instructions don't use this memory cell
  - As with every nondeterministic instruction a hint must be attached to let the prover know whether to jump or not
    - EG:
      ```
      %{
        memory[ap] = 1 if x > 10 else 0
      %}
      jmp label if [ap] != 0; ap++
      ```
  - The prover cannot be trusted, so you should have an assert to make sure that the result of hints done by the prover is what you want
  - Then the verifier can check your assert statement and ensure that the prover has done the right thing

## builtins and implicit arguments
### introduction
  - Builtins are predefined optimized low-level execution units which are added to the Cairo CPU board
    - They perform predefined computations which are expensive to perform in vanilla Cairo, EG
      - Range checks
      - Pedersen hash
      - ECDSA
      - and more
  - Communication between CPU and builtins is done via memory
    - Each builtin is assigned a continuous area in the memory and applies some constraints on the memory cells in that area
      - These constraints depend on the builtin definition
    - EG: The Pedersen builtin will enforce that
      ```
      [p + 2] = hash([p + 0], [p + 1])
      [p + 5] = hash([p + 3], [p + 4])
      [p + 8] = hash([p + 6], [p + 7])
      ...
      ```
  - Cairo code may read/write from those memory cells to "invoke" the builtin
  - The following code verifies that `hash(x, y) == z`
    ```
    # Write the value of x to [p + 0]
    x = [p]
    # Write the value of y to [p + 1]
    y = [p + 1]
    # The builtin enforces that [p + 2] == hash([p + 0], [p + 1])
    z = [p + 2]
    ```
  - Once we use the addresses `[p + 0]`, `[p + 1]`, `[p + 2]` to calc first hash we can't use them again to compute a different hash
    - This is because Cairo memory is immutable
  - Instead we should use `[p + 3]`, `[p + 4]`, `[p + 5]` and so on
    - This means that we have to keep track of a pointer to the next unused builtin instance
  - The convention is that functions which use the builtin should get that pointer as an argument
    - They should also return an updated pointer to the next unused instance
  - A more complete example of the example above would look like this:
    ```
    func hash2(hash_ptr, x, y) -> (hash_ptr, z):
      # Invoke the hash function
      x = [hash_ptr]
      y = [hash_ptr + 1]
      # Return the updated pointer (increased by 3 memory cells) and the result of the hash
      return (hash_ptr=hash_ptr + 3, z=[hash_ptr + 2])
    end
    ```
  - Note how `hash_ptr` is now being used, so `x` and `y` are being set in the builtin memory area
  - We can use typed references with the type `HashBuiltin` from `starkware.cairo.common.cairo_builtins` as follows
    ```
    from starkware.cairo.common.cairo_builtins import HashBuiltin

    func hash2(hash_ptr : HashBuiltin*, x, y) -> (hash_ptr : HashBuiltin*, z):
      let hash = hash_ptr
      # Invoke the hash function
      hash.x = x
      hash.y = y
      # Return the updated pointer (increased by 3 memory cells) and the result of the hash
      return (hash_ptr=hash_ptr + HashBuiltin.SIZE, z=hash.result)
    end
    ```
### implicit arguments
  - If a function `foo()` calls `hash2()`
    - `foo()` must also get and return the builtin pointer `hash_ptr` and so does every every function calling `foo()`
  - Since this pattern is so common Cairo has syntactic sugar for it called "Implicit arguments"
  - See the following implementation of `hash2` (note the function declaration in particular)
    ```
    from starkware.cairo.common.cairo_builtins import HashBuiltin

    func hash2{hash_ptr : HashBuiltin*}(x, y) -> (z):
      # Create a copy of the reference and advance hash_ptr
      let hash = hash_ptr
      let hash_ptr = hash_ptr + HashBuiltin.SIZE
      # Invoke the hash function
      hash.x = x
      hash.y = y
      # Return the result of the hash
      # The updated pointer is returned immediately
      return(z=hash.result)
    end
    ```
  - The curly braces `{}` declare `hash_ptr` as an _implicit argument_
  - This automatically adds an argument __and__ and return value to the function
    - If you're using the high level `return` statement you don't have to explicitly return `hash_ptr`
    - Note that since `hash2()` has to return a pointer to the next available instance, reference rebinding used on `hash_ptr`

### calling a function that gets implicit arguments
  - Cairo's standard library includes `hash2` in the module `starkware.cairo.common.hash`
  - You can call `hash2()` in a few ways
    - Explicitly, using `{x=y}` where `x` is the name of the implicit argument and `y` is the name of the reference to bind to it
      - The word "bind" is used since `y` is not merely passed to `foo`
      - After the call, `y` will be rebound to the value returned by `foo` for the implicit argument
      ```
      from starkware.cairo.common.cairo_builtins import HashBuiltin
      from starkware.cairo.common.hash import hash2
  
      func foo{hash_ptr0 : HashBuiltin*}() -> (z):
        let (z) = hash2{hash_ptr=hash_ptr0}(1, 2)
        # The previous statement rebinds the value of hash_ptr0
        # If hash_ptr0 were used here, it would have referred to the updated value rather than foo's argument
        return (z=z)
      end
      ```
    - Implicitly, if the calling function also has an __implicit__ argument named `hash_ptr`
      ```
      from starkware.cairo.common.cairo_builtins import HashBuiltin
      from starkware.cairo.common.hash import hash2

      func foo{hash_ptr : HashBuiltin*}() -> (z):
        let (z) = hash2(1, 2)
        # The previous statement rebinds the value of hash_ptr
        # If hash_ptr were used here, it would've referred to the updated value rather than foo's argument
        return (z=z)
      end
      ```
      - Trying to use `hash(2, 1)` will fail in the following conditions
        - There is no reference named `hash_ptr`
        - The `hash_ptr` reference is not an implicit argument (or marked uising a `with` statement as you'll see below)
    - Implicitly, inside a `with` statement on a reference named `hash_ptr`
      ```
      from starkware.cairo.common.cairo_builtins import HashBuiltin
      from starkware.cairo.common.hash import hash2

      func foo(hash_ptr : HashBuiltin*) -> (hash_ptr : HashBuiltin*, z):
        # Use a with-statement, since hash_ptr is not an implicit argument
        with hash_ptr:
          let (z) = hash2(1, 2)
        end
        return (hash_ptr=hash_ptr, z=z)
      end
      ```
        - The purpose of the `with` statement is to make the code more readable
        - To call `hash2` changes (rebinds) the reference `hash_ptr` even though `hash_ptr` is not mentioned in that line
        - The only references that may be implicitly changed are implicit arguments and references mentioned in a `with` statement
        - This is because it can be confusing to have `hash2()` change `hash_ptr` even though it's not even in `hash2()`'s arguments
  - Using the implicit argument mechanism, and helper functions, such as `hash2` you don't have to worry about the builtin pointer
    - All you have to do is add `hash_ptr` as an implicit argument and then you can call `hash2` without explicitly passing the pointer

### revoked implicit arguments
  - Implicit arguments are implemented as references and as such they can be revoked
  - EG
    - A function has an explicit argument for `hash_ptr`
    - It then calls `hash2()`, then some other function that __doesn't__ use the implicit argument, and then `hash2()` is called again
    - The implicit argument is based on the `ap` register 
      - So when you call a function that doesn't use `hash_ptr` then the track on `ap` is lost
  - So solvs this you need to assign `hash_ptr` to a local variable like so
    ```
    local hash_ptr : HashBuiltin* = hash_ptr
    ```
    - You can also simply add `alloc_locals` to the top of the function and the compiler will automatically add the above instruction
    - After the line `local hash_ptr : HashBuiltin = hash_ptr` the reference to `hash_ptr` is relative to `fp` instead of `ap`
  - This will still happen regardless if you have if statements or jumps in your code
    - Because the binding will be different depending on the branch of the if statement
    - This can be addressed by adding `tempvar hash_ptr = hash_ptr` to every possible branch in an `if` statement

### layouts
  - Cairo supports a few possible layouts
    - Each layout specifies which of the different builtins exist and how many instances of that builtin can be used
  - This is measured as the ratio between the number of instructions and the number of available builtin instances
    - EG: If this ration of a hash builtin is 16, it means that the number of hash invocations can be at most `n_steps / 16`
      - Where `n_steps` is the number of Cairo steps
    - If your program needs more hash invocations you can either increase the number of steps (with `--steps` flag)
      - The alternative is to choose a layout with a smaller ratio
  - The default layout is `plain` and it has no builtins, thus you need to call `cairo-run` with another layout if you want to
    - Write output
    - Compute Pedersen hash
    - Use another builtin

### the small layout
  - The `small` layout (`--layout=small`) includes the following builtins
    ```
    Builtin name    Ratio
    ---------------------
    Output          -
    Pedersen        8
    Range check     8
    ECDSA           512
    ```
    - Note that since the number of `ECDSA` instances is `n_steps/512` and it must be an integer it implies
      - That the number of steps must be divisible by 512 when the `small` layout is used

### the %builtins directive
  - The `%builtins` directive specifies which builtins are used by the program
  - Each builtin adds an argument to `main()` and requires a return value
  - Those can be replaced by adding implicit arguments to `main`
  - EG
    ```
    %builtins output pedersen

    from starkware.cairo.common.cairo_builtins import HashBuiltin
    from starkware.cairo.common.hash import hash2

    # Implicit arguments: addresses of the output and pedersen builtins
    func main{output_ptr, pedersen_ptr : HashBuiltin*}():
      # The following line implicitly updates the pedersen_ptr reference to pedersen_ptr + 3
      let (res) = hash2{hash_ptr=pedersen_ptr}(1, 2)
      assert [output_ptr] = res

      # Manually update the output builtin pointer
      let output_ptr = output_ptr + 1

      # output_ptr and pedersen_ptr will be implicitly returned
      return ()
    end
    ```

### range checks
  - The range-check builtin is used to check that a field element is within the range [0, 2^128)
  - It forces that...
    ```
    0 <= [p + 0] < 2^128
    0 <= [p + 1] < 2^128
    0 <= [p + 2] < 2^128
    ```
    - ...where `p` is the beginning address of the builtin
    - Checking that a value `x` is in a smaller range [0, BOUND] (where BOUND < 2^128) can be done using two range-check instances:
      - Use one instance to verify that `0 < x < 2^128`
      - Use another instance to verify that `0 <= BOUND - x < 2^128`

### divisibilty testing
  - Divisibility is a question of whether an integer `x` is divisible by `y` without remainder
    - IE: Is there an integer `z` such that `x = y * z`
  - A special case is testing whether `x` is even or odd
    - The question of (integer) divisibilty is not well-defined within finite fields
    - `P - 1` is an even integer, but is also used to represent `-1` which is clearly odd
  - You can overcome this by forcing a range

### integer division
  - We can use the range-check builtin in order to computer integer division with remainder
  - The geal is to computer `q = <floor>x/y</floor>` and `r = x % y`
    - We can rewrite it as `x = q * y + r` (as integers) where `0 <= r <= y`
  - When we test `x = q * y + r` we need to be careful
    - We need to make sure the computation will not overflow
  - For simplicity we will assume here that `0 <= x`, `y < 2^64`
    - If this is not the case, you can modify the code according to your constraints
  - The following code computes `q` and `r` (and validates `0 <= x`, `y < 2^64`) assuming that `|F| > 2^128`
  - ___Personal note: I'm not exactly following this___
  - The code
    ```
    func div{range_check_ptr}(x, y) -> (q, r):
      alloc_locals
      local q
      local r
      %{ ids.q, ids.r = ids.x // ids.y, ids.x % ids.y %}

      # Check that 0 <= x < 2**64
      [range_check_ptr] = x
      assert [range_check_ptr + 1] = 2 ** 64 - 1 - x

      # Check that 0 <= y < 2**64
      [range_check_ptr + 2] = y
      assert [range_check_ptr + 3] = 2 ** 64 - 1 - y

      # Check that 0 <= q < 2**64
      [range_check_ptr + 4] = x
      assert [range_check_ptr + 5] = 2 ** 64 - 1 - q

      # Check that 0 <= r < y
      [range_check_ptr + 6] = r
      assert [range_check_ptr + 7] = y - 1 - r

      # Verify that x = q * y + r
      assert x = q * y + r

      let range_check_ptr = range_check_ptr + 8
      return (q=q, r=r)
    end
    ```

## define word
  - The `dw` keyword compiles to a single field element of data directly in the code
  - EG: `dw 0x123`
    - Will be translated to the field element `0x123` in the bytecode
  - This isn't really an instruction, and therefore should not be in any execution path
  - A common use for this is constant arrays
    ```
    from starkware.cairo.common.registers import get_label_location

    # Returns a pointer to the values: [1, 22, 333, 4444]
    func get_data() -> (data : felt*):
      let (data_address) = get_label_location(data_start)
      return (data=cast(data_address, felt*))

      data_start:
      dw 1
      dw 22
      dw 333
      dw 4444
    end

    func main():
      let (data) = get_data()
      tempvar value = data[2]
      assert value = 333
      return()
    end
    ```
