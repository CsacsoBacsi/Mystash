from functools import partial

# Parameter Fixing: Partial functions can be very useful when we have a function with multiple parameters and we frequently want to use it with some parameters fixed.
#   Instead of repeatedly passing those fixed parameters, we can create a partial function and call it with the remaining arguments.
# Reducing Duplication: If we are using the same arguments for a function in various places, creating a partial function with those fixed arguments can help to reduce 
#   code duplication and maintenance efforts.
# Default Arguments: Python's built-in functools.partial can be used to set default values for function arguments.

# A normal function
def nfunc (a, b, c, x):
    return 1000 * a + 100 * b + 10 * c + x

# A partial function that calls nfunc with a as 3, b as 1 and c as 4. a,b,c are fixed like default parameters
pfunc = partial (nfunc, 3, 1, 4)

# Calling pfunc ()
print (pfunc (5)) # The last parameter x is not fixed, so we can call pfunc with just that parameter. This will call nfunc (3, 1, 4, 5) and return 3145