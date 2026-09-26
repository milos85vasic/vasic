#!/usr/bin/env bash
# clean: existence guards that do not build anything
[ -f ./app.cfg ] || cp ./app.cfg.default ./app.cfg
# [ -x ./bin/server ] || bash ./build.sh   (commented out)
exec ./bin/server
