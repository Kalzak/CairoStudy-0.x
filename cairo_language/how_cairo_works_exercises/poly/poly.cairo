func main():
  [ap] = 100; ap++                  # x

  [ap] = [ap - 1] * [ap - 1]; ap++  # x^2
  [ap] = [ap - 2] * [ap - 1]; ap++  # x^3
  [ap] = [ap - 2] * 23; ap++        # 23x^2
  [ap] = [ap - 4] * 45; ap++        # 45x
  [ap] = [ap - 3] + [ap - 2]; ap++  # x^3 + 23x^2
  [ap] = [ap - 1] + [ap - 2]; ap++  # x^3 + 23x^2 + 45x
  [ap] = [ap - 1] + 67; ap++        # x^3 + 23x^2 + 45x + 67

  ret
end
