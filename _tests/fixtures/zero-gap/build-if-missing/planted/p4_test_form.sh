#!/bin/sh
# planted: the test(1) spelling
test -x ./dist/app.js || npm run build
exec node ./dist/app.js
