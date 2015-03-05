# Tests for mmap-io (duh!)
#
# Some lines snatched from Ben Noordhuis test-script of "node-mmap"

fs =        require "fs"
#mmap =      require "./build/Release/mmap-io.node"
mmap =      require "./mmap-io"
assert =    require "assert"
constants = require "constants"
#errno =     require "errno"
errno = errno: []   # foo.... *TODO*

say = (...args) -> console.log.apply console, args

say "mmap in test is", mmap

{PAGESIZE, PROT_READ, PROT_WRITE, MAP_SHARED} = mmap

try
    say "mmap.PAGESIZE = ", mmap.PAGESIZE, "tries to overwrite it with 47"
    mmap.PAGESIZE = 47
    say "now mmap.PAGESIZE should be the same:", mmap.PAGESIZE, "silently kept"
catch e
    say "Caught trying to modify the mmap-object. Does this ever happen?", e

# open self (this script)
fd = fs.open-sync(process.argv[1], 'r')
size = fs.fstat-sync(fd).size
say "file size", size

# full 6-arg call
buffer = mmap.map(size, PROT_READ, MAP_SHARED, fd, 0, mmap.MADV_SEQUENTIAL)
say "buflen 1 = ", buffer.length
assert.equal(buffer.length, size)

say "Give advise with 2 args"
mmap.advise buffer, mmap.MADV_NORMAL

say "Give advise with 4 args"
mmap.advise buffer, 0, mmap.PAGESIZE, mmap.MADV_NORMAL

# Read the data..
say "\n\nBuffer contents, read byte for byte backwards, stringified is:\n"
out = ""
for ix from (size - 1) to 0 by -1
    out += String.from-char-code(buffer[ix])

say out, "\n\n"

try
    say "read out of bounds test:", buffer[size + 47]
catch e
    say "caught deliberate out of bounds exception- does this thing happen?", e.code, errno.errno[e.code], 'err-obj = ', e

# Ok, I won't write a segfault catcher cause that would be evil, so this will simply be uncatchable.. /ORC
#try
#    say "Try to write to read buffer"
#    buffer[0] = 47
#catch e
#    say "caught deliberate segmentation fault", e.code, errno.errno[e.code], 'err-obj = ', e


# 5-arg call
buffer = mmap.map(size, PROT_READ, MAP_SHARED, fd, 0)
say "buflen test 1 = ", buffer.length
assert.equal(buffer.length, size)

# 4-arg call
buffer = mmap.map(size, PROT_READ, MAP_SHARED, fd)
say "buflen test 2 = ", buffer.length
assert.equal(buffer.length, size)

# Snatched from Ben Noordhuis test-script:
# page size is almost certainly >= 4K and this script isn't that large...
fd = fs.open-sync(process.argv[1], 'r')
buffer = mmap.map(size, PROT_READ, MAP_SHARED, fd, PAGESIZE)
say "buflen test 3 = ", buffer.length
assert.equal(buffer.length, size);    # ...but this is according to spec

# non int param should throw exception
fd = fs.open-sync(process.argv[1], 'r')
try
    buffer = mmap.map("foo", PROT_READ, MAP_SHARED, fd, 0)
catch e
    say "Pass non int param - caught deliberate exception ", e.code, errno.errno[e.code], 'err-obj = ', e
    assert.equal(e.code, constants.EINVAL)

# zero size should throw exception
fd = fs.open-sync(process.argv[1], 'r')
try
    buffer = mmap.map(0, PROT_READ, MAP_SHARED, fd, 0)
catch e
    say "Pass zero size - caught deliberate exception ", e.code, errno.errno[e.code], 'err-obj = ', e
    assert.equal(e.code, constants.EINVAL)

# non-page size offset should throw exception
WRONG_PAGE_SIZE = PAGESIZE - 1
fd = fs.open-sync(process.argv[1], 'r')
try
    buffer = mmap.map(size, PROT_READ, MAP_SHARED, fd, WRONG_PAGE_SIZE)
catch e
    say "Pass wrong page-size as offset - caught deliberate exception ", e.code, errno.errno[e.code], 'err-obj = ', e
    assert.equal(e.code, constants.EINVAL)


# faulty param to advise should throw exception
fd = fs.open-sync(process.argv[1], 'r')
try
    buffer = mmap.map(size, PROT_READ, MAP_SHARED, fd)
    mmap.advise buffer, "fuck off"
catch e
    say "Pass faulty arg to advise() - caught deliberate exception ", e.code, errno.errno[e.code], 'err-obj = ', e
    assert.equal(e.code, constants.EINVAL)


# Write tests

say "Now for some write/read tests"

try
    say "Creates file"

    test-file = "./tmp-mmap-file"
    test-size = 47474

    fs.write-file-sync test-file, ""
    fs.truncate-sync test-file, test-size

    say "open write buffer"
    fd-w = fs.open-sync test-file, 'r+'
    say "fd-write = ", fd-w
    w-buffer = mmap.map(test-size, PROT_WRITE, MAP_SHARED, fd-w)
    fs.close-sync fd-w
    mmap.advise w-buffer, mmap.MADV_SEQUENTIAL

    say "open read bufer"
    fd-r = fs.open-sync test-file, 'r'
    r-buffer = mmap.map(test-size, PROT_READ, MAP_SHARED, fd-r)
    fs.close-sync fd-r
    mmap.advise r-buffer, mmap.MADV_SEQUENTIAL

    say "verify write and read"

    for i from 0 til test-size
        #say "i", i
        val = 32 + (i % 60)
        w-buffer[i] = val
        assert.equal r-buffer[i], val

    say "Write/read verification seemed to work out"

catch e
    say "Something fucked up in the write/read test: ", e.code, errno.errno[e.code], 'err-obj = ', e

try
    say "sync() tests x 4"

    say "1. Does explicit blocking sync to disk"
    mmap.sync w-buffer, 0, test-size, true, false

    say "2. Does explicit blocking sync without offset/length arguments"
    mmap.sync w-buffer, true, false

    say "3. Does explicit sync to disk without blocking/invalidate flags"
    mmap.sync w-buffer, 0, test-size

    say "4. Does explicit sync with no additional arguments"
    mmap.sync w-buffer

catch e
    say "Something fucked up for syncs: ", e.code, errno.errno[e.code], 'err-obj = ', e

try
    fs.unlink-sync test-file
catch e
    say "Failed to remove test-file", test-file
