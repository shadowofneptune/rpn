# RPN
![rpn](https://github.com/shadowofneptune/rpn/assets/56777828/9d0edbb6-fa2e-496a-a641-0a53aa373d96)

### Version 1.0

RPN is a reverse-polish notation calculator. It comes
with a **built-in manual**.

## Build instructions

Open the project in Lazarus. Go to Project > Project Options..., then under
Build Settings, go to Custom Options. You will see a line like this:

```
-Sm -dRPN_TZ:=
```

RPN_TZ is a variable used to generate the build number. Set it to your local
UTC timestamp, rounded to the nearest integer. For example, this is how I
set it for my local Arizona time:

```
-Sm -dRPN_TZ:=-7
```

Set this for all build modes except for Clean. Don't worry about messing it up;
I made it so that Lazarus will yell at you until you get it right.

Finally, go under Build > Build many modes, and build the version that makes
sense for you.

## Examples

After **reading the manual**, you can try importing a transcript. There's one
I have gotten plenty of use out of in 'examples'.

## Warnings

This only has tested to work with Linux (on a Debian 11 box), and with Windows,
(using WINE on that same box). Your milage may vary. Please leave an issue
and I will do the best I can to help.

This has been tested to be as free of bugs, daemons, or other maledictions as
I can with the resources available to me. May Almighty God bless your system,
and leave an issue if He could not help you.

