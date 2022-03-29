Structs
  - They use the following structure
  ```
  struct Location:
    member row : felt
    member col : felt
  end
  ```
  - Struct data can be accessed like this
    - `structVariable.element`
    - The "dot" access method seems to work on pointer types too (or maybe all struct types are pointers)
  - The total size of a struct can be checked like this
    - `structVariable.SIZE`
    - It actually returns the memory 'size' that each struct would take up
    - If you have
      - A struct `struct1` that stores two `felts`
      - A struct `struct2` that stores one `felt` and then a `struct1`
      - The size of `struct2` would be 3 (one `felt` and then two `felts`)

Temporarly variables
  - Example
    - `tempvar num = 1`
  - The scope of a temporarly variables is restricted
    - Example
      - A temporary variable may be revoked due to jumps (eg `if` statements or func calls)
  - It manipulated `ap` which seems to be an important variable. Will look into this more later

Less than operator (`<`)
  - Cairo does not have an `<` operator
  - Because it's a complicated operation
  - Instead it has a _builtin_ called "range-check" that allows comparing values
  - There are also library functions to invoke the "range-check" such as `assert_nn_le()`
    - Gets two arguments `x` and `y` and verifies that `0 <= x <= y`

Return
  - Even if your function doesn't return anything, you need an empty return at the end of a function
    - `return ()`
  - Of course if you _are_ returning values then just use it like normal

Local variables
  - Similar to temporary variables except the scope in which they can be accessed is much less restricted
    - Can access them starting from their definution up until the end of your function
  - When using local variables the first statement in a function should be `alloc_locals`
    - If you don't add this line first then compilation will fail

References, temporary variables and local variables
  - A reference is defined using a `let` statement
    - EG: `let x = y * y * y`
    - In this case `x` is an alias for `y * y * y`
    - This means that the line `let x = y * y * y` does not actually cause any computation to happen
    - If you later something like `assert x * x = 1` it will turn into `assert (y * y * y) * (y * y * y) = 1`
  - Temporary and local variables are special cases of a reference
    - They point to a specific memory cell which stores the result of a computation
    - Therefore the statement `tempvar x = y * y * y` __will__ invoke the computation
      - `x` will then be an alias to the memory cell containing the result, rather than the expression `y * y * y`
  - Temporary variables do not require prior allocation of memory, but their scope is restricted
  - Local variables are placed in the beginning of the function stack
    - This means that they need prior allocation using the instruction `alloc_locals`
    - However they can be accessed throughout the entire execution of the function
  - The scope of the result of a function call is similar to that of a temporary variables
    - If you need to access the returned value later, you should copy the result to a local variable
  - If you get an error that your temporary variable was revoked, you can try to make it a local variable instead

Tuples
  - They are ordered, finite lists that contain any combination of valid types
    - EG: Five structs
  - Each element may be accessed with a zero-based index
    - EG: `loc_tuple[2]` is the third element
  - Typed example
  ```
  struct Location:
    member row : felt
    member col : felt
  end

  local loc_tuple : (Location, Location, Location, Location, Location) = (
    Location(row=0, col=2),
    Location(row=1, col=2),
    Location(row=1, col=3),
    Location(row=2, col=3),
    Location(row=3, col=3),
    )
  ```

Casting
  - Cairo supports types such as field element (`felt`), pointers and structs
  - You can change the type of an expression using `cast(<expr>, <type>)`
    - Where `<type>` can be
      - `felt` (for a field element)
      - `T` (for a struct `T`)
      - pointer to another types (such as `T*` or `felt**`)

Addresses of local variables
  - To get the address of a local variables you simply do `&localVariable`
  - When Cairo needs to retrieve the address of a local variable, it needs to be told the value of the frame pointer register `fp`
    - This can be done with the statement `let (__fp__, _) = get_fp_and_pc()`
    - If you don't use this line then you will get an error about "using the value of fp directly"
  - So if you actually want to get the address of a local variable you have to
  ```
  local number = 1
  let (__fp__, _) = get_fp_and_pc()
  let numberPtr = cast(&number, felt*)
  ```

Library function `squash_dict`
  - Can simulate the behavior of a read-write dict/map in Cairo
  - The library file `dict_access.cairo` defines the following struct
  ```
  struct DictAccess:
    member key: felt
    member prev_value : felt
    member new_value : felt
  end
  ```
  - The function `squash_dict()` (defined in `squash_dict.cairo`) gets a list of `DictAccess`
    - It verifies that they make sense (the prev value of the same key should match with new value in order)
    - It then returns a list of `DictAccess` entries where 
      - The squashed keys are sorted
      - Each key appears once
      - The squashed `prev_value` refers to the `prev_value` in the first time the key appeared
      - The squashed `new_value` refers to the `new_value` in the last time they key appeared
    - Shown table example
    ```
    Key Prv New
    7   3   2
    5   4   4
    7   2   10
    0   2   3
    7   10  0
    0   3   4
    0   4   5
    ```
    - The squashed dict for this example would be
    ```
    Key Prv New
    0   2   5
    5   4   4
    7   3   0
    ```
  - `squash_dict()` requires the Cairo builtin named "range-check"
    - Functions that need to use a builtin (and all the functions calling them) require 
      - That the builtin will be passed as an argument and that the updated pointer will be returned (same way we treat dict pointers)
      - This happens automatically when you add the implicit argument `range_check_ptr`
      - Therefore, the function that contains the `squash_dict()` needs to specify `range_check_ptr` as an argument too
        - That is then provided when called implicitly
      - `squash_dict()` returns an updated pointer and the overarching function (that contains `squash_dict`) 
        - Returns the same valuet to its caller

Reference rebinding
  - Insane. Will learn it later.
