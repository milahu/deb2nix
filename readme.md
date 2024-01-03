# deb2nix

translate package names between debian and nixpkgs



## status

early draft, proof of concept

currently this is extremely slow
because `nix-locate` is called once for every file

example:

```console
$ APT_CONFIG="$HOME/.config/apt/apt.conf" apt-file list bzip2 | grep /bin/
bzip2: /bin/bunzip2
bzip2: /bin/bzcat
bzip2: /bin/bzcmp
bzip2: /bin/bzdiff
bzip2: /bin/bzegrep
bzip2: /bin/bzexe
bzip2: /bin/bzfgrep
bzip2: /bin/bzgrep
bzip2: /bin/bzip2
bzip2: /bin/bzip2recover
bzip2: /bin/bzless
bzip2: /bin/bzmore
```

this will call

```sh
nix-locate --top-level --whole-name --at-root /bin/bunzip2
nix-locate --top-level --whole-name --at-root /bin/bzcat
nix-locate --top-level --whole-name --at-root /bin/bzcmp
# ...
```

this will be faster:

```sh
nix-locate --top-level --regex '^(/bin/bunzip2|/bin/bzcat|/bin/bzcmp|/bin/bzdiff|/bin/bzegrep|/bin/bzexe|/bin/bzfgrep|/bin/bzgrep|/bin/bzip2|/bin/bzip2recover|/bin/bzless|/bin/bzmore)$'
```



## related

- https://github.com/ngi-nix/debnix - Mapping library names from debian to nix - mapping is done by package names, see [matcher.rs](https://github.com/ngi-nix/debnix/blob/main/src/matcher.rs)
