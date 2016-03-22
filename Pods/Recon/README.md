# Record Notation (RECON)

RECON brings attributes into the era of object notation, and provides a simple
grammar and uniform tree model for attributed text markup.  RECON aims to
combine the minimalism of JSON with the expressiveness of XML in a
human-friendly syntax.

## Getting Started

To get started with the RECON Swift library, add the following to your
[CocoaPods](https://cocoapods.org) profile:

```
use_frameworks!
pod 'Recon'
```

Next run `pod install` to load the dependency.  Then import the `Recon`
module in your code.

```swift
import Recon
```

## Language Primer

### Primtives

RECON has three primitive datatypes: _text_, _number_, and _data_.

#### Text

Text values take one of two forms: a quoted _string_, or an unquoted
_identifier_.

```recon
"string"
identifier
```

#### Numbers

Numbers serialize as decimal literals.

```recon
-1
3.14
6.02e23
```

#### Data

Binary data serializes as a leading '%' symbol, followed by a base64 literal.

```recon
%AA==
```

### Records

RECON's sole aggregate datatype, the _record_, plays the combined role of array
and associative array.  Think of a record as a partially keyed list.  The
example record below contains two ordered items, first a "subject" field with
value "Greetings", then the unkeyed string "Hello, Earthlings!".

```recon
{ subject: "Greetings", "Hello, Earthlings!" }
```

A single comma, a single semicolon, or one or more newlines separate items.
Newline separated records provide a clean syntax for pretty-printed documents.

```recon
{
  subject: "Re: Greetings"
  "Hi Martians!"
}
```

Records support arbitrary values as slot keys.

```recon
{
  @planet Jupiter: {}
  @god Jupiter: {}
}
```

### Blocks

Top-level documents can omit the curly braces around their root record.  We
call the content of a record, sans curly braces, a _block_.  When a block
contains only a single item, the value of the block reduces to just the value
of the item it contains.  The example block below is equivalent to the sample
record above.

```recon
subject: "Re: Greetings"
"Hi Martians!"
```

### Attributes

The @ sign introduces an attribute.  Attributes call out key fields of a
record.  The previous markup example further reduces to the form below.

```recon
{
  "Hello, "
  {
    "@em":
    "world"
  }
  "!"
}
```

Note that the `@em` field above has no explicit value.  The RECON data model
refers to unspecified–but existent–values as _extant_.  We say that the record
`@em[world]` has an extant attribute named `em`.

Of course, attributes can have associated values too.  Place attribute
parameters in parentheses, following the attribute's name.

```recon
@answer(42)
@event("onClick")
```

The above attributes are structurally equivalent to:

```recon
{"@answer":42}
{"@event":"onClick"}
```

Attribute parentheses enclose a block, meaning attribute values construct an
implicit record when needed. An example, with its desugared equivalent, follows.

```recon
@img(src: "tesseract.png", width: 10, height: 10, depth: 10, time: -1)

{
  "@img": {
    src: "tesseract.png"
    width: 10
    height: 10
    depth: 10
    time: -1
  }
}
```

Attributes _modify_ adjacent values.  Modified values interpolate into the
record formed by their adjacent attributes.  Here are some examples of values
with prefix, postfix, and circumfix attributes:

```recon
@duration 30
30 @seconds
@duration 30 @seconds
@relative @duration 30 @seconds
```

The above attribute expressions desugar to the following records:

```recon
{ "@duration":, 30 }
{ 30, "@seconds": }
{ "@duration":, 30, "@seconds": }
{ "@relative":, "@duration":, 30, "@seconds": }
```

Modified records flatten into the record formed by their adjacent attributes.
So `@point{x:0,y:0}`, reduces to `{"@point":,x:0,y:0}`, not
`{"@point":,{x:0,y:0}}`.

### Markup

Square brackets denote _markup_.  Markup offers an inverted syntax for records,
with values embedded in text, as opposed to text embedded in records.

```recon
[Hello, @em[world]!]
```

Markup is really just syntactic sugar for records.  The above example expresses
the exact same structure as the one below.

```recon
{ "Hello, "; @em "world"; "!" }
```

Curly braces within markup lift the enclosed block into the markup's record.
The following records are equivalent.

```recon
[Answer: {42}.]
{ "Answer", 42, "." }
```

Square brackets lift nested markup into the enclosing record.  Make sure to
backslash escape square brackets if you want to include them verbatim.

```recon
[Say [what]?]
{ "Say ", "what", "?"}

[Say \[what\]?]
{ "Say [what]?" }
```

Sequential attributes within markup don't chain; each markup-embedded
attribute inserts a nested record.

```recon
[http@colon@slash@slash]
{ "http", @colon, @slash, @slash }
```

Attributes in markup can prefix curly brace enclosed blocks, and nested markup.

```recon
[Goals: @select(max:2){fast,good,cheap}.]
{ "Goals: ", @select(max:2){fast,good,cheap}, "." }
```

Beware that whitespace inside markup is significant.  Notice how the single
space added to the example below completely changes its meaning, when compared
to the previous example.

```recon
[Goals: @select(max:2) {fast,good,cheap}.]
{ "Goals: ", @select(max:2), " ", {fast,good,cheap}, "." }
```

## Tutorial

Parse a RECON-encoded string by invoking the `recon` function.

```swift
let event = recon("@event(onClick),@command")!
```

Serialize a RECON value using its `recon` method.

```swift
event.recon // returns "{@event(onClick),@command}""
```

Use a value's `reconBlock` method to flatten its top-level record, if it has one.

```swift
event.reconBlock // returns "@event(onClick),@command""
```

Subscripts get a record's children by index, or by key.

```swift
let msg = recon("{from: me, to: you}")!
msg[0] // returns Attr("from", "me")
msg["to"] // returns Item("you")
```

Subscripting a non-existent key returns `Value.Absent`.

```swift
msg["cc"]
msg[2]
recon("2.0")!["number"]
```

Because `Value.Absent` is a value, subscripting is a "closed" operation.

```swift
recon("{foo: {bar: {baz: win}}}")!["foo"]["bar"]["baz"] // returns Item("win")
```

Implicit conversion from Swift literals to RECON values makes record construction easy.

```swift
Value(Attr("img", [Slot("src", "...")]), Slot("width", 10), Slot("height", 10), [Attr("caption", [Slot("lang", "en")]), "English Caption"], [Attr("caption", [Slot("lang", "es")]), "Spanish Caption"])
// returns @img(src:"..."){width:10,height:10,@caption(lang:en)"English Caption",@caption(lang:es)"Spanish Caption"}
```

### Data Model

The Swift library represents RECON values using the following algebraic data type:

```swift
enum Item {
  case Field(Recon.Field)
  case Value(Recon.Value)
}

enum Field {
  case Attr(String, Value)
  case Slot(Value, Value)
}

enum Value {
  case Record(Recon.Record)
  case Text(String)
  case Data(Recon.Data)
  case Number(Double)
  case Extant
  case Absent
}
```

## Language Grammar

```
SP ::= #x20 | #x9

NL ::= #xA | #xD

WS ::= SP | NL

Char ::= [#x1-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]

NameStartChar ::=
  [A-Z] | "_" | [a-z] |
  [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF] |
  [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D] |
  [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] |
  [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]

NameChar ::=  NameStartChar | '-' | [0-9] | #xB7 | [#x0300-#x036F] | [#x203F-#x2040]

MarkupChar ::= Char - ('\\' | '@' | '{' | '}' | '[' | ']')

StringChar ::= Char - ('"' | '\\' | '@' | '{' | '}' | '[' | ']' | '\b' | '\f' | '\n' | '\r' | '\t')

CharEscape ::= '\\' ('"' | '\\' | '/' | '@' | '{' | '}' | '[' | ']' | 'b' | 'f' | 'n' | 'r' | 't')

Base64Char ::= [A-Za-z0-9+/]

Block ::= WS* Slots WS*

Slots ::= Slot SP* ((',' | ';' | NL) WS* Slots)?

Slot ::= BlockValue (SP* ':' SP* BlockValue?)?

Attr ::= '@' Ident ('(' Block ')')?

BlockValue ::=
  Attr SP* BlockValue? |
  (Record | Markup | Ident | String | Number | Data) SP* (Attr SP* BlockValue?)?

InlineValue ::= Attr (Record | Markup)? | Record | Markup

Record ::= '{' Block '}'

Markup ::= '[' (MarkupChar* | CharEscape | InlineValue)* ']'

Ident ::= NameStartChar NameChar*

String ::= '"' (StringChar* | CharEscape)* '"'

Number ::= '-'? (([1-9] [0-9]*) | [0-9]) ('.' [0-9]+)? (('E' | 'e') ('+' | '-')? [0-9]+)?

Data ::= '%' (Base64Char{4})* (Base64Char Base64Char ((Base64Char '=') | ('=' '=')))?
```
