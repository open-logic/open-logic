<img src="../Logo.png" alt="Logo" width="400">

# olo_base_pkg_math

[Back to **Entity List**](../EntityList.md)

## Status Information

![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/coverage/olo_base_pkg_math.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/branches/olo_base_pkg_math.json?cacheSeconds=0) ![Endpoint Badge](https://img.shields.io/endpoint?url=https://storage.googleapis.com/open-logic-badges/issues/olo_base_pkg_math.json?cacheSeconds=0)

VHDL Source: [olo_base_pkg_math](../../src/base/vhdl/olo_base_pkg_math.vhd)

## Description

This package contains different mathematics functions not defined in IEEE packages but used by *Open Logic* internally or on its interfaces to the user (e.g. for port-widths depending on generics). The package is written mainly for these purposes and does not aim for completeness - nevertheless as a user you are free to use it for your code of course.

The package uses array-types (e.g. t_abool or t_areal) defined in [olo_base_pkg_array](./olo_base_pkg_array.md).

## Definitions

None

## Functions

### log2()

Calculate the binary logarithm of an integer number.

```
function log2(arg : in natural) return natural;
```

### log2ceil()

Calculate the binary logarithm of an integer number and round the result up. 

```
function log2ceil(arg : in natural) return natural;
```

This function can be used to calculate the number of bits required to represent a given number. An example for this usage is given below.

```
signal UpToThousand : std_logic_vector(log2ceil(1000)-1 downto 0);
```

Note that *log2ceil()* implements a special case for zero as input. Although the mathematically correct result would be *minus infinity* the function returns zero. This special case handling is useful for the usecase depicted above - returning zero results in a valid zero-length array instead of a compile error.

### isPower2()

Check if a number is a a power of two. 

```
function isPower2(arg : in natural) return boolean;
```

### max() / min()

Return the smaller or larger value out of two.

```
function max(a : in <T>; b : in <T>) return <T>;
function min(a : in <T>; b : in <T>) return <T>; 
```

Implemented for \<T\>: integer, real

### choose()

Return one or the other value based depending on a boolean input. This is useful for decisions in constant calculations.

```
function choose(s : in boolean; t : in <T>; f : in <T>) return <T>;
```

Implemented for \<T\>: integer, real, std_logic, std_logic_vector, string, unsigned, boolean, t_areal

### count()

Count the occurrences of a a given value in an array.

```
function count(a : in <A>; v : in <T>) return integer;
```

Implemented for the following \<A\> / \<T\> combinations:

* t_ainteger / integer
* t_abool / boolean
* std_logic_vector / std_logic

### toUslv() / toSslv() / toStdl()

Convert an integer value to a signed/unsigned std_logic_vector representation of a given length or a std_logic representation.

``` 
function toUslv(input : integer; len   : integer) return std_logic_vector;
function toSslv(input : integer; len   : integer) return std_logic_vector;
function toStdl(input : integer range 0 to 1) return std_logic;
```

This function is implemented as pure simplification to avoid typing the very popular conversion below over and over again:

``` 
a := std_logic_vector(to_unsigned(someInteger, a'length));
-- The same can now be written simpler
a := toUslv(someInteger, a'length);
```

### fromUslv() / fromSslv() / fromStdl()

Convert a signed/unsigned std_logic_vector value or a std_logic value into integer representation.

```
function fromUslv(input : std_logic_vector) return integer;
function fromSslv(input : std_logic_vector) return integer;
function fromStdl(input : std_logic) return integer;
```

This function is implemented as pure simplification to avoid typing the very popular conversion below over and over again:

``` 
a := to_integer(unsigned(someStdLogicVector));
-- The same can now be written simpler
a := fromUslv(someStdLogicVector);
```

### fromString()

This function converts a string into other types. 

```
function fromString(input : string) return <T>;
```

The \<T\> types is is implemented for plus some examples of the strings it takes for the corresponding conversion are given below:

* real
  * "1.234"
  * "-1.234e3"
  * "+5.67E-12"
* t_areal (real array)
  * "1.234, -1.234e3, +5.67E-12"
  * Values separated by comma (,) and NO brackets

### minArray() / maxArray()

Return the minumum / maximum value out of an array.

```
function maxArray(a : in <A>) return <T>;
function minArray(a : in <A>) return <T>;
```

Implemented for the following \<A\> / \<T\> combinations:

* t_ainteger / integer
* t_areal / real





