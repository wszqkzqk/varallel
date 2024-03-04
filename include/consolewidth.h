/* consolewidth.h
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

#if defined(_WIN32)
#include <windows.h>
__declspec(dllexport) extern inline int get_console_width () {
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    int columns;
    // GetConsoleScreenBufferInfo will return 0 if it FAILS
    int success = GetConsoleScreenBufferInfo(GetStdHandle(STD_ERROR_HANDLE), &csbi);
    if (success) {
        columns = csbi.srWindow.Right - csbi.srWindow.Left + 1;
        return (int) columns;
    } else {
        return 0;
    }
}
#else
#include <sys/ioctl.h>
#include <stdio.h>
extern inline int get_console_width () {
    struct winsize w;
    // ioctl will return 0 if it SUCCEEDS
    int fail  = ioctl (fileno (stderr), TIOCGWINSZ, &w);
    if (fail) {
        return 0;
    } else {
        return w.ws_col;
    }
}
#endif
