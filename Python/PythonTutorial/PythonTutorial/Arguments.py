# --------------------------------------------------------------------

import os

# --------------------------------------------------------------------

# Multiple (variable length) function arguments
def test_var_args (f_arg, *args):
    print ("First, normal arg: " + f_arg)
    for arg in args: # *args is like an array of parameters
        print ("Another arg through *args: ", arg)

test_var_args ('Normal', 'Python', 'C++', 'Asm')

# --------------------------------------------------------------------

# Multiple (variable length) keyword/value function arguments
def test_kw_args (p1, p2 = 5, ** kwargs):
    p = p2
    if kwargs is not None:
        for key, value in kwargs.items (): # Iterates over a dict's key-value pair. KeyWord arguments array
            print ("%s == %s" % (key, value))
    print ("First keyword argument: " + kwargs["par1"]) # kwargs is a dict of keyword arguments, so we can access its elements by key
 
test_kw_args (5, par1 = "param1", par2 = "param2", par3 = "param3")

# --------------------------------------------------------------------

mylist = ["Python", "C++", "Asm"]

def loop_func (*lis): # 3 parameters instead of 1 (lis).
    for l in lis:
        print (l)

loop_func (*mylist) # Unpack the list into individual parameters

mydict = {"par1": "param1", "par2": "param2", "par3": "param3"}

def loop_func2 (**dic): # 3 keyword parameters instead of 1 (dic)
    for key, value in dic.items ():
        print ("%s == %s" % (key, value))

loop_func2 (**mydict) # Unpack the dict into individual keyword parameters
print ("----------------------")
def params (pos1, pos2, pos3, pos4, pos5 = 4.9, *args, pocs, **kwargs):
    print (f"pos1: {pos1}, pos2: {pos2}, pos3: {pos3}, pos4: {pos4}, pos5: {pos5}")
    print ("Keyword argument pocs: ", pocs)
    if args is not None:
        for arg in args: # *args is like an array of parameters
            print ("Another arg through *args: ", arg)
        for key, value in kwargs.items (): # Iterates over a dict's key-value pair. KeyWord arguments array
            print ("KeyWord args: %s = %s" % (key, value))
params (1, 2, 3, 4, 5, 6, 'hi', 7.5, pocs = "pocs", kw1='hi', kw2 = 99)
'''
pos1 - pos5 : Positional arguments (pos5 has a default value). Default parameter can not be followed by non-default parameters therefore pos5 must be the last positional argument.
pocs : Keyword-only argument (pocs). Must be specified after *args
*args : Variable length positional arguments (6, 'hi', 7.5))
**kwargs : Variable length keyword arguments (kw1='hi', kw2 = 99). Positional arguments can not follow keyword arguments
'''
# --------------------------------------------------------------------


os.system ("pause")

