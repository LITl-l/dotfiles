# T2 — persistent key-value store

Implement `./run`, a key-value store that keeps its data on disk.

## Invocation

    ./run --data <dir>

- `<dir>` already exists. It is empty the first time and is yours: keep whatever files
  you like in it. Store nothing anywhere else.
- `./run` may be started again and again on the same `<dir>`. Every start must see the
  data that earlier runs acknowledged.
- `./run` reads commands from standard input, one per line, and exits with status 0 at
  end of input.

## Commands and replies

Every command gets exactly one reply line. Write each reply and flush standard output
before you read the next command: the client waits for each reply before it sends more.
It may also send several commands at once without waiting, and it must still get one
reply per command, in order.

| Command          | Reply                                                                        |
|------------------|------------------------------------------------------------------------------|
| `SET <k> <v>`    | `OK`. Stores value `<v>` under key `<k>` and replaces any earlier value.     |
| `GET <k>`        | `VAL <v>` when `<k>` holds a value, otherwise `NIL`.                         |
| `DEL <k>`        | `OK`, whether or not `<k>` existed. Afterwards `GET <k>` replies `NIL`.      |
| `SCAN <prefix>`  | `KEYS` followed by every stored key that starts with `<prefix>`.            |

- Keys, values and prefixes are 1 to 64 characters from `A-Z a-z 0-9 _ . : / -`. They
  never contain spaces. Fields are separated by a single space.
- `SCAN` lists matching keys in ascending byte order (ASCII order, so `B` sorts before `a`),
  separated by single spaces, for example `KEYS a1 a2 ab`. With no match, the reply is
  just `KEYS`.
- Lines end with `\n`. The client never sends a malformed command.

Example session:

    SET user:1 alice      ->  OK
    SET user:2 bob        ->  OK
    GET user:1            ->  VAL alice
    SCAN user:            ->  KEYS user:1 user:2
    DEL user:1            ->  OK
    GET user:1            ->  NIL
    SCAN user:            ->  KEYS user:2

## Durability

`OK` means the write is durable. Once `OK` for a `SET` or `DEL` has been written, that
write must survive the process being killed at any moment (`kill -9`) **and** the
machine losing power. A clean exit at end of input must lose nothing either.

After a crash, the next start must see every acknowledged write. It may also see some
later writes that it had received but not yet acknowledged, but only in order: the data
must equal the result of applying, in the order received, every command up to some point
at or after the last acknowledged one. A deleted key must never come back.
