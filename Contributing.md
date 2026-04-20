<img src="./doc/Logo.png" alt="Logo" width="400">

[Back to **Readme**](./Readme.md)

# How to Contribute to Open Logic

Of course you are more than welcome to contribute to the project. This document explains how you can do so.

There [YouTube Video](https://www.youtube.com/watch?v=Ugm9VoZOdo0) about contributing to _Open Logic_ aavailable,
which is a good and quick starting point.

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

You can donate through [GitHub sponsors](https://github.com/sponsors/open-logic). **In case your company better like
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

### Contributor License Agreement

To get any contributions accepted, the _Contributors License Agreement_ (CLA) must be signed. You can do this
through [cla-assistant.io](https://cla-assistant.io/open-logic/open-logic).

### Copyright

You may add your own copiright notice to any file you contribute to. However, for contributions to be accepted, you
must sign the [Contributor License Agreement](https://cla-assistant.io/open-logic/open-logic).

### Gernerative AI Policy

Generative AI may be used for contributions as long as the contributor is fully aware of the content generated,
takes full responsibility for it and ensured that no copyrighted content from third parties is included.

The usage of genenerative AI beyond accepting inline code suggestions (e.g. GitHub Copilot) is restricted as follows:

- It is forbidden for any contributions towards features funded by [NLnet](https://nlnet.nl/)
- It mus be disclosed in the pull request description

# Code of Conduct

We are committed to providing a friendly, safe and welcoming environment for all, regardless of level of experience, gender identity and expression, sexual orientation, disability, personal appearance, body size, race, ethnicity, age, religion, nationality, or other similar characteristic.
Please avoid using overtly sexual aliases or other nicknames that might detract from a friendly, safe and welcoming environment for all.
Please be kind and courteous. There’s no need to be mean or rude.
Respect that people have differences of opinion and that every design or implementation choice carries a trade-off and numerous costs. There is seldom a right answer.
Please keep unstructured critique to a minimum. If you have solid ideas you want to experiment with, make a fork and see how it works.
We will exclude you from interaction if you insult, demean or harass anyone. That is not welcome behavior. We interpret the term “harassment” as including the definition in the Citizen Code of Conduct; if you have any lack of clarity about what might be included in that concept, please read their definition. In particular, we don’t tolerate behavior that excludes people in socially marginalized groups.
Private harassment is also unacceptable. No matter who you are, if you feel you have been or are being harassed or made uncomfortable by a community member, please contact one of the channel ops or any of the Rust moderation team immediately. Whether you’re a regular contributor or a newcomer, we care about making this community a safe place for you and we’ve got your back.
Likewise any spamming, trolling, flaming, baiting or other attention-stealing behavior is not welcome.
