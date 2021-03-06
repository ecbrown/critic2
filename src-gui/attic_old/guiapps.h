/*
Copyright (c) 2017 Alberto Otero de la Roza
<aoterodelaroza@gmail.com>, Robin Myhr <x@example.com>, Isaac
Visintainer <x@example.com>, Richard Greaves <x@example.com>, Ángel
Martín Pendás <angel@fluor.quimica.uniovi.es> and Víctor Luaña
<victor@fluor.quimica.uniovi.es>.

critic2 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

critic2 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef GUIAPPS_H
#define GUIAPPS_H

// Handles for the various windows and GUI elements
extern bool structureinfo_window_h;
extern bool structurenew_window_h;
extern int structureopen_window_h;
extern bool console_window_h;

// GUI element prototypes
void guiapps_process_handles();
void structureinfo_window(bool *p_open);
void structurenew_window(bool *p_open);
void structureopen_window(int *p_open);
void console_window(bool *p_open);

#endif
