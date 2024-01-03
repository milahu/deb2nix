# notes



## nix-locate --at-root

or: nix-locate --regex '^/bin/bash$'

https://github.com/nix-community/nix-index/issues/233

<blockquote>

Allow filtering out results from FHS packages

There's a bunch of FHS packages in nixpkgs that essentially ship half a distro with them
and massively pollute the output when searching for packages that provides common command line tools.

</blockquote>



## default output name

https://ryantm.github.io/nixpkgs/stdenv/multiple-output/

<blockquote>

"Binaries first"

A commonly adopted convention in nixpkgs is that executables provided by the package are contained within its first output.
This convention allows the dependent packages to reference the executables provided by packages in a uniform manner.
For instance, provided with the knowledge that the perl package contains a perl executable it can be referenced as ${pkgs.perl}/bin/perl within a Nix derivation that needs to execute a Perl script.

The glibc package is a deliberate single exception to the “binaries first” convention.
The glibc has libs as its first output allowing the libraries provided by glibc to be referenced directly (e.g. ${glibc}/lib/ld-linux-x86-64.so.2).
The executables provided by glibc can be accessed via its bin attribute (e.g. ${lib.getBin stdenv.cc.libc}/bin/ldd).

</blockquote>

https://ianthehenry.com/posts/how-to-learn-nix/derivations/

> I learned that $out does not always refer to the default output path

```
nix-repl> pkgs.glibc.outputName
"out"
```



### custom-default-output-packages.txt

packages where the default output is not "out"

all other packages have "out" as their default output = first output

FIXME recursive walk of all packages

```
xclip -o | tr -d '"' | tr ' ' $'\n' >custom-default-output-packages.txt
```

FIXME use `nix eval` instead of `nix repl`

```nix
let pkgs = import <nixpkgs> {}; in (
  builtins.concatStringsSep
  " "
  (
    builtins.attrValues
    (
      builtins.mapAttrs
      (n: v: "${n}.${v.outputName}")
      (
        pkgs.lib.filterAttrs
        (n: v: (builtins.tryEval v).success && v ? outputName && v.outputName != "out")
        pkgs
      )
    )
  )
)
```



### builtins.tryEval

fix

```
error: Please be informed that this pseudo-package is not the only part of
Nixpkgs that fails to evaluate. You should not evaluate entire Nixpkgs
without some special measures to handle failing packages, like those taken
by Hydra.
```

see also https://discourse.nixos.org/t/how-to-filter-nixpkgs-by-metadata/27473



## make it faster

run nix-locate less often

```
$ nix-locate --top-level --regex '^(/bin/bzip2|/bin/bzless|/bin/bzmore|/bin/bzcmp|/bin/bzcat|/bin/bunzip2|/bin/bzegrep)$'
toybox.out                                            0 s /nix/store/sa1p3cc8pf1d6jlq31wqax10d8q50mp6-toybox-0.8.10/bin/bunzip2
toybox.out                                            0 s /nix/store/sa1p3cc8pf1d6jlq31wqax10d8q50mp6-toybox-0.8.10/bin/bzcat
bzip2.bin                                             0 s /nix/store/9gdg43h7zrn651lb1ihv2b2qf59im94b-bzip2-1.0.8-bin/bin/bunzip2
bzip2.bin                                             0 s /nix/store/9gdg43h7zrn651lb1ihv2b2qf59im94b-bzip2-1.0.8-bin/bin/bzcat
bzip2.bin                                             0 s /nix/store/9gdg43h7zrn651lb1ihv2b2qf59im94b-bzip2-1.0.8-bin/bin/bzcmp
bzip2.bin                                             0 s /nix/store/9gdg43h7zrn651lb1ihv2b2qf59im94b-bzip2-1.0.8-bin/bin/bzegrep
bzip2.bin                                        44,576 x /nix/store/9gdg43h7zrn651lb1ihv2b2qf59im94b-bzip2-1.0.8-bin/bin/bzip2
bzip2.bin                                             0 s /nix/store/9gdg43h7zrn651lb1ihv2b2qf59im94b-bzip2-1.0.8-bin/bin/bzless
bzip2.bin                                         1,259 x /nix/store/9gdg43h7zrn651lb1ihv2b2qf59im94b-bzip2-1.0.8-bin/bin/bzmore
bzip2_1_1.bin                                         0 s /nix/store/mvfap7kqj2kvxr91rkf71h6nqjavjhq1-bzip2-unstable-2020-08-11-bin/bin/bunzip2
bzip2_1_1.bin                                         0 s /nix/store/mvfap7kqj2kvxr91rkf71h6nqjavjhq1-bzip2-unstable-2020-08-11-bin/bin/bzcat
bzip2_1_1.bin                                         0 s /nix/store/mvfap7kqj2kvxr91rkf71h6nqjavjhq1-bzip2-unstable-2020-08-11-bin/bin/bzcmp
bzip2_1_1.bin                                         0 s /nix/store/mvfap7kqj2kvxr91rkf71h6nqjavjhq1-bzip2-unstable-2020-08-11-bin/bin/bzegrep
bzip2_1_1.bin                                    43,944 x /nix/store/mvfap7kqj2kvxr91rkf71h6nqjavjhq1-bzip2-unstable-2020-08-11-bin/bin/bzip2
bzip2_1_1.bin                                         0 s /nix/store/mvfap7kqj2kvxr91rkf71h6nqjavjhq1-bzip2-unstable-2020-08-11-bin/bin/bzless
bzip2_1_1.bin                                     1,259 x /nix/store/mvfap7kqj2kvxr91rkf71h6nqjavjhq1-bzip2-unstable-2020-08-11-bin/bin/bzmore
busybox.out                                           0 s /nix/store/2ishn1q3c9qk9p5ax4j2y4rk0yqh09gj-busybox-1.36.1/bin/bunzip2
busybox.out                                           0 s /nix/store/2ishn1q3c9qk9p5ax4j2y4rk0yqh09gj-busybox-1.36.1/bin/bzcat
busybox.out                                           0 s /nix/store/2ishn1q3c9qk9p5ax4j2y4rk0yqh09gj-busybox-1.36.1/bin/bzip2
```

expected result: `bzip2.bin` because it has all 7 files, and is an alias of `bzip2_1_1.bin`
