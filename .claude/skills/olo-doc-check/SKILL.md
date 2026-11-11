---
name: olo-doc-check
description: "check open-logic documentation on develop branch"
---

## Steps

1. For all entities in the EntityList.md document repeat the following steps:
2. Read the Markdown documentation of the entity
3. Check the source file linked
4. Check if all port names match between VHDL and Markdown
5. Check if all entity names match between VHDL and Markdown
6. Check if all default values (for ports and generics) match between VHDL and Markdown
7. Check if all link targets in the Markdown are valid.
8. Check if you find any other obvious mismatches between VHDL and Markdown
9. Write a quick report for the entity. Form, see below.

## Instructions on Parsing

All sub-sections (###, ####) that appear between "## Interfaces" (or "## Ports") and the next "## " top-level section
belong to the port table, regardless of their heading name.

## Rules

- others => '0' in VHDL and 0 in Markdown are regarded as equal
- others => '0' in VHDL and all '0'  in Markdown are regarded as equal
- toUslv(SomeVal, xxx) in VHDL and SomeVal in Markdown are regarded as equal
- bidir and inout are regarded as equal

## Report Format

```text
## <Number> <entity-name>

--> Omit the section completely if there were no mismatches.

### Generics [section only if applicable]
All Generic Mismatches as bullet list

### Ports [section only if applicable]

All Port Mismatches as bullet list

### Functionality [section only if applicable]

Functional mismatches as bullet list
```

The findings are numbered for easier reference.
