# The func ()() syntax is a common pattern in Python for creating closures. A closure is a function that retains access to variables from its enclosing scope,
# even after that scope has finished executing. In this example, func () returns inner_func (), which retains access to the variable val from func ().
def func (p1, p2):
    val = p1 + p2
    def inner_func (p3):
        return val ** p3 # inner_func has access to val, which is defined in the enclosing scope of func despite the fact that func has finished executing by the time inner_func is called.

    return inner_func
ret = func (2, 3)(2) # Adds 2 and 3 to get 5, then raises 5 to the power of 2 to get 25
print (str (ret))

def make_counter():
    count = 0  # This variable will be remembered from outer scope
    def counter():
        nonlocal count  # Modify outer variable
        count += 1
        return count
    return counter

counter1 = make_counter()
print(counter1())  # 1
print(counter1())  # 2