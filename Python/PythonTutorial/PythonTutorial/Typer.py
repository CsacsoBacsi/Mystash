import os
import typer

'''
Call:
python Typer.py mymain Lastname --firstname Csacsi --formal -a 54
kid and pwd parameters will be prompted. Password will be confirmed.
mymain is one of the typer commands defined below.
greet is another command and can be called like this:
python Typer.py greet Alice

If any keyword parameter is not provided by the function caller, the value is an object like <typer.models.OptionInfo object at 0x00000210EE903350>
Even despite the missing parameter in the typer.Option specification has a default value!
Typer will only take care the default value if the parameter is missing when the function is called from the command line. python Typer.py mymain Lastname --firstname Csacsi --formal

Typer only plays a role when the function is called from the command line. The parameter definition originally is of typer.Option type, but when the function is called from within Python code,
the parameter value will change to the actual value provided by the caller. 
When the function is called from the command line, Typer will take care of converting the command line parameter strings to the appropriate types (int, bool, str, etc.)
and the parameter values will also be of the appropriate types.
If the parameter value remains of typer.Option type, then the function was called from within Python code and not from the command line. Otherwise Typer either uses the default value 
or the value provided on the command line.

The methods decorated with @app.command() become commands of the Typer app and will be called when the app is called from the command line with the command name as first parameter.
'''

name = os.getenv("MY_NAME", "World") # Get environment variable MY_NAME, default to "World" if not set

app = typer.Typer()

print ("Running typer")

ageOption = typer.Option (5, '-a', '--age', help = "Specifies the age of the person")
kidOption = typer.Option (..., '-k', '--kid', help = "Your kid's first name", prompt="Type in your kid's first name")
pwdOption = typer.Option (..., '-p', '--pwd', help = "Your password", prompt="Type in your password", confirmation_prompt = True)

dummy = ageOption
print (f"Dummy ageOption: {dummy}") # Typer Option object with no value yet

@app.command ()
def greet (name: str):
    print (f"Hello {name} from greet function!")

@app.command ()
def mymain (lastname: str, age: int = ageOption, firstname: str = '', formal: bool = False, kid: str = kidOption, pwd: str = pwdOption):
    print ('-----------------')
    print (f"Hello {firstname} {lastname} aged {age}")
    if formal:
        print ("Formal is True")
    else:
        print ("Formal is False")
    print (f"Your kid is {kid}")
    print (f"Your password is {pwd}")

if __name__ == "__main__":
    print ("Calling mymain function from within the Python code with fixed parameter values...")
    #mymain ("Riedlinger", 57, "Csaba", True, "Alex", "mypassword")
    mymain (None, None, "Csaba", True, "Alex", "mypassword")
    print ("-----------------")
    print ("Calling Typer app...")
    app ()
