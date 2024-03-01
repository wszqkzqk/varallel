/* reporter.vala
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
    [CCode (cheader_filename = "../include/consolewidth.h", cname = "get_console_width")]
    public extern int get_console_width ();

    [Compact (opaque = true)]
    public class Reporter {
        [CCode (has_target = false)]
        delegate int AttyFunc (int fd);
        static bool? in_tty = null;

        public enum EscapeCode {
            END,
            RED,
            GREEN,
            YELLOW,
            BLUE,
            MAGENTA,
            CYAN,
            WHITE,
            BOLD,
            UNDERLINE,
            BLINK,
            DIM,
            HIDDEN,
            INVERT;

            // Colors
            const string ANSI_COLOR_RED = "\x1b[31m";
            const string ANSI_COLOR_GREEN = "\x1b[32m";
            const string ANSI_COLOR_YELLOW = "\x1b[33m";
            const string ANSI_COLOR_BLUE = "\x1b[34m";
            const string ANSI_COLOR_MAGENTA = "\x1b[35m";
            const string ANSI_COLOR_CYAN = "\x1b[36m";
            const string ANSI_COLOR_WHITE = "\x1b[37m";
            // Effects
            const string ANSI_COLOR_BOLD = "\x1b[1m";
            const string ANSI_COLOR_UNDERLINE = "\x1b[4m";
            const string ANSI_COLOR_BLINK = "\x1b[5m";
            const string ANSI_COLOR_DIM = "\x1b[2m";
            const string ANSI_COLOR_HIDDEN = "\x1b[8m";
            const string ANSI_COLOR_INVERT = "\x1b[7m";
            const string ANSI_COLOR_END = "\x1b[0m";

            public inline unowned string to_string () {
                switch (this) {
                case EscapeCode.END:
                    return ANSI_COLOR_END;
                case EscapeCode.RED:
                    return ANSI_COLOR_RED;
                case EscapeCode.GREEN:
                    return ANSI_COLOR_GREEN;
                case EscapeCode.YELLOW:
                    return ANSI_COLOR_YELLOW;
                case EscapeCode.BLUE:
                    return ANSI_COLOR_BLUE;
                case EscapeCode.MAGENTA:
                    return ANSI_COLOR_MAGENTA;
                case EscapeCode.CYAN:
                    return ANSI_COLOR_CYAN;
                case EscapeCode.WHITE:
                    return ANSI_COLOR_WHITE;
                case EscapeCode.BOLD:
                    return ANSI_COLOR_BOLD;
                case EscapeCode.UNDERLINE:
                    return ANSI_COLOR_UNDERLINE;
                case EscapeCode.BLINK:
                    return ANSI_COLOR_BLINK;
                case EscapeCode.DIM:
                    return ANSI_COLOR_DIM;
                case EscapeCode.HIDDEN:
                    return ANSI_COLOR_HIDDEN;
                case EscapeCode.INVERT:
                    return ANSI_COLOR_INVERT;
                default:
                    return ANSI_COLOR_END;
                }
            }
        }

        public static bool isatty (int fd) {
            Module module = Module.open (null, ModuleFlags.LAZY);
            if (module == null) {
                printerr ("Error opening libc\n");
                // Default to true for stdin to avid IO blocking of tty's stdin
                // Default to false for other file descriptors
                return (fd == stdin.fileno ()) ? true : false;
            }
            void* _func;
            module.symbol ("isatty", out _func);
            if (_func == null) {
                module.symbol ("_isatty", out _func);
                if (_func == null) {
                    printerr ("Error getting isatty/_isatty\n");
                    // Default to true for stdin to avid IO blocking of tty's stdin
                    // Default to false for other file descriptors
                    return (fd == stdin.fileno ()) ? true : false;
                }
            }
            AttyFunc? func = (AttyFunc) _func;
            return (func (fd) != 0);
        }

        public static inline void print_command_status (string command, int status) {
            if (status != 0) {
                if (in_tty == null) {
                    in_tty = isatty (stderr.fileno ());
                }
                if (in_tty) {
                    printerr ("Command `%s%s%s' failed with status: %s%d%s\n",
                                EscapeCode.BOLD.to_string () + EscapeCode.YELLOW.to_string (),
                                command,
                                EscapeCode.END.to_string (),
                                EscapeCode.RED.to_string () + EscapeCode.BOLD.to_string (),
                                status,
                                EscapeCode.END.to_string ());
                    return;
                }
                printerr ("Command `%s' failed with status: %d\n",
                            command,
                            status);
            }
        }
    }

    [Compact (opaque = true)]
    public class ProgressBar {
        string title;
        double percentage = 0.0;
        int total_steps;
        int current_step;
        char fill_char;
        char empty_char;
    
        public ProgressBar (int total_steps,
                            char fill_char = '#',
                            char empty_char = '-',
                            string title = "Progress") {
            this.title = title;
            this.total_steps = total_steps;
            this.current_step = 0;
            this.fill_char = fill_char;
            this.empty_char = empty_char;
        }
    
        public int update () {
            current_step += 1;
            current_step = (current_step > total_steps) ? total_steps : current_step;
            percentage = (double) current_step / total_steps * 100.0;
            print_progress ();
            return current_step;
        }

        public void print_progress () {
            // Only the the effictive length of progressbar is no less than 5, the progressbar will be shown
            var builder = new StringBuilder (title);
            int bar_length = get_console_width () - title.length - 12; // 12 is the length of ": [] 100.00%"
            if (bar_length >= 5) {
                builder.append (": [");
                var fill_length = (int) (percentage / 100.0 * bar_length);
                for (int i = 0; i < fill_length; i++) {
                    builder.append_c (fill_char);
                }
                for (int i = 0; i < bar_length - fill_length; i++) {
                    builder.append_c (empty_char);
                }
                builder.append_printf ("] %6.2f%%\r", percentage);
            } else {
                builder.append_printf (": %6.2f%%\r", percentage);
            }
            printerr(builder.str);
        }
    }
}
