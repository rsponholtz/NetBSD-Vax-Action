#!/bin/bash

#set -eu
set -x

arg_run="$1"
arg_path="$2"

echo "unpacking bsd disk image"
[ -f ../ci.dsk.gz ] && gzip -d ../ci.dsk.gz

echo "mounting 44bsd file system"
sudo mkdir /bsd
sudo chown $USER /bsd
sudo mount -r -t ufs -o ufstype=44bsd ../ci.dsk /bsd
rsync -a --safe-links --ignore-errors "$PWD/" "/bsd/" || true

echo "unmounting bsd filesystem"
sudo umount /bsd
sudo rmdir /bsd

DATE=$(date +%y%m%d%H%M)

echo "Date will be set to $DATE"

cat - > pdp.expect <<EOF
#!/usr/bin/expect -f
spawn ../simh/BIN/microvax3900 netbsd-run-vax.ini

expect ">>>"  {send "boot dua0\n"}

expect "login: " {send "root\n"}

expect "# " {send "date $DATE\n"}

proc checkrun {cmd} {
  expect "# " { send "\$cmd\n" }
  expect "# " {send "echo \\\$?\n"}

  expect -re "(\\\\d+)" {
    set result \$expect_out(1,string)
  }

  if { \$result == 0 } {
  } elseif { \$result == 4 } {
  } else {
    exit \$result
  }
}

set timeout -1

expect "# " {send "mkdir -p $arg_path\n"}
expect "# " {send "mkdir /scratch\n"}
expect "# " {send "cd /dev\n"}
expect "# " {send "./MAKEDEV ra1\n"}
expect "# " {send "mount /dev/ra1a /scratch\n"}
expect "# " {send "cd /\n"}
expect "# " {send "cp -r /scratch/ $arg_path/\n"}
expect "# " {send "cd $arg_path\n"}
expect "# " {send "umount /scratch\n"}
EOF

while IFS= read -r line; do
    cat >> pdp.expect <<EOF
checkrun "$line"
EOF

done <<< "$arg_run"

cat >> pdp.expect <<EOF
checkrun "sync"
checkrun "sleep 5"
expect "# " {send "shutdown now\n"}

EOF

chmod +x pdp.expect
./pdp.expect
exit $?
