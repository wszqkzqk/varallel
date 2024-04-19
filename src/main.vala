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
        static bool bar = true;
        static bool print_only = false;
        static Regex colsep_regex = null;
        const OptionEntry[] options = {
            { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
            { "jobs", 'j', OptionFlags.NONE, OptionArg.INT, ref jobs, "Run n jobs in parallel", "n" },
            { "colsep", 'r', OptionFlags.NONE, OptionArg.STRING, ref colsep_regex_str, "Regex to split the argument", "EXPRESSION" },
            { "quiet", 'q', OptionFlags.NONE, OptionArg.NONE, ref hide_sub_output, "Hide subcommands output", null },
            { "shell", 's', OptionFlags.NONE, OptionArg.STRING, ref shell, "Manually set SHELL to run the command, set 'n' to disable to use any shell", "SHELL" },
            { "hide-bar", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref bar, "Hide progress bar", null},
            { "bar", '\0', OptionFlags.NONE, OptionArg.NONE, ref bar, "Show progress bar (Default behavior)", null},
            { "print-only", '\0', OptionFlags.NONE, OptionArg.NONE, ref print_only, "Only print the command but not run", null},
            { null }
        };

        public static bool parse_nonoption_args ([CCode (array_length = false, array_null_terminated = true)] ref string[] args,
                                                 out string? command,
                                                 out GenericArray<GenericArray<string>> args_matrix) {
            command = null;
            args_matrix = new GenericArray<GenericArray<string>> ();
            if (args.length <= 1) {
                // No command specified
                return false;
            }

            if (colsep_regex_str != null && colsep_regex == null) {
                try {
                    colsep_regex = new Regex (colsep_regex_str, RegexCompileFlags.OPTIMIZE);
                } catch (RegexError e) {
                    Reporter.error ("RegexError", e.message);
                    return false;
                }
            }

            command = args[1];
            if (args.length <= 2) {
                // No args specified, use stdin (pipe) as input
                // Check if stdin is a pipe
                if (Reporter.isatty (stdin.fileno ())) {
                    // stdin is a tty
                    // No input and no command specified, ERROR
                    return false;
                }
                // stdin is a pipe
                string line;
                var arg_array = new GenericArray<string> ();
                while ((line = stdin.read_line ()) != null) {
                    handle_line_colsep (line, arg_array);
                }
                add_args (arg_array, args_matrix);
                return true;
            }

            for (var i = 2; args[i] != null; i += 1) {
                unowned var arg = args[i];
                if (arg == ":::") {
                    var arg_array = new GenericArray<string> ();
                    while (args[i + 1] != null) {
                        if (args[i + 1] == ":::" || args[i + 1] == "::::") {
                            // End of :::
                            break;
                        }
                        i += 1;
                        unowned var line = args[i];
                        handle_line_colsep (line, arg_array);
                    }
                    add_args (arg_array, args_matrix);
                } else if (arg == "::::") {
                    // Read from files specified in the following arguments
                    while (args[i + 1] != null) {
                        if (args[i + 1] == ":::" || args[i + 1] == "::::") {
                            // End of :::
                            break;
                        }
                        i += 1;
                        unowned var filename = args[i];
                        if (filename == "-") {
                            // Use stdin as input
                            if (Reporter.isatty (stdin.fileno ())) {
                                // stdin is a tty, WARNING and ignore
                                Reporter.warning ("Warning", "stdin is a tty, ignoring");
                                continue;
                            }
                            // stdin is a pipe
                            string line;
                            var arg_array = new GenericArray<string> ();
                            while ((line = stdin.read_line ()) != null) {
                                handle_line_colsep (line, arg_array);
                            }
                            add_args (arg_array, args_matrix);
                        } else {
                            var stream = FileStream.open (filename, "r");
                            if (stream == null) {
                                Reporter.warning ("Warning", "error opening file `%s'", filename);
                                continue;
                            }
                            string line;
                            var arg_array = new GenericArray<string> ();
                            while ((line = stream.read_line ()) != null) {
                                handle_line_colsep (line, arg_array);
                            }
                            add_args (arg_array, args_matrix);
                        }
                    }
                } else {
                    Reporter.error ("OptionError", "invalid separator, the command must be in one");
                    return false;
                }
            }

            return true;
        }

        static inline void handle_line_colsep (string line, GenericArray<string> arg_array) {
            /**
             * Split the line by colsep_regex and add to arg_array
             */
            if (colsep_regex != null) {
                foreach (var part in colsep_regex.split (line)) {
                    arg_array.add ((owned) part);
                }
            } else {
                arg_array.add (line);
            }
        }

        static inline void add_args (GenericArray<string> arg_array, GenericArray<GenericArray<string>> args_matrix) {
            if (args_matrix.length == 0) {
                // No args in args_matrix, directly add arg_array
                if (arg_array.length == 0) {
                    // No args in arg_array, default to " "
                    arg_array.add (" ");
                }
                foreach (unowned var arg in arg_array) {
                    var arg_item = new GenericArray<string> ();
                    arg_item.add (arg);
                    args_matrix.add (arg_item);
                }
            } else {
                if (arg_array.length == 0) {
                    // No args in arg_array, default to " "
                    arg_array.add (" ");
                }
                var new_args_matrix = new GenericArray<GenericArray<string>> ();
                foreach (unowned var old_arg_item in args_matrix) {
                    foreach (unowned var arg in arg_array) {
                        var new_arg_item = new GenericArray<string> ();
                        foreach (unowned var old_arg in old_arg_item) {
                            new_arg_item.add (old_arg);
                        }
                        new_arg_item.add (arg);
                        new_args_matrix.add (new_arg_item);
                    }
                }
                // Replace args_matrix's old data with new_args_matrix's data
                args_matrix.data = (owned) new_args_matrix.data;
            }
        }

        static int main (string[] original_args) {
            Intl.setlocale ();

#if WINDOWS
            var args = Win32.get_command_line ();
#else
            var args = strdupv (original_args);
#endif
            var opt_context = new OptionContext ("command [:::|::::] [arguments]");
            opt_context.set_help_enabled (true);
            opt_context.set_description ("Replacements in cammand:
  {}                          Input argument
  {.}                         Input argument without extension
  {/}                         Basename of input line
  {//}                        Dirname of input line
  {/.}                        Basename of input line without extension
  {#}                         Job index, starting from 1
  {3} {2.} {4/} {1/.} etc.    Positional replacement strings
  
For more information, or to report bugs, please visit:
    <https://github.com/wszqkzqk/varallel>");
            opt_context.add_main_entries (options, null);
            try {
                opt_context.parse_strv (ref args);
            } catch (OptionError e) {
                Reporter.error ("OptionError", e.message);
                stderr.putc ('\n');
                printerr ("%s", opt_context.get_help (true, null));
                return 1;
            }

            if (show_version) {
                printerr ("Varallel v%s\n", VERSION);
                return 0;
            }

            string? command;
            GenericArray<GenericArray<string>> args_matrix;
            if ((!parse_nonoption_args (ref args, out command, out args_matrix))) {
                Reporter.error ("OptionError", "invalid command or args");
                stderr.putc ('\n');
                printerr ("%s", opt_context.get_help (true, null));
                return 1;
            } else if (args_matrix == null || args_matrix.length == 0) {
                Reporter.error ("OptionError", "no input specified");
                stderr.putc ('\n');
                printerr ("%s", opt_context.get_help (true, null));
                return 1;
            }

            try {
                var manager = new ParallelManager (
                    command,
                    args_matrix,
                    jobs,
                    shell,
                    shell != "n",
                    hide_sub_output,
                    bar);
                if (print_only) {
                    manager.print_commands ();
                } else {
                    manager.run ();
                }
            } catch (ThreadError e) {
                Reporter.error ("ThreadError", e.message);
                return 1;
            }

            printerr ((bar && (!print_only)) ? "\nAll jobs completed!\n" : "All jobs completed!\n");
            return 0;
        }
    }
}
