NODE_MODULES_BIN := ./node_modules/.bin
TS_NODE_BASE := TS_NODE_TRANSPILE_ONLY=true node -r ts-node/register
WEBPACK := $(TS_NODE_BASE) $(NODE_MODULES_BIN)/webpack
KARMA := $(TS_NODE_BASE) $(NODE_MODULES_BIN)/karma start

generateTypes ?= generateTypes
es ?= es2015
uglify ?= true
excludeLangs ?= false
browsers ?= FirefoxHeadless
singleRun ?= true
isTest ?= false
updateTests ?= false
version = $(shell cat package.json | jq -r '.version')

.PHONY: start
start:
	$(WEBPACK) serve --progress --mode development \
		--env stat=true \
		--env es=$(es) \
		--env uglify=$(uglify) \
		--env excludeLangs=${excludeLangs} \
		--env isTest=$(isTest)

.PHONY: build
build:
	$(WEBPACK) --progress --mode production \
		--env stat=true \
		--env es=$(es) \
		--env uglify=$(uglify) \
		--env excludeLangs=${excludeLangs} \
		--env isTest=$(isTest) \
		--env generateTypes=$(generateTypes)

.PHONY: esm
esm:
	rm -rf ./build/esm
	tsc -p tsconfig.json --module es2020 --target es2020 --removeComments false --sourceMap false --outDir ./build/esm
	$(TS_NODE_BASE) ./build-system/utils/resolve-alias-imports.ts ./build/esm

.PHONY: build-all
build-all:
	make clean
	make build es=es2018 uglify=false generateTypes=true
	make dts
	make build es=es2018

	make build es=es2015
	make build es=es2015 uglify=false

	make build es=es5
	make build es=es5 uglify=false

	make build es=es2018 excludeLangs=true
	make build es=es2018 excludeLangs=true uglify=false

	make esm

.PHONY: lint
lint:
	tsc --noemit --noErrorTruncation
	eslint ./src/ ./test/
	stylelint ./src/**/**.less

.PHONY: fix
fix:
	npx eslint ./src/ ./test/ --fix
	make prettify

prettify:
	npx prettier --write ./src/*.{ts,less} ./src/**/*.{ts,less} ./src/**/**/*.{ts,less} ./src/**/**/**/*.{ts,less} ./src/**/**/**/**/*.{ts,less}

.PHONY: test
test:
	make test-find
	make clean
	make build es=$(es) uglify=false isTest=true
	make test-only-run es=$(es)

.PHONY: test-find
test-find:
	$(TS_NODE_BASE) ./build-system/utils/find-tests.ts

.PHONY: test-only-run
test-only-run:
	$(KARMA) --browsers $(browsers) ./test/karma.conf.ts --single-run $(singleRun)

.PHONY: clean
clean:
	rm -rf ./node_modules/.cache && rm -rf build/*

.PHONY: dts
dts:
	mkdir -p ./build/types/types
	cp -R ./tsconfig.json ./build/types/
	cp -R ./src/typings.d.ts ./build/types/
	cp -R ./src/types/* ./build/types/types
	$(TS_NODE_BASE) ./build-system/utils/resolve-alias-imports.ts ./build/types
	replace "import .+.(less|svg)('|\");" '' ./build/types -r --include='*.d.ts'

.PHONY: coverage
coverage:
	npx --yes type-coverage ./src --detail --ignore-files 'build/**' --ignore-files 'test/**' --ignore-files 'examples/**'


.PHONY: screenshots
screenshots:
	docker run -v $(pwd)/build:/app/build/ -v $(pwd)/test:/app/test/ \
		-e SNAPSHOT_UPDATE=$(updateTests) \
		-v $(pwd)/src:/app/src/ jodit-screenshots \
		node --input-type=module ./node_modules/.bin/mocha ./src/**/**.screenshot.js --build=$(es)

.PHONY: screenshots-build-image
screenshots-build-image:
	docker build -t jodit-screenshots -f test/screenshots/Dockerfile .

.PHONY: newversion
newversion:
	make lint
	make clean
	make test
	npm version patch --no-git-tag-version
	make build-all
	make newversion-git
	npm publish ./
	rm -rf types/

.PHONY: newversion-git
newversion-git:
	git add --all  && git commit -m "New version $(version) Read more https://github.com/xdan/jodit/blob/main/CHANGELOG.md "
	git tag $(version)
	git push --tags origin HEAD:main

.PHONY: jodit
jodit:
	cd ../jodit-react/
	npm update
	npm run newversion
	cd ../jodit-pro
	npm run newversion
	cd ../jodit-joomla
	npm run newversion
