# Math operations on fields
awk '{ f1=$1; f2=$2*2; print $1 " " $2 " " f1*5+f2; }' awk_file1.txt

# BEGIN runs before file processing. END runs after
awk 'BEGIN{print"fee"} $1==5 {print"fi"} END{print"fo fum"}' awk_file1.txt

# Conditional operator
awk '{ if ($1 < 10) { print "less" } else { print "not less" }}' awk_file1.txt

# Loop over each field on the record and display their value
awk -F " " '{ for(i=1;i <=NF;i++) print "Field" i " value: " $i ; }' awk_file1.txt

# Regular expressions
echo 'Lines matching "Number+space+Bu"'
cat awk_file1.txt | awk '/[0-9][[:space:]]Bu/ { print $0}'

echo '3rd field matching "zi"'
awk '$3 ~/.+zi/' awk_file1.txt
