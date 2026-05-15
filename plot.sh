echo "Starting DS9..."
if [ `xpaaccess DS9Test` = no ]; then
    ds9 -title DS9Test -tcl&

    i=1
    while [ "$i" -le 30 ]
	do
	sleep 2
	if [ `xpaaccess DS9Test` = yes ]; then
	    break
	fi

	i=`expr $i + 1`
    done
fi

echo
echo "*** plot.sh ***"

delay=.5

echo -n "file xy|xyex|xyey|xyexey..."
xpaset -p DS9Test plot plot/xy.dat {The Title} {X Axis} {Y Axis} xy
xpaset -p DS9Test plot plot/xyex.dat {The Title} {X Axis} {Y Axis} xyex
xpaset -p DS9Test plot plot/xyey.dat {The Title} {X Axis} {Y Axis} xyey
xpaset -p DS9Test plot plot/xyexey.dat {The Title} {X Axis} {Y Axis} xyexey
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n "line file xy|xyex|xyey|xyexey..."
xpaset -p DS9Test plot line plot/xy.dat {The Title} {X Axis} {Y Axis} xy
xpaset -p DS9Test plot line plot/xyex.dat {The Title} {X Axis} {Y Axis} xyex
xpaset -p DS9Test plot line plot/xyey.dat {The Title} {X Axis} {Y Axis} xyey
xpaset -p DS9Test plot line plot/xyexey.dat {The Title} {X Axis} {Y Axis} xyexey
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

xpaset -p DS9Test plot bar plot/xy.dat {The Title} {X Axis} {Y Axis} xy
xpaset -p DS9Test plot bar plot/xyex.dat {The Title} {X Axis} {Y Axis} xyex
xpaset -p DS9Test plot bar plot/xyey.dat {The Title} {X Axis} {Y Axis} xyey
xpaset -p DS9Test plot bar plot/xyexey.dat {The Title} {X Axis} {Y Axis} xyexey
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

# backward compatibility
xpaset -p DS9Test plot scatter plot/xy.dat {The Title} {X Axis} {Y Axis} xy
xpaset -p DS9Test plot scatter plot/xyex.dat {The Title} {X Axis} {Y Axis} xyex
xpaset -p DS9Test plot scatter plot/xyey.dat {The Title} {X Axis} {Y Axis} xyey
xpaset -p DS9Test plot scatter plot/xyexey.dat {The Title} {X Axis} {Y Axis} xyexey
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n "stdin 2|3|4|5..."
cat plot/stdin.2.dat | xpaset DS9Test plot line stdin
cat plot/stdin.3.dat | xpaset DS9Test plot line stdin
cat plot/stdin.4.dat | xpaset DS9Test plot line stdin
cat plot/stdin.5.dat | xpaset DS9Test plot line stdin
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

cat plot/stdin.2.dat | xpaset DS9Test plot bar stdin
cat plot/stdin.3.dat | xpaset DS9Test plot bar stdin
cat plot/stdin.4.dat | xpaset DS9Test plot bar stdin
cat plot/stdin.5.dat | xpaset DS9Test plot bar stdin
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

# backward compatibility
cat plot/stdin.2.dat | xpaset DS9Test plot scatter stdin
cat plot/stdin.3.dat | xpaset DS9Test plot scatter stdin
cat plot/stdin.4.dat | xpaset DS9Test plot scatter stdin
cat plot/stdin.5.dat | xpaset DS9Test plot scatter stdin
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n "stdin xy|xyex|xyey|xyexey..."
cat plot/stdin.xy.dat | xpaset DS9Test plot line stdin
cat plot/stdin.xyex.dat | xpaset DS9Test plot line stdin
cat plot/stdin.xyey.dat | xpaset DS9Test plot line stdin
cat plot/stdin.xyexey.dat | xpaset DS9Test plot line stdin
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

cat plot/stdin.xy.dat | xpaset DS9Test plot bar stdin
cat plot/stdin.xyex.dat | xpaset DS9Test plot bar stdin
cat plot/stdin.xyey.dat | xpaset DS9Test plot bar stdin
cat plot/stdin.xyexey.dat | xpaset DS9Test plot bar stdin
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

# backward compatibility
cat plot/stdin.xy.dat | xpaset DS9Test plot scatter stdin
cat plot/stdin.xyex.dat | xpaset DS9Test plot scatter stdin
cat plot/stdin.xyey.dat | xpaset DS9Test plot scatter stdin
cat plot/stdin.xyexey.dat | xpaset DS9Test plot scatter stdin
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n "stdin text|error..."
cat plot/stdin.error.dat | xpaset DS9Test plot line stdin
cat plot/stdin.text.dat | xpaset DS9Test plot line stdin
sleep "$delay"
xpaset -p DS9Test plot close
echo "PASSED"

echo -n "4|5..."
cat plot/4.dat | xpaset DS9Test plot line {The Title} {X Axis} {Y Axis} 4
cat plot/5.dat | xpaset DS9Test plot line {The Title} {X Axis} {Y Axis} 5
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

cat plot/4.dat | xpaset DS9Test plot bar {The Title} {X Axis} {Y Axis} 4
cat plot/5.dat | xpaset DS9Test plot bar {The Title} {X Axis} {Y Axis} 5
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

# backward compatibility
cat plot/4.dat | xpaset DS9Test plot scatter {The Title} {X Axis} {Y Axis} 4
cat plot/5.dat | xpaset DS9Test plot scatter {The Title} {X Axis} {Y Axis} 5
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n "xy|xyex|xyey|xyexey..."
cat plot/xy.dat | xpaset DS9Test plot line {The Title} {X Axis} {Y Axis} xy
cat plot/xyex.dat | xpaset DS9Test plot line {The Title} {X Axis} {Y Axis} xyex
cat plot/xyey.dat | xpaset DS9Test plot line {The Title} {X Axis} {Y Axis} xyey
cat plot/xyexey.dat | xpaset DS9Test plot line {The Title} {X Axis} {Y Axis} xyexey
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

cat plot/xy.dat | xpaset DS9Test plot bar {The Title} {X Axis} {Y Axis} xy
cat plot/xyex.dat | xpaset DS9Test plot bar {The Title} {X Axis} {Y Axis} xyex
cat plot/xyey.dat | xpaset DS9Test plot bar {The Title} {X Axis} {Y Axis} xyey
cat plot/xyexey.dat | xpaset DS9Test plot bar {The Title} {X Axis} {Y Axis} xyexey
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

# backward compatibility
cat plot/xy.dat | xpaset DS9Test plot scatter {The Title} {X Axis} {Y Axis} xy
cat plot/xyex.dat | xpaset DS9Test plot scatter {The Title} {X Axis} {Y Axis} xyex
cat plot/xyey.dat | xpaset DS9Test plot scatter {The Title} {X Axis} {Y Axis} xyey
cat plot/xyexey.dat | xpaset DS9Test plot scatter {The Title} {X Axis} {Y Axis} xyexey
sleep "$delay"
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

xpaset -p DS9Test quit

echo "DONE"
