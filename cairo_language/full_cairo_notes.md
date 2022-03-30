# Kalzaks condensed Cairo notes
Sections
  - cairo intro
  - debugging-related flags
  - the program counter (`pc`)
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
