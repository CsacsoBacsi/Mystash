# ksh tutorial exercise script - Csaba Riedlinger

print "\nKSH tutorial output\n"

# Word count
wc tut.ksh # Get line, word, char count

# Arrays
set -A myarr value1 value2 value3 # Define array with init values
echo ${myarr[2]}
echo ${myarr[@]} # Get all values (space separated) at once

# Read only variable
myrovar="My read-only variable"
readonly myrovar # Read only variable, value can not be changed
echo $myrovar
#myrovar="something else" # Raises error

unset myarr # Forget about myarr
echo ${myarr[1]}

# Shell variable
export envvar1="Hello!" # Exports variable for use by child processes
./tut2.ksh # Child shell script to echo envvar1
echo $PWD # Echo a shell variable

# NVL
var0="Csacsi"
var1=${var2:-$var0} # If var2 is null or not set, use value in var0. Does not set var2, only var1
echo $var2 # Displays nothing
echo $var1

var0="Csacso"
var1=${var2:=$var0} # If var2 is null or not set, use value in var0. Sets var2 as well
echo $var2 
echo $var1

thisdate=`date` # Command substitution
echo $thisdate

# Arithmetic
res=$((5+10))
echo $res

# Quoting
echo It\'s raining
echo 'We can use special chars like $*& etc.'

# String manipulation
echo "Length of var1: ${#var1}"
stringZ="wxyzabcABC123ABCabc"

pos=`expr index $stringZ '(3A)'` # First occurence of ANY letters in search string
echo "Position: $pos"

sstr=`expr substr "Sleep well" 7 4`i # Substring
echo "Substring: $sstr"
echo ${sstr:1:1} # Substring: fisrt char at pos 1
echo ${sstr: -2} # Last two chars. Note the space after the colon

mystr="Csaba RRiedlinger"
instr="in"
echo ${mystr/a[[:space:]]/repl} 
echo ${mystr} | grep -c 'a[[:space:]]R\+' # Metachar + must be backslashed!

echo "$mystr:$instr" | awk -F: '{print index($1,$2)}' # Find position of string in another
echo "ToBeSub" | awk '{print gensub ("Sub","Replaced","G",$1)}' # Substitute string "G"-globally
echo "ToBeSub" | awk '{print match ($1,"Be")}' # Returns position match of regexp in str
echo "ToBeSub" | awk '{print substr ($1,3,5)}' # Substring from position for length

exit 0

# Conditional branching
if cat tut.ksh > tutcopy.ksh ; then # Command test
   echo 'Copy done successfully.'
else
   echo 'Copy failed.'
fi

if [ -f $HOME/tutcopy.ksh ] ; then # File test
   echo 'File exists!'
else
   echo 'File does not exist!'
fi

if [ -z "$var1" ] ; then # String test if zero length
   echo 'Var1 is empty'
else
   echo "Var1 has ${#var1} chars."
fi
if [ "$var1"="Csacso" ] ; then # String equality test
   echo 'Var1 is Csacso'
else
   echo 'Var1 is not Csacso'
fi

chmod 777 nonexistent.file
if [ $? -ne 0 ] ; then # Command exit status test
   echo 'Command errored.'
else
   echo 'Command successful.'
fi

numval1=100
numval2=101
if [ $numval1 -lt $numval2 ] ; then # Numeric values test
   echo 'Less than.'
else
   echo 'Not less than.'
fi
if [ $numval1 -lt 200 -a $numval2 -gt 100 ] ; then # Compound expression
   echo 'And satisfied.'
else
   echo 'And not satisfied.'
fi

# CASE statement
fruit=kiwi 
case "$fruit" in 
    apple) echo "Apple it is" ;; 
    banana) echo "Banana it is" ;; 
    kiwi) echo "Kiwi it is" ;;
    *) echo "Fruit not recognized" ;; 
esac

# Increment counter
x=1
x=$((x+1))
echo $x

# While loop
x=1
while [ $x -le 10 ]
do
   echo $x
   x=$((x+1))
   # With the BC command
   # x=`echo "$x + 1" | bc`
done

# User input
secret=55
resp= 
while [ -z "$resp" ] ;  
do 
    echo "Enter a number: " 
    read resp 
    if [ $secret -eq $resp ] ; then 
        echo "Well done!"
    else
       resp=
       continue 
    fi 
done

# For loop
for i in 0 1 2 3 4 5 6 7 8 9 
do  
    echo $i 
done
echo "Files in the home directory:"
for file in $HOME/* 
do 
   echo $file
done

ilist="One two three"
for i in ${ilist}
do
   echo $i
done

# User selection
PS3="Please make a selection => " ; export PS3
select sel in comp1 comp2 comp3 all quit 
do 
    case $sel in 
        comp1|comp2|comp3) echo "Selected: $sel" ;; 
        all) echo "All selected" ;; 
        quit) break ;; 
        *) echo "ERROR: Invalid selection." ;; 
    esac 
done 

# Loop control
for i in 1 2 3 4 5
do
   for j in 1 2 3 4 5
   do
      if [ $i -eq 3 -a $j -eq 2 ] ; then
         break 2 # Break 2 levels
      fi
      echo "i=$i j=$j"
   done
done

# Arguments
echo "Command executing: $0"
echo "Number of arguments supplied: $#"
echo "Parameter 1: $1"
echo "Parameter 2: $2"
echo "All params: $@"
echo "Process id: $$"
echo "Individual parameters:"
for thisparam in $@
do
   echo $thisparam
done

# Basename
bname=`basename $0`
echo "Basename: $bname"

# Option parsing 
VERBOSE=false
USAGE="Use it this way:"
while getopts f:o:v OPTION ; 
do
    case "$OPTION" in
        f) INFILE="$OPTARG" ;;
        o) OUTFILE="$OPTARG" ;;
        v) VERBOSE=true ;;
       \?) echo "$USAGE" ; 
           exit 1 
           ;;
    esac
done

echo "-f : $INFILE"
echo "-o : $OUTFILE"

# Read a file
while read LINE 
do 
   case $LINE in  
   *3*) echo "Found!" ;; 
   *) echo $LINE ;; 
esac 
done < inp_file.txt

# Associating file with handle
exec 4>myoutput.txt
cat inp_file.txt>&4 # To reference handle, use the ampersand char
cat inp_file.txt myoutput.txt >> merge_file.txt # Catenate two files and redirect output to third

# List path directories
OLDIFS="$IFS" # Save original Internal Field Separator value 
IFS=: # $PATH uses the colon to separate dirs 
for DIR in $PATH ; do echo $DIR ; done 
IFS="$OLDIFS" # Restore original IFS

# Functions
set_prompt () {
    PS1="`pwd`$" # This is temporary only
    echo $PS1
}

set_prompt

# Eval
outputfile="> newoutput.txt"
echo hello $outputfile
eval echo hello $outputfile # Evaluates the value in the variable

# Signals
Cleanup () { # Handler routine
    echo "Got the signal!"
}

trap Cleanup 1 2 3 15
echo "Sleeping now..."
sleep 2 
echo "Woke up."

# Sub process
COMMAND1="sleep 20"
${COMMAND1} &
Procs="$Procs $!"
echo $Procs

# Alarm signal handling
AlarmHandler() { 
    echo "Got SIGALARM, cmd took too long." 
    KillSubProcs 
} 
 
KillSubProcs() { 
    kill ${CHPROCIDS:-$!} 2>/dev/null 
    if [ $? -eq 0 ] ; then 
        echo "Sub-processes killed." ;
    fi 
} 
 
SetTimer() { 
    DEF_TOUT=${1:-5} ; # Set default timeout to 5 secs 
    if [ $DEF_TOUT -ne 0 ] ; then 
        sleep $DEF_TOUT && kill -s 14 $$ & # After 5 secs send an ALARM signal to main process 
        echo "Time process's ID: $!"
        #CHPROCIDS="$CHPROCIDS $!"  
        TIMERPROC=$! 
    fi 
} 
 
UnsetTimer() {  
    kill $TIMERPROC 2>/dev/null 
} 
 
trap AlarmHandler 14 
SetTimer 5 
PROG="sleep 10"
$PROG & 
echo "Command's PID: $!"
CHPROCIDS="$CHPROCIDS $!" 
wait $! # Wait until command terminates (in 10 secs). Alarm subprocess will terminate earlier (5 secs) so a signal will be sent and received 
UnsetTimer 
echo "All Done."

# Built-in variables
echo "Process id: $$"
echo "Last subprocess' id: $!"
echo "Final argument of previous command: $_"
echo "Exit status of a command: $?"
echo "Flags passed to script: $-"
echo "Program timeout after which user is logged out: $TMOUT"
echo "Number of seconds this script has been run: $SECONDS"
echo "Parent process' id: $PPID"
echo "OS Type: $OSTYPE"
echo "Host name: $HOSTNAME"
echo "Currently executing function: $FUNCNAME"
