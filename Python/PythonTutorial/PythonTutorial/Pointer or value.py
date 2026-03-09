*** Class as parameter
class ABC:
    intc1 = 10
    intc2 = 20

    def __init__(self, int1: int, int2: int):
        self.int1 = 100
        self.int2 = 200

abc = ABC(1, 2)
print (abc.int1)
print (abc.int2)
print (ABC.intc1) # Class variables can be accessed via the class name, and they are shared across all instances of the class.
                  # So this will print 10, which is the value of intc1 defined in the ABC class.
print (ABC.intc2)

def m1 (abc: ABC):
    print (abc.int1)
    print (abc.int2)
    abc.int3 = 300
    abc.int1 = 111

def m2 (abc: ABC):
    print (abc.int1) # This will print 111 because abc is passed by reference, so m1 modifies the same object that m2 accesses
    print (abc.int2)
    print (abc.int3) # This will work because abc is passed by reference, so m1 modifies the same object that m2 accesses

m1(abc)
m2(abc)

# Primitive types (like int, float, str) are passed by value, which means that a copy of the variable is created when it is passed to a function. This means that if you modify the variable inside the function, it does not affect the original variable outside the function.
g1 = 5

def cg ():
    g1 = 500 # This g1 is a local variable inside the cg function and does not affect the global g1 defined at the top.

cg ()
print (g1) # This will print 5 because the g1 defined inside cg is a local variable and does not affect the global g1 defined at the top.

def cg (myvar): # This myvar is a parameter of the cg function and does not affect the global g1 defined at the top.
    myvar = 500 # This myvar is a local variable inside the cg function and does not affect the global g1 defined at the top.

cg (g1)
print (g1) # This will print 5 because the myvar parameter in cg is