GENERATED_TYPES := bool string int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 byte rune float32 float64 complex64 complex128
# on mac use gsed
UNAME_S = $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	SED = gsed
else
	SED = sed
endif

.PHONY: all
all: codegen code

.PHONY: ipv6code generics codegen codegen-%
codegen: ipv6code generics $(addprefix codegen-,$(GENERATED_TYPES))

ipv6code:
	cp template/tree_v4.go template/tree_v6_generated.go
	$(SED) -i -e 's/Template file./Code generated by automation. DO NOT EDIT/' template/tree_v6_generated.go
	$(SED) -i -e 's/TreeV4/TreeV6/g' template/tree_v6_generated.go
	$(SED) -i -e 's/TreeIteratorV4/TreeIteratorV6/g' template/tree_v6_generated.go
	$(SED) -i -e 's/treeNodeV4/treeNodeV6/g' template/tree_v6_generated.go
	$(SED) -i -e 's/IPv4Address/IPv6Address/g' template/tree_v6_generated.go

generics: codegen-generics
	# generics -> T, except in tests
	( cd generics_tree && $(SED) -i -E -e 's/\bgenerics\b/string/g' *_test.go)
	( cd generics_tree && $(SED) -i -E -e 's/\bgenerics\b/T/g' *.go)
	# Each defined type should be parametrized with T
	( cd generics_tree && $(SED) -nE 's/^type (\w+).*/\1/p' *.go \
	        | grep -vFx treeIteratorNext \
		| while read T; do \
			$(SED) -i -E -e 's/\b'$$T'\b/\0[T]/g' *.go ; \
			$(SED) -i -E -e 's/\b('$$T')\[T\]/\1[string]/g' *_test.go ; \
		  done )
	# Fix type definition
	( cd generics_tree && $(SED) -i -E -e 's/^(type \w+)\[T\]/\1[T any]/' *.go)
	# NewTreeVX function should be parametrized
	( cd generics_tree && $(SED) -i -E -e 's/^(func NewTreeV.)/\1[T any]/' *.go)
	( cd generics_tree && $(SED) -i -E -e 's/(NewTreeV.)\(/\1[string](/g' *_test.go)
	# No need to cast interfaces
	( cd generics_tree && $(SED) -i -E -e 's/\.\(string\)//g' *_test.go)

codegen-%:
	@echo "** generating $* tree"
	mkdir -p "./${*}_tree"
	cp -pa template/*.go "./${*}_tree"
	test "${*}" = generics || rm -f ./${*}_tree/*_test.go
	rm -f ./${*}_tree/types.go
	( cd "${*}_tree" && $(SED) -i "s/Template file./Code generated by automation. DO NOT EDIT/g" *.go )
	( cd "${*}_tree" && $(SED) -i "s/GeneratedType/${*}/g" *.go )
	( cd "${*}_tree" && $(SED) -i "s/package template/package ${*}_tree/g" *.go )

.PHONY: clean
clean:
	rm -rf *_tree
	rm -f template/tree_v6_generated.go

.PHONY: code
code:
	go build -v ./...

.PHONY: test
test:
	go test -v ./... --cover --race
