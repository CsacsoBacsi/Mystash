import random

my_list = [1, 2, 3]
a, b, c = my_list # Unpacks the list into separate variables a, b, and c. The number of variables must match the number of elements in the list.
print (a, b, c)

points_min_max=(5,20)
rnd = random.randint(points_min_max[0],points_min_max[1]) # This is cumbersome 
print (rnd)

random.randint(*points_min_max) # This is much better, the * operator unpacks the tuple into separate arguments for the function

def my_func1(*args, **kwargs):
  '''
  args is a tuple, so you can use indexing to get the values
  kwargs is a dict, so you can use, kwargs.get(param_name) to access the value
  '''
  print(args)
  print(kwargs)

positional_args = (1, 2, 3, 4)
keyword_args = { 'arg1': 1, 'arg2': 2, 'arg3': 3 }

my_func1(*positional_args, **keyword_args)

# -------------------------------------------------------------
# Asterisk
person = ['Csacsi', 57, 'Data engineer', 'Miskolc']
name, age, job, city = person # Unpacks person into separate variable

name, *everything_else = person # Unpacks name and puts everything else as a list into everything_else
*everything_else, city = person # You can have only one asterisk! Number of variables must also match the items in the list!

word = 'Hi!'
first_letter, second_letter, third_letter = word # Splits the word into letters and assigns each individual letter to a separate variable. Asterisk works here too!

# Underscore
person = ['Csacsi', 57, 'Data engineer', 'Miskolc']
name, _, job, _ = person # Skip these values, do not assign them to any variable. You can have multiple underscores

# Combine asterisk and underscore
person = ['Csacsi', 57, 'Data engineer', 'Miskolc']
# Instead of: name, *everything_else = person
name, *_= person # We get name and throwaway the rest



