func main(): 
  [ap] = 25; ap++
  %{
    import math
    memory[ap] = int(math.sqrt(memory[ap - 1])) + 1
  %}
  [ap - 1] = [ap] * [ap]; ap++
  ret
end
