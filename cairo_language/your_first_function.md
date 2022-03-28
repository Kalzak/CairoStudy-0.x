```
# Computes the sum of the memory elements at addresses:
# arr + 0, arr + 1, ..., arr + (size - 1).
func array_sum(arr: felt*, size) -> (sum):
  if size == 0:
    return (sum=0)
  end

  # size is not zero.
  let (sum_of_rest) = array_sum(arr=arr + 1, size=size - 1)
  return (sum=[arr] + sum_of_rest)
end
```
Breakdown of the function
  - First two lines are comments
    - Comments are done with `#` and last until end of line
  - `func array_sum(arr : felt*, size) -> (sum):`
    - Defines a function named `array_sum`
    - Takes two arguments
      - `arr`: points to an array of `size` elements
      - `size`: the size of the array `arr`
    - Returns one value called `sum`
    - Scope of function ends with word `end`
    - Note that a return isn't implicit with `end`
      - You have to explicitly add `return` statement
  - `if size == 0:`
    - If the variable `size` is zero then enter `if` body, otherwise skip to end of `if` body
  - `return (sum=0)`
    - When `size == 0` there are no elements in the array so we can return the sum is zero.
    - The syntax `sum=` is not mandatory, but recommended for readability
      - If you don't want to use `sum=` then you can write `return (0)`
      - Parenthesis on the `return` is required
      - `return` ends execution of function immediately and returns to calling function
  - `end`
    - The end of the `if` statement
  - `let (sum_of_rest) = array_sum(arr=arr + 1, size=size - 1)`
    - Remember that this only executes if `size != 0`
    - Makes a recursive call to `array_sum` where
      - The array is one element smaller (left side removed)
        - `arr` is a pointer, so `arr + 1` is the current memory location plus one element
      - The `size` of the array has been updated accordingly
    - Note that in function calls the setting of `arr=` and `size=` is optional
    - The expression `let (sum_of_rest) = ` says that the function returns one value
      - This value can be accessed using `sum_of_rest`
    - Note that you can't call functions as part of other expressions
      - EG: `foo(bar())` will not compile
  - `return (sum=[arr] + sum_of_rest)
    - We have recursed through the array and added all elements from index `1` to `size - 1`
    - But we haven't added the element at index `0` to `sum\_of\_rest`
    - We return `sum\_of\_rest` added with the first element to return the sum of array contents
    - Note the `[arr]`
      - `[...]` is a dereference operator, so `[arr]` is the value of memory at address `arr`
        - In this case that's the first element in the array
  - `end`
    - The end of the function 
