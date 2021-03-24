//------------------------------------------------------------------------
//  Main Window
//------------------------------------------------------------------------
//
//  Oblige Level Maker
//
//  Copyright (C) 2006-2017 Andrew Apted
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//------------------------------------------------------------------------

#include "headers.h"
#include "hdr_fltk.h"
#include "hdr_ui.h"
#include "main.h"

#ifndef WIN32
#include <unistd.h>
#endif

#if (FL_MAJOR_VERSION != 1 ||  \
	 FL_MINOR_VERSION != 3 ||  \
	 FL_PATCH_VERSION < 0)
#error "Require FLTK version 1.3.0 or later"
#endif


#define BASE_WINDOW_W  816
#define BASE_WINDOW_H  512


UI_MainWin *main_win;

int KF = 0;

int  small_font_size;
int header_font_size;

#define SELECTION	fl_rgb_color(62, 61, 57)



static void main_win_close_CB(Fl_Widget *w, void *data)
{
	main_action = MAIN_QUIT;
}


//
// MainWin Constructor
//
UI_MainWin::UI_MainWin(int W, int H, const char *title) :
	Fl_Double_Window(W, H, title)
{

	size_range(W, H, 0, 0);

	callback((Fl_Callback *) main_win_close_CB);

	color(WINDOW_BG, WINDOW_BG);


	int LEFT_W = kf_w(232);
	int MOD_W   = (W - LEFT_W) / 2 - 4;

	int TOP_H   = kf_h(228);
	int BOT_H   = H - TOP_H - 4;

	menu_bar = new Fl_Menu_Bar(0,0, W, 25);
	menu_bar->box(FL_FLAT_BOX);
	menu_bar->add("File/Options", 0, menu_do_options);
	menu_bar->add("File/Addon List", 0, menu_do_addons);
	menu_bar->add("File/Set Seed", 0, menu_do_edit_seed);
	menu_bar->add("File/Config Manager", 0, menu_do_manage_config);
	menu_bar->add("Help/About", 0, menu_do_about);
	menu_bar->add("Help/View Logs", 0, menu_do_view_logs);

	game_box = new UI_Game(0, 27, LEFT_W, TOP_H-27);

	build_box = new UI_Build(0, TOP_H+4, LEFT_W, BOT_H);

	right_mods = new UI_CustomMods(W - MOD_W, 27, MOD_W, H-27, SELECTION);

	left_mods = new UI_CustomMods(LEFT_W+4, 27, MOD_W, H-27, SELECTION);


	end();
	resizable(this);

}


//
// MainWin Destructor
//
UI_MainWin::~UI_MainWin()
{ }


void UI_MainWin::CalcWindowSize(int *W, int *H)
{
	*W = kf_w(BASE_WINDOW_W);
	*H = kf_h(BASE_WINDOW_H);

	// tweak for "Tiny" setting
	if (KF < 0)
	{
		*W -= 24;
		*H -= 24;
	}

//// DEBUG
//	fprintf(stderr, "\n\nCalcWindowSize --> %d x %d\n", *W, *H);
}


void UI_MainWin::Locked(bool value)
{
	game_box  ->Locked(value);
	left_mods ->Locked(value);
	right_mods->Locked(value);
}

void UI_MainWin::menu_do_about(Fl_Widget*w, void*data)
{
	DLG_AboutText();
}

void UI_MainWin::menu_do_view_logs(Fl_Widget *w, void *data)
{
	DLG_ViewLogs();
}

void UI_MainWin::menu_do_options(Fl_Widget *w, void *data)
{
	DLG_OptionsEditor();
}

void UI_MainWin::menu_do_addons(Fl_Widget *w, void *data)
{
	DLG_SelectAddons();
}

void UI_MainWin::menu_do_edit_seed(Fl_Widget *w, void *data)
{
	DLG_EditSeed();
}

void UI_MainWin::menu_do_manage_config(Fl_Widget *w, void *data)
{
	DLG_ManageConfig();
}
//--- editor settings ---
// vi:ts=4:sw=4:noexpandtab
