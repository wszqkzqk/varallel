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
    [CCode (cname = "get_console_width")]
    extern int get_console_width ();

    [Compact (opaque = true)]
    public class Reporter {
        [CCode (has_target = false)]
        delegate int AttyFunc (int fd);
        static bool? in_tty = null;

        [CCode (cname = "is_a_tty")]
        public extern static bool isatty (int fd);

        public enum EscapeCode {
            RESET,
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
            public const string ANSI_RED = "\x1b[31m";
            public const string ANSI_GREEN = "\x1b[32m";
            public const string ANSI_YELLOW = "\x1b[33m";
            public const string ANSI_BLUE = "\x1b[34m";
            public const string ANSI_MAGENTA = "\x1b[35m";
            public const string ANSI_CYAN = "\x1b[36m";
            public const string ANSI_WHITE = "\x1b[37m";
            // Effects
            public const string ANSI_BOLD = "\x1b[1m";
            public const string ANSI_UNDERLINE = "\x1b[4m";
            public const string ANSI_BLINK = "\x1b[5m";
            public const string ANSI_DIM = "\x1b[2m";
            public const string ANSI_HIDDEN = "\x1b[8m";
            public const string ANSI_INVERT = "\x1b[7m";
            public const string ANSI_RESET = "\x1b[0m";

            public inline unowned string to_string () {
                switch (this) {
                case EscapeCode.RESET:
                    return ANSI_RESET;
                case EscapeCode.RED:
                    return ANSI_RED;
                case EscapeCode.GREEN:
                    return ANSI_GREEN;
                case EscapeCode.YELLOW:
                    return ANSI_YELLOW;
                case EscapeCode.BLUE:
                    return ANSI_BLUE;
                case EscapeCode.MAGENTA:
                    return ANSI_MAGENTA;
                case EscapeCode.CYAN:
                    return ANSI_CYAN;
                case EscapeCode.WHITE:
                    return ANSI_WHITE;
                case EscapeCode.BOLD:
                    return ANSI_BOLD;
                case EscapeCode.UNDERLINE:
                    return ANSI_UNDERLINE;
                case EscapeCode.BLINK:
                    return ANSI_BLINK;
                case EscapeCode.DIM:
                    return ANSI_DIM;
                case EscapeCode.HIDDEN:
                    return ANSI_HIDDEN;
                case EscapeCode.INVERT:
                    return ANSI_INVERT;
                default:
                    return ANSI_RESET;
                }
            }
        }

        public static inline void report_failed_command (string command, int status) {
            if (in_tty == null) {
                in_tty = isatty (stderr.fileno ());
            }
            if (in_tty) {
                printerr ("Command `%s%s%s' failed with status: %s%d%s\n",
                            Reporter.EscapeCode.ANSI_BOLD + EscapeCode.ANSI_BOLD,
                            command,
                            Reporter.EscapeCode.ANSI_RESET,
                            Reporter.EscapeCode.ANSI_RED + EscapeCode.ANSI_BOLD,
                            status,
                            Reporter.EscapeCode.ANSI_RESET);
                return;
            }
            printerr ("Command `%s' failed with status: %d\n",
                        command,
                        status);
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
        bool in_tty;
    
        public ProgressBar (int total_steps,
                            string title = "Progress",
                            char fill_char = '#',
                            char empty_char = '-') {
            this.title = title;
            this.total_steps = total_steps;
            this.current_step = 0;
            this.fill_char = fill_char;
            this.empty_char = empty_char;
            this.in_tty = Reporter.isatty (stderr.fileno ());
        }
    
        public inline int update (uint success_count, uint failure_count) {
            current_step += 1;
            current_step = (current_step > total_steps) ? total_steps : current_step;
            percentage = (double) current_step / total_steps * 100.0;
            print_progress (success_count, failure_count);
            return current_step;
        }

        public inline void print_progress (uint success_count, uint failure_count) {
            var prefix = "\rSuccess: %u Failure: %u ".printf (success_count, failure_count);
            var prelength = prefix.length - 1; // -1 for \r
            if (in_tty) {
                prefix = "\r".concat (
                    Reporter.EscapeCode.ANSI_BOLD,
                    Reporter.EscapeCode.ANSI_GREEN,
                    "Success: ",
                    success_count.to_string (),
                    Reporter.EscapeCode.ANSI_RESET,
                    " ",
                    Reporter.EscapeCode.ANSI_BOLD,
                    Reporter.EscapeCode.ANSI_RED,
                    "Failure: ",
                    failure_count.to_string (),
                    Reporter.EscapeCode.ANSI_RESET,
                    " ");
            }
            // Only the the effictive length of progressbar is no less than 5, the progressbar will be shown
            var builder = new StringBuilder (prefix);
            builder.append (title);
            // 12 is the length of ": [] 100.00%"
            int bar_length = get_console_width () - prelength - title.length - 12;
            if (in_tty && bar_length >= 5) {
                builder.append (": [");
                var fill_length = (int) (percentage / 100.0 * bar_length);
                builder.append (Reporter.EscapeCode.ANSI_INVERT);
                for (int i = 0; i < fill_length; i++) {
                    builder.append_c (fill_char);
                }
                builder.append (Reporter.EscapeCode.ANSI_RESET);
                for (int i = 0; i < bar_length - fill_length; i++) {
                    builder.append_c (empty_char);
                }
                builder.append_printf ("] %6.2f%%", percentage);
            } else {
                builder.append_printf (": %6.2f%%", percentage);
            }
            printerr(builder.str);
        }
    }
}
