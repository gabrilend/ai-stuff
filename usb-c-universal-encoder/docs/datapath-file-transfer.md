# Datapath — moving one file across the wire

This traces a single file from a datasource on one machine to a consumer on the
other, naming every stage it passes through. It is the reference the encoder,
interpreter, framing, and USB layers must all agree with; when any of them change,
this document changes with them.

## The path of one file

```
 SENDER                                             RECEIVER
 ------                                             --------
 datasource                                         consumer
   |  raw bytes                                        ^  file bytes + direction
   v                                                   |
 store:put(path, bytes)                              store (mutated)
 store:set_meta(path,"direction",...)                  ^
   |                                                    |
   v                                                    |
 encoder  --> opcode byte stream                     interpreter (dispatch table)
   |            OP_FILE_PUT path,bytes                   ^  applies each opcode
   |            OP_FILE_META path,key,val                |  to the store
   v                                                    |
 framing:  [len][crc][ opcode bytes ]               deframing: validate len+crc
   |                                                    ^
   v                                                    |
 link:send(frame)  ------------------------------>  link:recv() -> frame
   |                                                    ^
   v                                                    |
 USB bulk-OUT endpoint  ===== USB-C wire =====>  USB bulk-IN endpoint
   (host: libusb transfer /                          (device: FunctionFS read /
    device: FunctionFS write)                          host: libusb transfer)
```

The wire is symmetric: either end can be sender or receiver, and the return path
(receiver rewrites a file and sends it back) is the same diagram mirrored.

## Stage responsibilities

1. **datasource → store.** Whatever produces bytes (a sensor, typed text, a
   generated encoding) writes them into a file in the RAM store, and optionally
   sets a `direction` metadata field saying how the far end should handle it.

2. **store → encoder.** The encoder walks a file (or a set of changed files) and
   emits opcodes: `OP_FILE_PUT` for contents, `OP_FILE_META` for each metadata
   field. The encoder is *data generation* — it only reads the store and produces
   bytes; it never touches the wire.

3. **encoder → framing.** The opcode stream is chunked into frames, each prefixed
   with a length and a checksum, so the receiver can tell a whole, intact frame
   from a partial or corrupted one.

4. **framing → link → USB.** The `link` interface carries a frame's bytes. Its
   backend is a loopback or pipe during development, and a USB bulk endpoint pair
   in production. Nothing above the link knows or cares which.

5. **USB → deframing.** The receiver reassembles frames, checks length and
   checksum, and rejects (errors, never silently drops) anything malformed.

6. **deframing → interpreter → store.** The interpreter reads opcodes one at a
   time and dispatches each to a handler that mutates the store. This is the *only*
   code that runs against received bytes, and it can do nothing but change files.

7. **store → consumer.** The receiving application reads the file (and its
   `direction`) out of the store and does whatever it does with it.

## The invariant this datapath protects

Bytes that came from the far end are touched by exactly one piece of local logic —
the interpreter — and that logic's entire vocabulary is "change a file in the
store." No stage between the wire and the store can be steered into running the
received bytes as code, because no such capability is wired into the path.
