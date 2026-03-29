from enum import Enum, unique

@unique
class Color(Enum):
    red = 1
    green = 2
    blue = 3

par = "green"
print (Color[par].name)
print (Color[par].value)
print(Color.red)
print(Color.red.name)
print(Color.red.value)