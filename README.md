# Varallel

`Varallel` is a simple and easy to use CLI tool to run commands in parallel. It is written in Vala, and with the use of GLib, it is cross-platform.

## Build

### Dependencies

* Runtime:
  * GLib
* Build:
  * Vala
  * GLib
  * Meson
  * Ninja

### Compile

Use meson to configure the build environment and build the project.

```bash
meson setup builddir
meson compile -C builddir
```

## Usage

### Help

```
Usage:
  varallel [OPTION?] command [:::|::::] [arguments]

Help Options:
  -h, --help                  Show help options

Application Options:
  -v, --version               Display version number
  -j, --jobs=n                Run n jobs in parallel
  -r, --colsep=EXPRESSION     Regex to split the arguement
  --hide                      Hide subcommands output
  -s, --shell=SHELL           Manually set SHELL to run the command, set 'n' to disable to use any shell
  -b, --bar                   Show progress bar

Replacements in cammand:
  {}                          Input arguement
  {.}                         Input arguement without extension
  {/}                         Basename of input line
  {//}                        Dirname of input line
  {/.}                        Basename of input line without extension
  {#}                         Job index
  
For more information, or to report bugs, please visit:
    <https://github.com/wszqkzqk/varallel>
```

#### Explanation

* `{}`
  * Input arguement. This replacement will be replaced by a full line read from the input source. The input source may be stdin (standard input), :::, or ::::.
* `{.}`
  * Input arguement without extension. This replacement string will be replaced by the input with the extension removed. If the input arguement contains . after the last / the last . till the end of the string will be removed and {.} will be replaced with the remaining.
    * E.g. foo.webp becomes foo, subdir/foo.webp becomes subdir/foo, sub.dir/foo.webp becomes sub.dir/foo, sub.dir/bar remains sub.dir/bar. If the input arguement does not contain . it will remain unchanged.
* `{/}`
  * Basename of input arguement. This replacement string will be replaced by the input with the directory part removed.
* `{//}`
  * Dirname of input arguement. This replacement string will be replaced by the dir of the input arguement.
* `{/.}`
  * Basename of Input arguement without extension. This replacement string will be replaced by the input with the directory and extension part removed. It is a combination of {/} and {.}. 
* `{#}`
  * Sequence number of the job to run. This replacement string will be replaced by the sequence number of the job being run. It contains the same number as $PARALLEL_SEQ.
* `:::`
  * Read the arguement list from the command line.
* `::::`
  * Read the arguement list from the files provided as the arguement.
* `-j=n` `--jobs=n`
  * Run n jobs in parallel. The default value is the number of CPU cores.
* `-r=EXPRESSION` `--colsep=EXPRESSION`
  * User-defined regex to split the arguement.
* `--hide`
  * Hide subcommands output.
* `-s=SHELL` `--shell=SHELL`
  * Manually set SHELL to run the command, set 'n' to disable to use any shell, and the subcommands will be spawned directly.
* `-b` `--bar`
  * Show progress bar.

### Examples

`Varallel` can read the arguement lists from pipes, files or command line.

#### Use pipes

`Varallel` can read the arguement lists from pipes.

```bash
seq 1 6 | varallel echo
seq 1 6 | varallel echo
varallel echo < <(seq 3 7)
```

#### Use command lines

`Varallel` can read the arguement lists from the command line.

```bash
varallel echo ::: 1 2 3 4 5 6
varallel 'echo "{.} {/} {#} {//}"' ::: /home/wszqkzqk ./README.md ~/Pictures/Arch_Linux_logo.svg
```

#### Use files

Also, `Varallel` can read the arguement lists from files.

```bash
varallel echo :::: example.txt file*.txt
```
