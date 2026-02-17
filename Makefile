.PHONY: check lint package clean

check: lint package

lint:
	luacheck .

package:
	bash package.sh

clean:
	rm -rf dist/
