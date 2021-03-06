
# (Large) prefix inserted above by Make

# BSD systems keep chown in /etc
PATH="$PATH:/etc"

case "$1" in
mkdir)
	if [ -n "$2" -a ! -d "$2"/. ]
	then
		mkdir $2
		if [ ! -d "$2" ] ; then
			echo "Cannot create directory $2"
			exit 1
		fi
		chmod $3 $2
		if ./usercheck 0 ; then
			chgrp $GROUP $2
			chown $OWNER $2
		fi
		echo Created directory $2
	fi
	exit 0
	;;
copy)
	cp $4 $3
	chmod $2 $3/$4
	if ./usercheck 0 ; then
		chgrp $GROUP $3/$4
		chown $OWNER $3/$4
	fi
	echo "$4 -> $3/$4"
	exit 0
	;;
chmod)
	chmod $2 $3
	if ./usercheck 0 ; then
		chgrp $GROUP $3
		chown $OWNER $3
	fi
	exit 0
	;;
esac

set -u

(
if $NNTP
then
	:
else
	if [ ! -d "$SPOOL"/. ]
	then
		echo Error: News spool directory $SPOOL not found.
	fi

	if [ ! -d "$NLIB"/. ]
	then
		echo Error: News lib directory $NLIB not found.
	fi
fi

set $RECMAIL
if [ ! -f "$1" ]
then
	echo ERROR: Mailer program $RECMAIL not found.
fi
) > ErrorCheck

if [ -s ErrorCheck ]
then
	cat ErrorCheck
	echo "Hit return to continue"
	read X
fi
rm -f ErrorCheck

LOOP=true
while $LOOP
do

if [ $# -ge 1 ]
then
	OPT="$1"
	shift
	if [ $# -eq 0 ]
	then
		LOOP=false
	fi
	PAUSE=false
else
	PAUSE=true

cat <<'EOF'


INSTALLATION

1) Master programs (machine dependent)
2) User programs (machine dependent, shareable)
3) auxiliary programs (configuration dependent, shareable)
4) Documentation (shareable)
5) Help files (shareable)
6) Online manual (shareable with 5)

INIT) Initialize database

s) Server installation:  1 + 2 + 3 + 4 + 5 + 6
n) Network installation:     2 + 3 + 4 + 5 + 6
h) Shared installation:      2 + 3
m) Master installation:  1
c) Client installation:      2
u) Update after patch
q) Quit

EOF
if ./usercheck 0 ; then
	:
else
  echo "Warning: not running as super user"
  echo ""
fi
${AWK} 'BEGIN{printf "Select option: "}' < /dev/null
read OPT
echo

fi

case $OPT in

s*|a*)
	OPT="master bin aux help online man"
	;;
u*)
	OPT=""
	if [ -f "$MASTER/nnmaster" ]
	then
		OPT="$OPT master"
	fi
	if $DBSHORTNAME
	then
		if [ -n "$DBDATA" -a -d "$DBDATA" -a ! -d "$DBDATA/0" ]
		then
			OPT="$OPT splitdb"
		fi
	fi
	if [ -f "$BIN/nn" ]
	then
		OPT="$OPT bin"
	fi
	if [ -f "$LIB/aux" ]
	then
		OPT="$OPT aux"
	fi
	if [ -d "$HELP" ]
	then
		OPT="$OPT help"
	fi
	if [ -f "$DMAN_DIR/nnmaster.$DMAN_SECT" ]
	then
		OPT="$OPT man"
	fi
	if [ -f "$HELP/Manual" ]
	then
		OPT="$OPT online"
	fi
	;;
1|m)
	OPT=master
	;;
n)
	OPT="bin aux help online man"
	;;
2|c)
	OPT=bin
	;;
h)
	OPT="bin aux"
	;;
3)
	OPT="aux"
	;;
4)
	OPT="man"
	;;
5)
	OPT="help"
	;;
6)
	OPT="online"
	;;
INIT)
	if $NOV
	then
	    echo "The NOV version of NN does not *have* it's own database!"
	else
	    OPT=init
	fi
	;;
q*|"")
	if [ -f $MASTER/nnmaster -a ! -f $MASTER/MPID -a ! $NOV ]
	then
		echo "Remember to restart $MASTER/nnmaster"
	fi
	exit 0
	;;
*)
	echo "Unrecognized option: $OPT"
	exit 1
	;;
esac

for OP in $OPT
do
case "$OP" in

master)
	./inst mkdir $MASTER 755 || exit 1

	if [ -f $MASTER/nnmaster ]
	then
		if [ -f $MASTER/MPID ]
		then
			echo "Stopping running master..."
			if $MASTER/nnmaster -k ; then
				echo "Stopped."
			else
				exit 1
			fi
		fi
		mv $MASTER/nnmaster $MASTER/nnmaster.old
	fi

	echo Installing master in $MASTER

	for prog in $MASTER_PROG
	do
		./inst copy 755 $MASTER $prog
	done

	if [ -f $MASTER/nnmaster ]
	then
		chmod 6750 $MASTER/nnmaster
	fi
	;;

bin)
	echo
	if [ ! -d "$BIN"/. ]
	then
		echo Directory $BIN does not found!
		exit 1
	fi

	echo Installing user programs in $BIN

	if [ -f $BIN/nn ]
	then
	     (
		cd $BIN
		mv nn nn.old
		rm -f $BIN_PROG $BIN_LINK
	     )
	fi

	for prog in $BIN_PROG
	do
		./inst copy 755 $BIN $prog
	done

	for link in $BIN_LINK
	do
		ln $BIN/nn $BIN/$link
		echo $link linked to nn
	done

	if [ -f $BIN/nnacct ] ; then
		chmod 4755 $BIN/nnacct
		echo nnacct is setuid ${OWNER}.
	fi
	;;

aux)
	echo
	./inst mkdir $LIB 755 || exit 1

	echo Installing auxiliary programs in $LIB

	for prog in $LIB_PROG
	do
		./inst copy 755 $LIB $prog
	done

	./mkprefix conf > ${LIB}/conf
	grep "^#" config.h |
	sed -e '/_MAN_/d' -e 's/[ 	]*\/\*.*$//' >> ${LIB}/conf
	./inst chmod 644 ${LIB}/conf
	;;

help)
	./inst mkdir $HELP 755 || exit 1

	echo
	echo Installing help files in $HELP

	cd help
	for h in *
	do
		cd ..
		./cvt-help < help/$h > $HELP/$h
		./inst chmod 644 $HELP/$h
		echo $h
		cd help
	done
	cd ..
	;;

man)
	echo
	echo Installing manuals

	PL="`echo $VERSION | sed -e 's/ .*$//'`"
	{
		echo $UMAN_DIR $UMAN_SECT .1
		echo $SMAN_DIR $SMAN_SECT .1m
		echo $DMAN_DIR $DMAN_SECT .8
	} |
	while read DIR SECT SRC
	do
		if [ -d "$DIR"/. ]
		then
			for i in man/*$SRC
			do
				MAN=`basename ${i} $SRC`
				NEW=$DIR/${MAN}.$SECT
				sed -e '/^\.TH /s/6.7/'${PL}'/' $i > $NEW
				./inst chmod 644 $NEW
				echo $MAN in $NEW
			done
		else
			echo $DIR not found or not writeable
		fi
	done
	;;

online)
	./inst mkdir $HELP 755 || exit 1

	MAN=$HELP/Manual

	echo
	echo "Formatting online manual $MAN"
	echo ".... (continues in background) ...."

	rm -f $MAN

	(
	sed 	-e 's/\\f[BPI]//g' \
		-e 's/\\-/-/g' -e 's/\\&//g' -e 's/\\e/\\/g' \
		-e '/^\.\\"ta/p' -e '/^\.\\"/d' \
		-e '/^\.nf/d' -e '/^\.fi/d' \
		-e '/^\.if/d' -e '/^\.ta/d' -e '/^\.nr/d' \
		-e '/^\.in/d' -e 's/^\.[BI] //' \
		`ls -1 man/*.? man/*.??` |
	${AWK} -f format.awk - > $MAN

	./inst chmod 644 $MAN
	) &
	;;

splitdb)
	(
	echo
	echo "Rearranging $DBDATA directory for better performance."
	echo "Notice:  If interrupted, the database must be rebuilt!"
	echo "Be patient.  This may take a while...."
	echo

	$MASTER/nnmaster -l "DATABASE UPGRADE IN PROGRESS"

	OLDDB="${DBDATA}-old"
	mv ${DBDATA} ${OLDDB} || exit 1
	./inst mkdir "$DBDATA" 755 || exit 1

	Ngrp="`cat ${DB}/GROUPS | wc -l`"
	Ngrp="`expr $Ngrp + 1`"
	Ndir="`expr $Ngrp / 100`"

	i=0
	while [ $i -le $Ndir ]
	do
		./inst mkdir "${DBDATA}/${i}" 755 || exit 1
		i="`expr $i + 1`"
	done

	cd ${OLDDB}
	i=$Ndir
	while [ $i -ge 1 ]
	do
		if [ "`echo ${i}[0-9][0-9].[dx]`" != "${i}[0-9][0-9].[dx]" ]
		then
			echo "Moving groups ${i}00-${i}99 to ${DBDATA}/${i}"
			mv ${i}[0-9][0-9].[dx] ${DBDATA}/${i}
		fi
		i="`expr $i - 1`"
	done
	if [ "`echo *.[dx]`" != '*.[dx]' ]
	then
		echo "Moving groups 0-99 to ${DBDATA}/${i}"
		mv *.[dx] ${DBDATA}/0
	fi

	cd /tmp
	rm -r ${OLDDB}

	$MASTER/nnmaster -l

	echo "Database reorganization completed."
	echo
	)
	;;

init)
	echo
	./inst mkdir "$DB" 755 || exit 1
	if [ -n "$DBDATA" ] ; then
		if [ -d "$DBDATA" -a "$DBDATA" = "${DB}/DATA" ]
		then
			echo "Removing old data files"
			( cd /tmp && rm -r "$DBDATA" )
		fi
		./inst mkdir "$DBDATA" 755 || exit 1
		if $DBSHORTNAME
		then
			./inst mkdir "$DBDATA/0" 755 || exit 1
		fi
	fi

	if $NNTP ; then
		if [ x"$NNTPCACHE" != "x" ] ; then
			./inst mkdir "$NNTPCACHE" 777 || exit 1
		fi	
		ILIMIT=50
		DFLT=50

		cat <<'EOF'
	
When nnmaster is started the first time after initializing nn's
database, it will attempt to fetch all the articles from the nntp
server.  It does this by successively requesting each article in the
range min..last obtained from the NNTP server.  Often the 'min' number
is unreliable or even zero (Cnews doesn't maintain it).  This means
that the nnmaster will request a lot of non-existing articles from the
server, causing a lot of network traffic.

To limit this activity, nn will normally only attempt to fetch the
fifty newest articles in each group.  This shouldn't really be a
problem since that will give you enough news to start with, and the
older articles will probably be expired in a few days anyway.

You can change this limit if you like.  Or you can disable this
limitation completely if you trust the min field by giving a 0 limit.

EOF
	else
		ILIMIT=""
		DFLT="none"

		cat <<'EOF'

If the 'min' field in your active file is not reliable, nnmaster can
waste a lot of time trying to locate non-existing articles in the news
groups when it is collecting the available articles the first time it
is started after the database is initialized.  This is especially true
with Cnews where the min field is not normally maintained.

To limit the efforts during the initial collection, you can set a
limit on the number of articles in each group which nnmaster should
try to locate in each group.  This may get you running faster, and it
shouldn't matter much anyway since the articles that may be ignored
will be the oldest articles in the group, and they will probably be
expired soon anyway.  A value in the range 100-500 should be more than
enough.  If you don't specify a limit, all articles will be collected,
but it may take quite some time if the min fields are unreliable.

EOF
	fi

	${AWK} 'END{printf "Initial article limit ('"$DFLT"') "}' < /dev/null
	read L
	if [ -n "$L" ] ; then
		ILIMIT="$L"
	fi

	echo Running nnmaster -I $ILIMIT to initialize database....
	echo
	$MASTER/nnmaster -I $ILIMIT
	echo
	echo "Now start $MASTER/nnmaster [ -D ] [ -r ]"
	;;
esac

done

if [ -f $LOG ]
then
	chmod 666 $LOG
fi

if $PAUSE
then
${AWK} 'BEGIN{printf("\nHit return to continue....")}' < /dev/null
read X
fi
done
