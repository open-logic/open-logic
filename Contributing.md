<img src="./doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](./Readme.md)

# How to Contribute to Open Logic

Of course you are more than welcome to contribute to the project. This document explains how you can do so.

## Be a _Good_ User

The easiest way of doing so, is by simply using _Open Logic_ - and report any issues you find. That may be an idea for a
new feature, a bug or simply unclear documentation. Any feedback is appreciated and will help improving the usability of
_Open Logic_.

For bug reports, **always include/attach steps to reproduce the behavior**. This could be (in decreasing order of their
helpfulness):

- A an existing _Open Logic_ testbench, modified to reproduce the bug
- A single-file testbench you wrote your own
  - If you are not used to VUnit (all _Open Logic_ testbenches are VUnit based) this probably is easier.
- A questa *.do file
- A screenshot of a waveform
- A textual description

## Financial Contributions

You can donate through [GitHub sponsors](https://github.com/sponsors/open-logi). **In case your company better like
buying services than doing donations** - you can also find things to buy on the GitHub sponsors page (e.g. workshops or
priority support).

Where do the donations go:

- Tools and Subscriptions (e.g. cloud storage, tool cost)
- Infrastructure (e.g. a dedicated GitHub runner PC and the energy cost for it)
- Community Building (e.g. travel expenses for attending conferences and present _Open Logic_ there)

If you are willing to do a financial contribution for any service/activity not listed on GitHub sponsors (e.g. if you
want to pay some money for me giving a Keynote) - contact me through e-mail
[oli.bruendler@gmx.ch](oli.bruendler@gmx.ch).
  
## Contribute Code

For all contributions credits are given in the release notes.

### Conventions

For all contributions, please follow the [Conventions](./doc/Conventions.md).

### Simple Fixes

This category include **fixing documentation or bugs** in a way that is **not visible from outside**. This clearly
excludes bigger changes (e.g. addition of new components, modifications to the user interface).

Follow the steps below:

1. Fork _Open Logic_ to your personal github account
2. Create a feature branch on your fork. Name the branch _feature/\<your-feature-name\>_ and branch-off from _develop_.
3. Apply your modifications
4. Ensure all tests pass - if you have access to a questa license, ensure coverage is sufficient (see
   [How To ...](./doc/HowTo.md))
5. Create a Pull Request to the _develop_ branch of the _Open Logic_ main repository.

### Larger Features

This category includes **any changes that fall outside of the _Simple Fixes_** category (e.g. new entities).

Follow the steps below:

1. **Create an issue** on _Open Logic: describing your idea.
   - For new entities, describe the concept and the user interface (ports and generics) in detail. Ideally you provide
     the code of the entity declaration you foresee.
   - For modifications, describe the modification in detail and what is changed on the user interface - if any.
2. We will discuss your idea in the issue. This step is important for me because I have a strong focus in easy-to-use
   user interfaces and I would like to **discuss your plans** before changes cost you too much time.
3. Once dicussions are concluded, fork _Open Logic_ to your personal github account
4. Create a feature branch on your fork. Name the branch _feature/\<your-feature-name\>_ and branch-off from _develop_.
5. Apply your modifications.
   - Include a self-checking VUnit testbench
   - Include documentation
6. Ensure all tests pass - if you have access to a questa license, ensure coverage is sufficient (see
   [How To ...](./doc/HowTo.md))
7. Create a Pull Request to the _develop_ branch of the _Open Logic_ main repository.

### You don't have own Ideas

If you want to support the project but you do not have specific features in mind which you could implement, you can have
a look at the [Feature Ideas](https://github.com/open-logic/open-logic/wiki/Feature-Ideas) list in the Wiki or contact
me and I will suggest features. There is always more than enough to do.

### License

By contributing, you agree that your contributions will be licensed under the [License.txt](./License.txt) file in the
root directory.

### Copyright

Any contribution must give the copyright to Oliver Bründler. This is necessary to manage the project freely. Copyright
is given by adding the copyright notice to the beginning of each file.

```vhdl
Copyright (c) 2024 by Oliver Bründler
All rights reserved.
```

Of course the year must be adjusted to the year of the contribution and could also be a span like `2024-2025`.
