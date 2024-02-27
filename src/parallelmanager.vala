/* parallelmanager.vala
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
    public const bool IS_WINDOWS = (Path.DIR_SEPARATOR == '\\');

    public class ParallelManager {
        /**
         * ParallelManager is a class to manage parallel execution of commands.
         */
        ThreadPool<Unit> pool;
        string original_command;
        string[] original_args;
        int jobs = 0;
        string? shell = null;
        string shell_args = "-c";
        static Regex slot_in_command = /\{(\/|\.|\/\.|\/\/|#)?\}/;
        public uint finished_jobs {get; set; default = 0;}
        public uint failed_jobs {get; set; default = 0;}
        
        public ParallelManager (string original_command,
                                string[] original_args,
                                int jobs = 0,
                                string? shell = null,
                                bool use_shell = true,
                                bool hide_sub_output = false) throws ThreadError {
            /**
             * ParallelManager:
             * @original_command: the command to be executed
             * @original_args: the arguments of the command
             * @jobs: the number of jobs to be executed in parallel
             * @shell: the shell to be used
             * @use_shell: whether to use shell
             * @hide_sub_output: whether to hide the output of the subprocesses
             *
             * Create a new ParallelManager instance.
             */
            this.original_args = original_args;
            this.original_command = original_command;
            // if jobs is 0, use the number of processors
            this.jobs = (jobs == 0) ? (int) get_num_processors () : jobs;
            pool = new ThreadPool<Unit>.with_owned_data (
                (subprsc) => {
                    try {
                        subprsc.run ();
                        if (!hide_sub_output) {
                            printerr (subprsc.error);
                            print (subprsc.output);
                        }
                    } catch (SpawnError e) {
                        printerr ("SpawnError: %s\n", e.message);
                    }
                }, 
                this.jobs, 
                false);
            if (use_shell) {
                choose_shell (shell);
            }
        }

        public void run () {
            /**
             * run:
             *
             * Run the commands in parallel.
             */
            for (uint i = 0; i < original_args.length; i += 1) {
                var command = process_single_command (original_command, original_args[i], i);
                if (command == null) {
                    printerr ("Failed to process command: %s\n", original_command);
                    continue;
                }
                try {
                    pool.add (new Unit (command, shell, shell_args));
                } catch (ThreadError e) {
                    printerr ("ThreadError: %s\n", e.message);
                } catch (ShellError e) {
                    printerr ("ShellError: %s\n", e.message);
                }
            }
        }        

        static inline string? process_single_command (string command, string single_arg, uint index) {
            /**
             * process_single_command:
             * @command: the command to be executed
             * @single_arg: the argument of the command
             * @index: the index of the job
             *
             * Process a single command.
             */
            string? arg_no_ext = null;
            string? arg_basename = null;
            string? arg_dirname = null;
            string? arg_basename_no_ext = null;
            try {
                var ret = slot_in_command.replace_eval (
                    command,
                    -1,
                    0,
                    0,
                    (match_info, builder) => {
                        var old_center = match_info.fetch (1);
                        if (old_center == null) {
                            // {}: Input arguement
                            builder.append (single_arg);
                            return false;
                        }
                        
                        switch (old_center.length) {
                        case 0:
                            // {}: Input arguement
                            builder.append (single_arg);
                            return false;
                        case 1:
                            switch (old_center[0]) {
                            case '/':
                                // {/}: Basename of input line
                                if (arg_basename == null) {
                                    arg_basename = Path.get_basename (single_arg);
                                }
                                builder.append (arg_basename);
                                break;
                            case '#':
                                // {#}: Job index
                                builder.append (index.to_string ());
                                break;
                            case '.':
                                // {.}: Input arguement without extension
                                if (arg_no_ext == null) {
                                    var pos = single_arg.last_index_of_char ('.');
                                    if (pos == -1) {
                                        arg_no_ext = single_arg;
                                    } else {
                                        arg_no_ext = single_arg[:pos];
                                    }
                                }
                                builder.append (arg_no_ext);
                                break;
                            default:
                                printerr ("Unknown slot: {%s}\n", old_center);
                                builder.append (single_arg);
                                break;
                            }
                            break;
                        case 2:
                            // May be {//} or {/.}
                            if (old_center[1] == '/') {
                                // {//}: Dirname of input line
                                if (arg_dirname == null) {
                                    arg_dirname = Path.get_dirname (single_arg);
                                }
                                builder.append (arg_dirname);
                            } else if (old_center[1] == '.') {
                                // {/.}: Basename without extension of input line
                                if (arg_basename_no_ext == null) {
                                    var pos = single_arg.last_index_of_char ('.');
                                    if (pos == -1) {
                                        arg_basename_no_ext = Path.get_basename (single_arg);
                                    } else {
                                        arg_basename_no_ext = Path.get_basename (single_arg[:pos]);
                                    }
                                }
                                builder.append (arg_basename_no_ext);
                            } else {
                                printerr ("Unknown slot: {%s}\n", old_center);
                                builder.append (single_arg);
                            }
                            break;
                        default:
                            printerr ("Unknown slot: {%s}\n", old_center);
                            builder.append (single_arg);
                            break;
                        }
                        return false;
                    }
                );
                // Consider the case that the command is not changed
                // Put the argument at the end of the command
                if (ret == command) {
                    ret = command + " " + single_arg;
                }
                return ret;
            } catch (RegexError e) {
                printerr ("RegexError: %s\n", e.message);
                return null;
            }
        }

        inline void choose_shell (string? shell) {
            if (shell != null) {
                // if shell is not null, use it
                if (IS_WINDOWS) {
                    this.shell = shell.ascii_down ();
                    // if the shell is cmd or cmd.exe, use /c as the shell_args
                    if (this.shell.has_suffix ("cmd") || this.shell.has_suffix ("cmd.exe")) {
                        this.shell_args = "/c";
                    }
                } else {
                    this.shell = shell;
                }
            } else {
                // if shell is null and the system is windows, use cmd.exe
                if (IS_WINDOWS) {
                    this.shell = "cmd.exe";
                    this.shell_args = "/c";
                } else {
                    // if shell is null and the system is not windows, use the SHELL environment variable
                    this.shell = Environment.get_variable("SHELL");
                    // if the SHELL environment variable is not set, use /bin/sh
                    if (this.shell == null) {
                        this.shell = "/bin/sh";
                    }
                }
            }
        }
    }
}
