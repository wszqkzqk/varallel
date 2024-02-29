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
            // The minimal width of console to show progressbar is (title.length + ": [] 100.00%".length + 5)
            // = title.length + 17 + 5
            // only the the effictive length of progressbar is no less than 5, the progressbar will be shown
            var builder = new StringBuilder ("\r");
            builder.append (title);
            int bar_length = get_console_width () - 17;
            if (bar_length >= 5) {
                builder.append (": [");
                var fill_length = Math.lround (percentage / 100.0 * bar_length);
                for (int i = 0; i < fill_length; i++) {
                    builder.append_c (fill_char);
                }
                for (int i = 0; i < bar_length - fill_length; i++) {
                    builder.append_c (empty_char);
                }
                builder.append ("] %.2f%%".printf (percentage));
            } else {
                builder.append (": %.2f%%".printf (percentage));
            }
            printerr(builder.str);
        }

        int get_console_width () {
            // TODO: get console width
            return 80;
        }
    }
}
