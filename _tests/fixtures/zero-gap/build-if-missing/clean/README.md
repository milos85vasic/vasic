Not a script: prose that mentions [ -x "$BIN" ] || bash build.sh inside text is still scanned as a line, and stays clean only because this line is not a guard at line start.
