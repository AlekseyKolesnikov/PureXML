A simple xml engine for Delphi.
Copyright (C) 2024 by Alexey Kolesnikov.
Email: ak@blu-disc.net
Website: https://blu-disc.net

You can use this software for whatever you want.

Usage is similar to the standard Delphi xml engine, except:

  - Replace the square brackets with round brackets.
  - Instead of Attributes['blablabla'] := 'a value' you should use a setter version of the Attributes function: Attributes('blablabla', 'a value').
  - The same for the ChildValues.
  - AttributeNodes is a TStringList. Thus use Names, Values, ValueFromIndex and etc.
  - CData not supported (yet?).
  - DOMVendor, Options, Encoding are not supported.
  - To delete a node and clear its memory use RemoveAndFree.
