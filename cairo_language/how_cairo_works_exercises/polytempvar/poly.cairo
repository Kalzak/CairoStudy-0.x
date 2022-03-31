func main():
  [ap] = 100; ap++                  # x

  tempvar x = [ap - 1]
  tempvar xsquared = x * x
  tempvar xcubed = xsquared * x
  tempvar twentythreexsquared = xsquared * 23
  tempvar fourtyfivex = x * 45
  tempvar firsthalf = xcubed + twentythreexsquared
  tempvar lasthalf = fourtyfivex + 67
  tempvar solution = firsthalf + lasthalf

  ret
end
