LIBSUBDIRS=	src src-cpp

CHECK_FILES+=	CONFIGURATION.md \
		examples/rdkafka_example examples/rdkafka_performance \
		examples/rdkafka_example_cpp

PACKAGE_NAME?=	librdkafka
VERSION?=	$(shell python rpm/get_version.py)

# Jenkins CI integration
BUILD_NUMBER ?= 1

.PHONY:

all: mklove-check libs CONFIGURATION.md check

include mklove/Makefile.base

libs:
	@(for d in $(LIBSUBDIRS); do $(MAKE) -C $$d || exit $?; done)

CONFIGURATION.md: src/rdkafka.h examples
	@printf "$(MKL_YELLOW)Updating$(MKL_CLR_RESET)\n"
	@echo '//@file' > CONFIGURATION.md.tmp
	@(examples/rdkafka_performance -X list >> CONFIGURATION.md.tmp; \
		cmp CONFIGURATION.md CONFIGURATION.md.tmp || \
		mv CONFIGURATION.md.tmp CONFIGURATION.md; \
		rm -f CONFIGURATION.md.tmp)

file-check: CONFIGURATION.md examples
check: file-check
	@(for d in $(LIBSUBDIRS); do $(MAKE) -C $$d $@ || exit $?; done)

install:
	@(for d in $(LIBSUBDIRS); do $(MAKE) -C $$d $@ || exit $?; done)

examples tests: .PHONY libs
	$(MAKE) -C $@

docs:
	doxygen Doxyfile
	@echo "Documentation generated in staging-docs"

clean-docs:
	rm -rf staging-docs

clean:
	@$(MAKE) -C tests $@
	@$(MAKE) -C examples $@
	@(for d in $(LIBSUBDIRS); do $(MAKE) -C $$d $@ ; done)

distclean: clean
	./configure --clean
	rm -f config.log config.log.old

archive:
	git archive --prefix=$(PACKAGE_NAME)-$(VERSION)/ \
		-o $(PACKAGE_NAME)-$(VERSION).tar.gz HEAD
	git archive --prefix=$(PACKAGE_NAME)-$(VERSION)/ \
		-o $(PACKAGE_NAME)-$(VERSION).zip HEAD

build_prepare: distclean
	mkdir -p SOURCES
	git archive --format tar --output SOURCES/librdkafka-$(VERSION).tar HEAD:

srpm: build_prepare
	/usr/bin/mock \
		--define "__version $(VERSION)"\
		--define "__release $(BUILD_NUMBER)"\
		--resultdir=. \
		--buildsrpm \
		--spec=rpm/librdkafka.spec \
		--sources=SOURCES

rpm: srpm
	/usr/bin/mock \
		--define "__version $(VERSION)"\
		--define "__release $(BUILD_NUMBER)"\
		--resultdir=. \
		--rebuild *.src.rpm
