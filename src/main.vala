/* main.vala
 *
 * Copyright 2024 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

namespace Varallel {
    [Compact (opaque = true)]
    public class CLI {
        static bool show_version = false;
        static int jobs = 0;
        static string? colsep_regex_str = null;
        static bool hide_sub_output = false;
        static string? shell = null;
        const OptionEntry[] options = {
            { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
            { "jobs", 'j', OptionFlags.NONE, OptionArg.INT, ref jobs, "Run n jobs in parallel", "n" },
            { "colsep", 'r', OptionFlags.NONE, OptionArg.STRING, ref colsep_regex_str, "Regex to split the arguement", "EXPRESSION" },
            { "hide", '\0', OptionFlags.NONE, OptionArg.NONE, ref hide_sub_output, "Hide subcommands output", null },
            { "shell", 's', OptionFlags.NONE, OptionArg.STRING, ref shell, "Manually set SHELL to run the command, set 'n' to disable to use any shell", "SHELL" },
            { null }
        };

        [CCode (has_target = false)]
        public delegate int AttyFunc (int fd);
        public static bool isatty (int fd) {
            Module module = Module.open (null, ModuleFlags.LAZY);
            if (module == null) {
                printerr ("Error opening libc\n");
                // Default to true here to avid IO blocking of tty's stdin
                return true;
            }
            void* _func;
            module.symbol ("isatty", out _func);
            if (_func == null) {
                module.symbol ("_isatty", out _func);
                if (_func == null) {
                    printerr ("Error getting isatty/_isatty\n");
                    // Default to true here to avid IO blocking of tty's stdin
                    return true;
                }
            }
            AttyFunc? func = (AttyFunc) _func;
            return (func (fd) != 0);
        }

        public static bool parse_nonoption_args (ref unowned string[] args,
                                                 out string? command,
                                                 out string[]? args_list) {
            command = null;
            args_list = null;
            if (args.length <= 1) {
                // No command specified
                return false;
            }

            command = args[1];
            var array = new GenericArray<string> ();
            if (args.length <= 2) {
                // No args specified, use stdin (pipe) as input
                // Check if stdin is a pipe
                if (isatty (stdin.fileno ())) {
                    // stdin is a tty
                    // No input and no command specified, ERROR
                    return false;
                }
                // stdin is a pipe
                string line;
                while ((line = stdin.read_line ()) != null) {
                    array.add (line);
                }
            }
            // ::: is used to separate command and args
            if (args[2] == ":::") {
                if (args.length <= 3) {
                    printerr ("OptionError: no args specified arter `:::'\n\n");
                    return false;
                }
                array.data = args[3:];
            } else if (args[2] == "::::") {
                // :::: is used to separate command and files containing args
                if (args.length <= 3) {
                    printerr ("OptionError: no files specified arter `::::'\n\n");
                    return false;
                }
                foreach (var filename in args[3:]) {
                    if (filename == "-") {
                        // Use stdin as input
                        if (isatty (stdin.fileno ())) {
                            // stdin is a tty, WARNING and ignore
                            printerr ("Warning: stdin is a tty, ignoring\n");
                            continue;
                        }
                        // stdin is a pipe
                        string line;
                        while ((line = stdin.read_line ()) != null) {
                            array.add (line);
                        }
                    } else {
                        // Use file as input
                        var stream = FileStream.open (filename, "r");
                        if (stream == null) {
                            printerr ("Error opening file: %s\n", filename);
                            continue;
                        }
                        string line;
                        while ((line = stream.read_line ()) != null) {
                            array.add (line);
                        }
                    }
                }
            } else {
                printerr ("OptionError: invalid separator, the command must be in one\n");
                return false;
            }
            if (colsep_regex_str != null) {
                try {
                    var colsep_regex = new Regex (colsep_regex_str);
                    var old_array = (owned) array.data;
                    array.data = {};
                    foreach (var line in old_array) {
                        foreach (var part in colsep_regex.split (line)) {
                            array.add (part);
                        }
                    }
                } catch (RegexError e) {
                    printerr ("RegexError: %s\n", e.message);
                    return false;
                }
            }
            args_list = array.data;
            return true;
        }

        static int main (string[] args) {
            Intl.setlocale ();

            var opt_context = new OptionContext ("command [:::|::::] [arguments]");
            opt_context.set_help_enabled (true);
            opt_context.set_description ("Replacements in cammand:
  {}                          Input arguement
  {.}                         Input arguement without extension
  {/}                         Basename of input line
  {//}                        Dirname of input line
  {/.}                        Basename of input line without extension
  {#}                         Job index");
    /*
  {3} {2.} {4/} {1/.} etc.    Positional replacement strings
    */
            opt_context.add_main_entries (options, null);
            try {
                opt_context.parse (ref args);
            } catch (OptionError e) {
                printerr ("OptionError: %s\n\n", e.message);
                print (opt_context.get_help (true, null));
                return 1;
            }

            if (show_version) {
                print ("Vala Parallel v%s\n", VERSION);
                return 0;
            }

            if (args.length <= 1) {
                printerr ("OptionError: no command specified\n\n");
                print (opt_context.get_help (true, null));
                return 1;
            }

            string? command;
            string[]? args_list;
            if (!parse_nonoption_args (ref args, out command, out args_list)) {
                printerr ("OptionError: invalid command or args\n\n");
                print (opt_context.get_help (true, null));
                return 1;
            } else if (command == null || args_list == null) {
                printerr ("OptionError: invalid command or args\n\n");
                print (opt_context.get_help (true, null));
                return 1;
            } else if (args_list.length == 0) {
                printerr ("OptionError: no input specified\n\n");
                print (opt_context.get_help (true, null));
                return 1;
            }

            try {
                var manager = new ParallelManager (
                    command,
                    args_list,
                    jobs,
                    shell,
                    shell != "n",
                    hide_sub_output);
                manager.run ();
            } catch (ThreadError e) {
                printerr ("ThreadError: %s\n", e.message);
            }

            return 0;
        }
    }
}
