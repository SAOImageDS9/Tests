KillIt () {
    i=1
    while [ "$i" -le 15 ]; do
      sleep 1
      if [ `xpaaccess DS9Test` = yes ]; then
	  if [ $slow = "1" ]; then
	      sleep 1
	  fi
	  xpaset -p DS9Test quit
	  break
      fi

      i=`expr $i + 1`
    done
}

StartDS9 () {
    if [ `xpaaccess DS9Test` = no ]; then
	ds9 -title DS9Test &

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
    sleep 1
}

# which/where
which=Multiframe
where=mecube
ext=fits
what=multiframe

# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

echo
echo "*** $which ***"

# Command Line
if [ "$1" = "command" -o  -z "$1" ]; then
echo "Testing Command Line File"

for f in $where/*.$ext
do
    echo " ${f#$where/}"
    ds9 -title DS9Test -$what $f &
    KillIt
done

echo "PASSED"
fi

# Stdin
if [ "$1" = "stdin" -o  -z "$1" ]; then
echo "Testing Stdin File"

for f in $where/*.$ext
do
    echo " ${f#$where/}"
    cat $f | timeout 10s ds9 -title DS9Test -$what - &
    KillIt
done

echo "PASSED"
fi

# XPA
if [ "$1" = "xpa" -o  -z "$1" ]; then
echo "Testing XPA File"

StartDS9
xpaset -p DS9Test frame delete all

for f in $where/*.$ext
do
    echo " ${f#$where/}"
    xpaset -p DS9Test $what $f
    if [ $slow = "1" ]; then
	sleep 1
    fi
    xpaset -p DS9Test frame delete all
done

xpaset -p DS9Test quit
echo "PASSED"
fi

# XPA stdin
if [ "$1" = "xpastdin" -o  -z "$1" ]; then
echo "Testing XPA Stdin"

StartDS9
xpaset -p DS9Test frame delete all

for f in $where/*.$ext
do
    echo " ${f#$where/}"
    cat $f | xpaset DS9Test $what
    if [ $slow = "1" ]; then
	sleep 1
    fi
    xpaset -p DS9Test frame delete all
done

xpaset -p DS9Test quit
echo "PASSED"
fi

echo "DONE"
