Recursion instead of loops
  - Cairo memory is immutable
    - Once you write the value of a memory cell, the cell cannot change in the future
  - This makes loops (where you write over existing variables) limited and complicated to implement
  - The only advantage for loops over recursion is they tend to be slightly more efficient

The assert statement
  - `assert <expr0> = <expr1>`
  - Allows us to do two things
    - Verify that two values are the same value
    - Assign a value to a memory cell
  - EG: `assert [ptr] = 0`
    - Will set the value of the memory cell at address `ptr` to `0` if it was not set before.
  - This has to do with the fact that Cairo memory is immutable
    - If the values have already been set then it will function as a normal assert statement
    - If the value has not been set then Cairo will set it and the assert will pass

The primitive type - field element (felt)
  - In Cairo when you don't specify a type of a variables/argument, its type is a _field element_ (represented by keyword `felt`)
  - When we say "field element" we mean 
    - An integer in the range `-P/2 < x < P/2 where P is a very large prime number`
      - Currently it's a 252-bit number which is 76 decimal digits
  - When we add, subtract or multiply and the result is outside of the range, there is an overflow
    - In this case the appropriate multiple of `P` is added or subtracted to bring the result back into the range 
      - In other words the result is computed modulo `P`
  - The most important difference between integers and field elements is division
    - Division of field elements (and therefore division in Cairo) is different to normal programming language integer division
      - Normal languages have the integral part of the quotient returned (so you get `7 / 3 = 2`)
    - As long as the numerator is a multiple of the denominator it will behave as expected
      - `6 / 3 = 2`
    - If the numerator is not a multiple of the denominator then it acts differently
      - When we divide `7 / 3` it will result in a field element `x` that will satisfy `3 * x = 7`
      - It won't be `2.3333` because `x` has to be an integer
        - Might seem impossible but remember that if `3 * x` is outside the range `-P/2 < x < P/2` an overflow will occur
          - This can bring the result down to `7`
  - Cairo example
    - `serialize_word(6/3)` outputs `2`
    - `serialize_word(7/3)` outputs large 76 digit number (252 bits)
    - `serialize_word((7/3)*3) outputs `7`  
  - For the most part you won't have to deal with the fact that values in Cairo are field elements and can use them as normal
