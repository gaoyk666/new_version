declare -r SOURCE="/usr/local"
declare -r TARGET="/mnt/hgfs/Documents/linux_executable"

rm -rf $TARGET
mkdir $TARGET
mkdir $TARGET/bin
mkdir $TARGET/lib
# mkdir $TARGET/java

cp $SOURCE/bin/opendsscmd $TARGET/bin
cp $SOURCE/bin/fncs_broker $TARGET/bin
cp $SOURCE/bin/fncs_player $TARGET/bin
cp $SOURCE/bin/fncs_tracer $TARGET/bin
cp $SOURCE/bin/helics_broker $TARGET/bin
cp $SOURCE/bin/helics_player $TARGET/bin
cp $SOURCE/bin/helics_recorder $TARGET/bin

#cp $SOURCE/java/*fncs*.* $TARGET/java
#cp -P $SOURCE/java/*helics*.* $TARGET/java

cp -P $SOURCE/lib/*fncs*.* $TARGET/lib
cp -P $SOURCE/lib/*helics*.* $TARGET/lib
cp -P $SOURCE/lib/liblinenoise.so $TARGET/lib
cp -P $SOURCE/lib/libklusolve.so $TARGET/lib

ls -altR $TARGET
