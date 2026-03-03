# Simple substitution 
echo day | sed s/day/night/

# Using ampersan (&) as the matched string
echo "123 abc" | sed 's/[a-z]\{3,\}/& & &/' # Repeat abc twice more

# Keep part of the pattern
echo abcd123 | sed 's/\([a-z]*\).*/\1/' # Parenthesis denote pattern 1

echo abcdefg | sed 's/^\(.\)\(.\)\(.\)/\3\2\1/' # Reverse first 3 chars

echo abcdabcd | sed 's/c/x/g' # Change all occurence not just the first match

echo 'first second third' | sed 's/[a-z]*[[:space:]]//2' # Delete the 2nd occurence only

echo 'BEGIN process END' | sed 's/BEGIN/begin/g' | sed 's/END/end/g' # Do two changes with pipe calling sed twice

echo 'BEGIN process END' | sed -e 's/BEGIN/begin/g' -e 's/END/end/g' # Same as the previous

# Same as cat
print "This\nand\nthat" | sed 's/x/&/p' # If pattern not found, just prints the line

# Same as grep
print "This\nand\nthat" | sed -n 's/a/&/p' # If pattern found, print it, otherwise do not (-n)

# Every line that start with a "t". Search expression goes first
print "This\nand\nthat" | sed '/t/ s/a/b/'

# Execute it on certain lines only 
print "\n"
print "This\nand\nthat\nthing" | sed '2,3 s/t/b/'

# Specify range by regexp. Start turns substitution on. Stop turns it off
print "\n"
print "This\nand\nstart\nthat\nthing\nstop\nnothing" | sed '/start/,/stop/ s/t/x/'

# Delete lines
print "\n"
print "This\nand\nstart\nthat\nthing\nstop\nnothing" | sed '1,3 d'

# Printing
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed 'p' # Print everything plus print again (duplicate)
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed -n '1,3 p' # -n says do not print by default, p says print what matches criteria
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed -n '1,3 !p' # Reversing p
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed '3 q' # Quit after criteria matched

# Append a line after
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed '/i\+/ a This line goes after the line with i in it'
# Insert a line before
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed '/i\+/ i This line goes before the line with i in it'
# Change a line
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed '/i\+/ c This line will change the line with i in it'

# Transform with y
print "\n"
print "First\nSecond\nThird\nFourth\nFifth" | sed 'y/abcdefghijklmnop/ABCDEFGHIJKLMNOP/'
