/* main.vala
 *
 * Copyright 2024 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

namespace Varallel {
    [Compact (opaque = true)]
    class CLI {
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
            { "shell", 's', OptionFlags.NONE, OptionArg.STRING, ref shell, "Manually set SHELL to run the command", "SHELL" },
            { null }
        };

        static int main (string[] args) {
            Intl.setlocale ();

            var opt_context = new OptionContext ("command ::: [arguments]");
            opt_context.set_help_enabled (true);
            opt_context.set_description ("Replacements in cammand:
  {}                          Input arguement
  {.}                         Input arguement without extension
  {/}                         Basename of input line
  {//}                        Dirname of input line
  {/.}                        Basename of input line without extension
  {#}                         Job index");
    /*
    {3} {3.} {3/} {3/.} {=3 perl code =}    Positional replacement strings
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

            // Only allow one arg of command
            

            return 0;
        }
    }
}
